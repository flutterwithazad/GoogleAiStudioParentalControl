-- ==============================================================================
-- SCREENMIRROR PARENTAL CONTROL: SUPABASE DATABASE SCHEMA & RLS POLICIES
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS TABLE (Parent accounts)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. DEVICES TABLE (Registered Android child devices)
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL UNIQUE,
    device_name TEXT NOT NULL,
    manufacturer TEXT,
    model TEXT,
    android_sdk INT,
    is_online BOOLEAN DEFAULT false,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PARENT_CHILD_LINKS (Authorized relationships)
CREATE TABLE IF NOT EXISTS public.parent_child_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    alias TEXT,
    paired_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    CONSTRAINT unique_parent_device UNIQUE(parent_id, device_id)
);

-- 4. PAIRING_CODES (Ephemeral 6-digit codes and QR payloads)
CREATE TABLE IF NOT EXISTS public.pairing_codes (
    code TEXT PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
    is_used BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. MIRRORING_SESSIONS (Lifecycle audit & active state)
CREATE TYPE session_status AS ENUM (
    'REQUESTED',
    'ACTIVE',
    'DECLINED',
    'DISCONNECTED',
    'TERMINATED_BY_PARENT',
    'TERMINATED_BY_CHILD',
    'ERROR'
);

CREATE TABLE IF NOT EXISTS public.mirroring_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    status session_status DEFAULT 'REQUESTED',
    quality_profile TEXT DEFAULT 'NORMAL_NETWORK',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    error_reason TEXT
);

-- 6. SIGNALING_MESSAGES (Fallback store / WebRTC negotiation relay)
CREATE TABLE IF NOT EXISTS public.signaling_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES public.mirroring_sessions(id) ON DELETE CASCADE,
    sender_type TEXT NOT NULL CHECK (sender_type IN ('PARENT', 'CHILD')),
    recipient_type TEXT NOT NULL CHECK (recipient_type IN ('PARENT', 'CHILD')),
    message_type TEXT NOT NULL, -- 'OFFER', 'ANSWER', 'ICE_CANDIDATE', 'TERMINATE'
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- INDEXES FOR LOW LATENCY REALTIME QUERIES
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_parent_child_parent ON public.parent_child_links(parent_id);
CREATE INDEX IF NOT EXISTS idx_parent_child_device ON public.parent_child_links(device_id);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON public.mirroring_sessions(device_id, status);
CREATE INDEX IF NOT EXISTS idx_signaling_session ON public.signaling_messages(session_id, created_at);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_child_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pairing_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mirroring_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signaling_messages ENABLE ROW LEVEL SECURITY;

-- 1. USERS: Only self
CREATE POLICY "Users can only read/update their own profile"
    ON public.users
    FOR ALL
    USING (auth.uid() = id);

-- 2. PARENT_CHILD_LINKS: Parents can only see their own linked children
CREATE POLICY "Parents see their own linked child devices"
    ON public.parent_child_links
    FOR SELECT
    USING (auth.uid() = parent_id);

CREATE POLICY "Parents can delete/unlink their own child devices"
    ON public.parent_child_links
    FOR DELETE
    USING (auth.uid() = parent_id);

-- 3. DEVICES: Parents can only view devices they are paired with
CREATE POLICY "Parents can read paired device details"
    ON public.devices
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.parent_child_links pcl
            WHERE pcl.device_id = devices.id AND pcl.parent_id = auth.uid() AND pcl.is_active = true
        )
    );

-- 4. MIRRORING_SESSIONS: Strict authorization (Parent only accesses their own sessions)
CREATE POLICY "Parents can access mirroring sessions for their linked devices"
    ON public.mirroring_sessions
    FOR ALL
    USING (
        auth.uid() = parent_id AND
        EXISTS (
            SELECT 1 FROM public.parent_child_links pcl
            WHERE pcl.device_id = mirroring_sessions.device_id AND pcl.parent_id = auth.uid()
        )
    );

-- 5. SIGNALING_MESSAGES: Accessible only by session participants
CREATE POLICY "Signaling messages accessible by session participants"
    ON public.signaling_messages
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.mirroring_sessions ms
            WHERE ms.id = signaling_messages.session_id AND ms.parent_id = auth.uid()
        )
    );

-- ==============================================================================
-- PAIRING TRANSACTION STORED PROCEDURE
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.claim_pairing_code(p_code TEXT, p_alias TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pairing RECORD;
    v_link_id UUID;
BEGIN
    -- Check valid unused code
    SELECT * INTO v_pairing
    FROM public.pairing_codes
    WHERE code = p_code AND is_used = false AND expires_at > NOW();

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid or expired pairing code');
    END IF;

    -- Create link with authenticated parent
    INSERT INTO public.parent_child_links (parent_id, device_id, alias)
    VALUES (auth.uid(), v_pairing.device_id, p_alias)
    RETURNING id INTO v_link_id;

    -- Invalidate code
    UPDATE public.pairing_codes
    SET is_used = true
    WHERE code = p_code;

    RETURN jsonb_build_object('success', true, 'link_id', v_link_id);
END;
$$;
