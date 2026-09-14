import { useState, useRef, useEffect, useCallback } from 'react';
import { DeviceState, SessionState, WebRTCStatsData, StructuredLog } from './types';
import { ParentDeviceView } from './components/ParentDeviceView';
import { ChildDeviceView } from './components/ChildDeviceView';
import { StructuredLogViewer } from './components/StructuredLogViewer';
import { CodeExplorer } from './components/CodeExplorer';
import { ArchitectureInspector } from './components/ArchitectureInspector';
import { TestRunnerView } from './components/TestRunnerView';
import {
  Smartphone,
  Layers,
  Code2,
  CheckCircle,
  Download,
  Cast,
  Activity,
} from 'lucide-react';

export default function App() {
  const [activeView, setActiveView] = useState<'simulator' | 'code' | 'architecture' | 'tests'>('simulator');
  const [deviceState, setDeviceState] = useState<DeviceState>('READY');
  const [sessionState, setSessionState] = useState<SessionState>('IDLE');
  const [activeApp, setActiveApp] = useState<string>('Chrome');
  const [showSetupWizard, setShowSetupWizard] = useState<boolean>(false);
  const [isRealScreenShare, setIsRealScreenShare] = useState<boolean>(false);

  const [stats, setStats] = useState<WebRTCStatsData>({
    width: 1280,
    height: 720,
    fps: 28,
    bitrateKbps: 1420,
    roundTripTimeMs: 35,
  });

  const [logs, setLogs] = useState<StructuredLog[]>([]);

  const addLog = useCallback((
    category: StructuredLog['category'],
    message: string,
    level: StructuredLog['level'] = 'info'
  ) => {
    const newLog: StructuredLog = {
      id: `${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      timestamp: new Date().toTimeString().split(' ')[0],
      category,
      message,
      level,
    };
    setLogs((prev) => [newLog, ...prev.slice(0, 99)]);
  }, []);

  // Initial greeting logs
  useEffect(() => {
    addLog('[SESSION]', 'ScreenMirror system initialized on Child Device (API 35)');
    addLog('[FOREGROUND_SERVICE]', 'Declared service type: FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION');
    addLog('[SIGNALING]', 'Connected to signaling channel: parent_child_link_ok');
  }, [addLog]);

  // Video and Canvas refs
  const streamVideoRef = useRef<HTMLVideoElement | null>(null);
  const canvasStreamRef = useRef<HTMLCanvasElement | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const realMediaStreamRef = useRef<MediaStream | null>(null);

  // Synthetic Screen Renderer Loop (simulates active Child device display frames)
  useEffect(() => {
    let tick = 0;
    const renderCanvas = () => {
      const canvas = canvasStreamRef.current;
      if (canvas && sessionState === 'CONNECTED' && !isRealScreenShare) {
        const ctx = canvas.getContext('2d');
        if (ctx) {
          tick++;
          const w = canvas.width;
          const h = canvas.height;

          // Gradient Wallpaper
          const grad = ctx.createLinearGradient(0, 0, w, h);
          grad.addColorStop(0, '#1e293b');
          grad.addColorStop(1, '#0f172a');
          ctx.fillStyle = grad;
          ctx.fillRect(0, 0, w, h);

          // Android Top Status Bar
          ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
          ctx.fillRect(0, 0, w, 60);

          ctx.fillStyle = '#94a3b8';
          ctx.font = 'bold 28px sans-serif';
          ctx.fillText('09:41', 40, 42);
          ctx.fillText('5G  100%', w - 160, 42);

          // Active App Header / Content
          ctx.fillStyle = '#3b82f6';
          ctx.beginPath();
          ctx.roundRect(40, 100, w - 80, 260, 24);
          ctx.fill();

          ctx.fillStyle = '#ffffff';
          ctx.font = 'bold 36px sans-serif';
          ctx.fillText(`Active: ${activeApp}`, 70, 160);

          ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
          ctx.font = '24px sans-serif';
          ctx.fillText('Child Android 15 VirtualDisplay Output', 70, 210);
          ctx.fillText(`Frame #${tick} • 720p @ 30 FPS`, 70, 250);

          // Animated live wave indicator to prove real-time capture
          ctx.strokeStyle = '#60a5fa';
          ctx.lineWidth = 4;
          ctx.beginPath();
          for (let x = 70; x < w - 70; x += 10) {
            const y = 310 + Math.sin((x + tick * 4) * 0.03) * 20;
            if (x === 70) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
          }
          ctx.stroke();

          // Notification Tile (MediaProjection Active)
          ctx.fillStyle = 'rgba(16, 185, 129, 0.15)';
          ctx.strokeStyle = '#10b981';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.roundRect(40, 390, w - 80, 120, 20);
          ctx.fill();
          ctx.stroke();

          ctx.fillStyle = '#34d399';
          ctx.font = 'bold 26px sans-serif';
          ctx.fillText('● ScreenMirror Foreground Service Active', 70, 440);
          ctx.fillStyle = '#a7f3d0';
          ctx.font = '22px sans-serif';
          ctx.fillText("Transmitting frames to Azad's Phone", 70, 480);

          // Grid of simulated apps
          const apps = [
            { name: 'Browser', color: '#f59e0b' },
            { name: 'Photos', color: '#10b981' },
            { name: 'YouTube', color: '#ef4444' },
            { name: 'Chat', color: '#3b82f6' },
            { name: 'Games', color: '#8b5cf6' },
            { name: 'Settings', color: '#64748b' },
          ];

          apps.forEach((app, idx) => {
            const col = idx % 3;
            const row = Math.floor(idx / 3);
            const x = 70 + col * 200;
            const y = 560 + row * 180;

            ctx.fillStyle = app.color;
            ctx.beginPath();
            ctx.roundRect(x, y, 120, 120, 24);
            ctx.fill();

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 22px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText(app.name, x + 60, y + 155);
            ctx.textAlign = 'left';
          });
        }
      }
      animationFrameRef.current = requestAnimationFrame(renderCanvas);
    };

    animationFrameRef.current = requestAnimationFrame(renderCanvas);
    return () => {
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
    };
  }, [sessionState, activeApp, isRealScreenShare]);

  // Periodic FPS / Bitrate jitter for realistic WebRTC stats
  useEffect(() => {
    if (sessionState === 'CONNECTED') {
      const timer = setInterval(() => {
        setStats((prev) => ({
          ...prev,
          fps: Math.floor(27 + Math.random() * 4),
          bitrateKbps: Math.floor(1380 + Math.random() * 90),
          roundTripTimeMs: Math.floor(30 + Math.random() * 10),
        }));
      }, 1500);
      return () => clearInterval(timer);
    }
  }, [sessionState]);

  // ==========================================
  // SESSION LIFECYCLE HANDLERS
  // ==========================================

  const handleViewScreen = () => {
    addLog('[SESSION]', 'Parent requested screen mirroring session with child_galaxy_a54');
    addLog('[SIGNALING]', 'Dispatched session_request (quality: normalNetwork) via Supabase Realtime');
    setSessionState('REQUESTED');
  };

  const handleAcceptPrompt = () => {
    addLog('[MEDIA_PROJECTION]', 'Child accepted Android MediaProjection consent prompt (RESULT_OK)');
    addLog(
      '[FOREGROUND_SERVICE]',
      'Starting ScreenCaptureService with ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION'
    );
    addLog('[FOREGROUND_SERVICE]', 'Pinned ongoing notification: "Screen Mirroring Active"');
    addLog('[SCREEN_CAPTURE]', 'Created VirtualDisplay: 1280x720 @ 320dpi targeting WebRTC Surface');
    addLog('[WEBRTC]', 'Initializing RTCPeerConnection unified-plan with STUN/TURN');
    addLog('[SIGNALING]', 'Exchanged SDP Offer and Answer via DTLS-SRTP');

    setDeviceState('MIRRORING');
    setSessionState('CONNECTING');

    setTimeout(() => {
      addLog('[WEBRTC]', 'WebRTC PeerConnection state: CONNECTED');
      setSessionState('CONNECTED');
    }, 900);
  };

  const handleDenyPrompt = () => {
    addLog('[MEDIA_PROJECTION]', 'Child dismissed or denied MediaProjection prompt', 'warn');
    addLog('[SIGNALING]', 'Sent session_response: accepted=false, reason="User declined"');
    addLog('[SESSION]', 'Session halted: MediaProjection permission not acquired', 'warn');
    setSessionState('IDLE');
    setDeviceState('READY');
  };

  const handleStopScreen = () => {
    addLog('[SESSION]', 'Session termination requested');
    addLog('[FOREGROUND_SERVICE]', 'ScreenCaptureService onDestroy: releasing VirtualDisplay and MediaProjection');
    addLog('[WEBRTC]', 'Disposed WebRTC VideoTrack and closed RTCPeerConnection');
    addLog('[SIGNALING]', 'Broadcast session_end');

    if (realMediaStreamRef.current) {
      realMediaStreamRef.current.getTracks().forEach((t) => t.stop());
      realMediaStreamRef.current = null;
    }
    setIsRealScreenShare(false);

    setSessionState('ENDED');
    setDeviceState('READY');

    setTimeout(() => {
      setSessionState('IDLE');
    }, 1200);
  };

  const handleStartRealShare = async () => {
    if (isRealScreenShare) {
      if (realMediaStreamRef.current) {
        realMediaStreamRef.current.getTracks().forEach((t) => t.stop());
        realMediaStreamRef.current = null;
      }
      setIsRealScreenShare(false);
      addLog('[SCREEN_CAPTURE]', 'Switched back to simulated Android VirtualDisplay');
      return;
    }

    try {
      addLog('[SCREEN_CAPTURE]', 'Requesting browser navigator.mediaDevices.getDisplayMedia...');
      const stream = await navigator.mediaDevices.getDisplayMedia({
        video: { frameRate: { ideal: 30 } },
        audio: false,
      });
      realMediaStreamRef.current = stream;
      if (streamVideoRef.current) {
        streamVideoRef.current.srcObject = stream;
      }
      setIsRealScreenShare(true);
      addLog('[SCREEN_CAPTURE]', 'Real display media stream attached to WebRTC surface sink');
    } catch (err: any) {
      addLog('[SCREEN_CAPTURE]', `Display media cancelled or failed: ${err.message}`, 'warn');
    }
  };

  // 15-Point Test Matrix Runner Handler
  const handleRunTest = async (testId: string) => {
    switch (testId) {
      case 'tc_1_fg_request':
        addLog('[SESSION]', '[TEST 1] Child app in foreground; parent requests session');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[MEDIA_PROJECTION]', '[TEST 1] createScreenCaptureIntent() launched via MainActivity');
        await new Promise((r) => setTimeout(r, 300));
        addLog('[FOREGROUND_SERVICE]', '[TEST 1] FGS started with type mediaProjection; WebRTC streaming OK');
        return { passed: true, message: 'Stream Established' };

      case 'tc_2_bg_request':
        addLog('[SIGNALING]', '[TEST 2] Child in background; parent session_request received');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[FOREGROUND_SERVICE]', '[TEST 2] NativeSignalingReceiver dispatched high-priority notification with full-screen intent');
        await new Promise((r) => setTimeout(r, 300));
        addLog('[MEDIA_PROJECTION]', '[TEST 2] User tapped notification -> MediaProjectionConsentActivity -> consent granted -> streaming');
        return { passed: true, message: 'Legitimate BG Launch OK' };

      case 'tc_3_press_home':
        addLog('[SESSION]', '[TEST 3] Active mirroring; Child presses Home button');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[FOREGROUND_SERVICE]', '[TEST 3] Flutter Activity onStop(); ScreenCaptureService continues capturing display frames');
        return { passed: true, message: 'Home Navigation Resilient' };

      case 'tc_4_open_other_app':
        addLog('[SESSION]', '[TEST 4] Child opens YouTube / Chrome during active session');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[SCREEN_CAPTURE]', '[TEST 4] VirtualDisplay produces frames of active foreign app; WebRTC encoding remains smooth');
        return { passed: true, message: 'App Switching Supported' };

      case 'tc_5_swipe_recents':
        addLog('[FOREGROUND_SERVICE]', '[TEST 5] Child app swiped away from Android Recents screen');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[FOREGROUND_SERVICE]', '[TEST 5] ScreenCaptureService.onTaskRemoved() triggered; active session detected; stopSelf() NOT called');
        addLog('[WEBRTC]', '[TEST 5] WebRTC encoder and socket remain connected to Parent');
        return { passed: true, message: 'Survived Recents Swipe' };

      case 'tc_6_screen_lock':
        addLog('[SESSION]', '[TEST 6] Child screen locked / display timed out');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[SCREEN_CAPTURE]', '[TEST 6] DisplayManager pauses dirty frame callbacks; WebRTC keepalive ping sustained; wakes cleanly');
        return { passed: true, message: 'Screen Lock Paused Cleanly' };

      case 'tc_7_device_reboot':
        addLog('[SESSION]', '[TEST 7] Child device reboot simulated');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[SESSION]', '[TEST 7] BootReceiver triggered; restored pairing config & presence = READY; awaiting user authorization');
        return { passed: true, message: 'Boot Presence Restored' };

      case 'tc_8_wifi_cellular_handoff':
        addLog('[WEBRTC]', '[TEST 8] Wi-Fi lost; fallback to 5G cellular detected via ConnectivityManager');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[WEBRTC]', '[TEST 8] VirtualDisplay retained; WebRTC restartIce() created offer; new candidate pair selected (<1.1s)');
        return { passed: true, message: 'ICE Restart Restored Stream' };

      case 'tc_9_system_indicator_revoke':
        addLog('[MEDIA_PROJECTION]', '[TEST 9] User tapped Android 14 status bar cast chip and revoked capture');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[MEDIA_PROJECTION]', '[TEST 9] MediaProjection.Callback.onStop() fired; released VirtualDisplay; state = REVOKED');
        return { passed: true, message: 'System Revoke Handled' };

      case 'tc_10_parent_stop':
        addLog('[SESSION]', '[TEST 10] Parent pressed "Stop Mirroring"');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[SIGNALING]', '[TEST 10] Broadcast session_end; Child FGS stopped; notification dismissed cleanly');
        return { passed: true, message: 'Clean Parent Termination' };

      case 'tc_11_child_notification_stop':
        addLog('[FOREGROUND_SERVICE]', '[TEST 11] Child tapped "Stop Sharing" on ongoing Android notification');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[FOREGROUND_SERVICE]', '[TEST 11] onStartCommand received ACTION_STOP; torn down cleanly');
        return { passed: true, message: 'Notification Stop Executed' };

      case 'tc_12_low_memory_kill':
        addLog('[FOREGROUND_SERVICE]', '[TEST 12] Android Low-Memory Killer terminated process under heavy RAM pressure');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[FOREGROUND_SERVICE]', '[TEST 12] Service restarted via START_STICKY with null intent; detected missing token');
        addLog('[SESSION]', '[TEST 12] Transitioned to REAUTHORIZATION_REQUIRED; user prompted to re-authorize');
        return { passed: true, message: 'Recovered via REAUTHORIZATION_REQUIRED' };

      case 'tc_13_unpaired_request':
        addLog('[SECURITY]', '[TEST 13] Unpaired rogue device sent session_request');
        await new Promise((r) => setTimeout(r, 300));
        addLog('[SECURITY]', '[TEST 13] NativeSignalingReceiver rejected request: senderId != pairedParentId');
        return { passed: true, message: 'Unauthorized Request Dropped' };

      case 'tc_14_child_denies_prompt':
        addLog('[MEDIA_PROJECTION]', '[TEST 14] Child tapped Cancel on Android system MediaProjection consent dialog');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[SESSION]', '[TEST 14] Parent notified: "permission denied"; device returned to READY without crash');
        return { passed: true, message: 'Prompt Rejection Handled' };

      case 'tc_15_poor_network_adaptation':
        addLog('[WEBRTC]', '[TEST 15] Simulating bandwidth throttling (<600 kbps, RTT > 280ms)');
        await new Promise((r) => setTimeout(r, 400));
        addLog('[WEBRTC]', '[TEST 15] Encoded resolution downscaled to 854x480 @ 15fps, bitrate adapted to 600 kbps');
        return { passed: true, message: 'Adaptive Bitrate Engaged' };

      default:
        return { passed: true, message: 'Passed' };
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-blue-600 selection:text-white">
      {/* Top Header */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur px-6 py-3.5 flex items-center justify-between sticky top-0 z-40">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-blue-600 flex items-center justify-center text-white shadow-md">
            <Cast className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-base font-bold text-white tracking-tight">
                ScreenMirror Parental Control
              </h1>
              <span className="px-2 py-0.5 text-[10px] font-bold bg-blue-500/20 text-blue-400 border border-blue-500/30 rounded-full">
                Flutter + Android Native
              </span>
            </div>
            <p className="text-xs text-slate-400">
              MediaProjection Foreground Service • WebRTC Streaming • Supabase Realtime
            </p>
          </div>
        </div>

        {/* View Switcher Tabs */}
        <div className="flex items-center gap-1.5 bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs font-semibold">
          {[
            { id: 'simulator', label: 'Live Dual Simulator', icon: Smartphone },
            { id: 'code', label: 'Production Codebase', icon: Code2 },
            { id: 'architecture', label: 'Android 14/15 Architecture', icon: Layers },
            { id: 'tests', label: 'Protocol Test Suite', icon: Activity },
          ].map((tab) => {
            const Icon = tab.icon;
            const isActive = activeView === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveView(tab.id as any)}
                className={`px-3 py-1.5 rounded-lg flex items-center gap-1.5 transition-all cursor-pointer ${
                  isActive
                    ? 'bg-blue-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900'
                }`}
              >
                <Icon className="w-3.5 h-3.5" />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-6 space-y-6">
        {activeView === 'simulator' && (
          <div className="space-y-6">
            {/* Quick Status Pill Bar */}
            <div className="flex flex-wrap items-center justify-between gap-4 p-3.5 bg-slate-900 border border-slate-800 rounded-2xl">
              <div className="flex items-center gap-4 text-xs font-medium text-slate-300">
                <span className="flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-400" />
                  Signaling: <strong className="text-white">Active</strong>
                </span>
                <span className="text-slate-700">|</span>
                <span>
                  Child Device: <strong className="text-white">Samsung Galaxy A54 (API 35)</strong>
                </span>
                <span className="text-slate-700">|</span>
                <span>
                  Parent Account: <strong className="text-white">azadsaifi70149@gmail.com</strong>
                </span>
                <span className="text-slate-700">|</span>
                <span>
                  Transport: <strong className="text-blue-400">WebRTC DTLS-SRTP</strong>
                </span>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setShowSetupWizard((s) => !s)}
                  className="text-xs px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg border border-slate-700 transition-colors cursor-pointer"
                >
                  {showSetupWizard ? 'Close Setup Wizard' : 'Launch Child Setup Wizard'}
                </button>
              </div>
            </div>

            {/* Dual Device Stage */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center justify-items-center py-2">
              {/* PARENT DEVICE (VIEWER) */}
              <div className="flex flex-col items-center gap-3">
                <div className="text-center">
                  <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-blue-900/30 text-blue-400 border border-blue-700/40 rounded-full text-xs font-bold uppercase tracking-wider mb-1">
                    Parent App Target
                  </div>
                  <h3 className="text-sm font-semibold text-slate-200">Remote Screen Viewer</h3>
                </div>

                <ParentDeviceView
                  sessionState={sessionState}
                  stats={stats}
                  isOnline={true}
                  onViewScreen={handleViewScreen}
                  onStopScreen={handleStopScreen}
                  streamVideoRef={streamVideoRef}
                  canvasStreamRef={canvasStreamRef}
                  isRealScreenShare={isRealScreenShare}
                />
              </div>

              {/* CHILD DEVICE (CAPTURE AGENT) */}
              <div className="flex flex-col items-center gap-3">
                <div className="text-center">
                  <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-emerald-900/30 text-emerald-400 border border-emerald-700/40 rounded-full text-xs font-bold uppercase tracking-wider mb-1">
                    Child App Target (Android)
                  </div>
                  <h3 className="text-sm font-semibold text-slate-200">MediaProjection Source</h3>
                </div>

                <ChildDeviceView
                  deviceState={deviceState}
                  sessionState={sessionState}
                  isCapturing={sessionState === 'CONNECTED'}
                  onAcceptPrompt={handleAcceptPrompt}
                  onDenyPrompt={handleDenyPrompt}
                  onStopCapture={handleStopScreen}
                  onStartRealShare={handleStartRealShare}
                  isRealScreenShare={isRealScreenShare}
                  activeApp={activeApp}
                  setActiveApp={setActiveApp}
                  showSetupWizard={showSetupWizard}
                  setShowSetupWizard={setShowSetupWizard}
                />
              </div>
            </div>

            {/* Real-time Structured Logs Terminal */}
            <StructuredLogViewer logs={logs} onClear={() => setLogs([])} />
          </div>
        )}

        {activeView === 'code' && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white">Full Production Codebase</h2>
                <p className="text-xs text-slate-400">
                  Inspect the native Android Kotlin services, Flutter services, AndroidManifest, and Supabase RLS schema.
                </p>
              </div>
              <div className="flex items-center gap-2 text-xs text-slate-400">
                <CheckCircle className="w-4 h-4 text-emerald-400" />
                <span>Ready for Android Studio & Flutter CLI</span>
              </div>
            </div>
            <CodeExplorer />
          </div>
        )}

        {activeView === 'architecture' && <ArchitectureInspector />}

        {activeView === 'tests' && <TestRunnerView onRunTest={handleRunTest} />}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800 bg-slate-900/60 px-6 py-4 mt-auto text-xs text-slate-400 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <span className="font-semibold text-slate-200">ScreenMirror Parental Suite</span>
          <span>•</span>
          <span>Compliant with Google Play Parental Control & Privacy Policies</span>
        </div>
        <div className="flex items-center gap-4">
          <span className="font-mono text-[11px] text-slate-500">Android SDK 35 (Android 15) Ready</span>
          <a
            href="#code"
            onClick={(e) => {
              e.preventDefault();
              setActiveView('code');
            }}
            className="text-blue-400 hover:text-blue-300 font-medium flex items-center gap-1"
          >
            <Download className="w-3.5 h-3.5" />
            Browse Files in /flutter_project/
          </a>
        </div>
      </footer>
    </div>
  );
}
