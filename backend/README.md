# ScreenMirror Backend & Signaling Architecture

The backend infrastructure provides authenticated device pairing, Row-Level Security (RLS) enforcement, and real-time WebRTC signaling via Supabase.

## Directory Structure

```
/backend
├── supabase/
│   └── schema.sql                # Complete PostgreSQL schema with RLS & functions
├── edge-functions/
│   └── get-turn-credentials.ts   # RFC 5766 ephemeral TURN credential generator
└── README.md                     # Backend documentation
```

## Security & Row Level Security (RLS) Policies

1. **Strict Relationship Verification**:
   - Parents can only query or request sessions from child devices present in `parent_child_links` where `is_active = TRUE`.
   - Rogue devices cannot send signals to unrelated parent or child devices.

2. **No Backend Secrets in Mobile Apps**:
   - Supabase `service_role` key is **NEVER** embedded in Flutter code.
   - Long-term TURN credentials are never shipped in the APK. The `get-turn-credentials` Edge Function generates short-lived HMAC-SHA1 tokens with a 2-hour TTL.

3. **Atomic Pairing Protocol**:
   - `claim_pairing_code(code)` is a PostgreSQL transaction with `FOR UPDATE` row-locking to prevent race conditions or replay attacks.

## Database Tables

- `users`: Parent and child identities.
- `devices`: Android hardware metadata, presence state, and battery exemption status.
- `parent_child_links`: Verified cryptographic pairings.
- `pairing_codes`: 10-minute expiring alphanumeric and QR pairing payloads.
- `mirroring_sessions`: Complete session audit trail with state transitions and termination reasons.
- `signaling_messages`: Realtime broadcast table for WebRTC SDP offers, answers, and ICE candidate exchanges.
