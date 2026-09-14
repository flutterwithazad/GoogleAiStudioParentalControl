import React, { useState } from 'react';
import { CheckCircle, XCircle, Play, RefreshCw, AlertTriangle, ShieldCheck } from 'lucide-react';

export interface TestCase {
  id: string;
  number: number;
  title: string;
  trigger: string;
  expectedResult: string;
  actualHandling: string;
  category: 'Foreground' | 'Background' | 'Recents' | 'Reboot' | 'Network' | 'Security' | 'Lifecycle' | 'OEM/Battery';
  status: 'idle' | 'running' | 'passed' | 'failed';
  resultMessage?: string;
  androidLimitation?: string;
}

interface Props {
  onRunTest: (testId: string) => Promise<{ passed: boolean; message: string }>;
}

export const TestRunnerView: React.FC<Props> = ({ onRunTest }) => {
  const [tests, setTests] = useState<TestCase[]>([
    {
      id: 'tc_1_fg_request',
      number: 1,
      title: 'Flutter Child in Foreground -> Parent Requests',
      trigger: 'Child app is open on screen. Parent presses "View Screen".',
      expectedResult: 'System MediaProjection consent dialog displays. Child grants. Native FGS starts with type mediaProjection, WebRTC streams to Parent.',
      actualHandling: 'MainActivity triggers createScreenCaptureIntent(). Result forwarded to ScreenCaptureService. Stream transitions to STREAMING.',
      category: 'Foreground',
      status: 'idle',
      androidLimitation: 'None. Standard legitimate Android MediaProjection flow.',
    },
    {
      id: 'tc_2_bg_request',
      number: 2,
      title: 'Flutter Child in Background -> Parent Requests',
      trigger: 'Child app minimized/in background. Parent requests session.',
      expectedResult: 'Child receives legitimate high-priority notification with full-screen intent. User taps -> prompt -> stream starts.',
      actualHandling: 'NativeSignalingReceiver receives request, validates pairing, displays interactive notification launching MediaProjectionConsentActivity.',
      category: 'Background',
      status: 'idle',
      androidLimitation: 'Android 10+ background activity launch restrictions prevent silent prompt; high-priority notification with full-screen intent is the legitimate Android path.',
    },
    {
      id: 'tc_3_press_home',
      number: 3,
      title: 'Child Starts Mirroring -> Presses Home',
      trigger: 'Mirroring is active. Child navigates to Home launcher.',
      expectedResult: 'Screen capture and WebRTC stream continue without interruption. Ongoing notification remains in status bar.',
      actualHandling: 'ScreenCaptureService runs independently of Flutter Activity. VirtualDisplay and WebRTC encoder continue capturing home screen frames.',
      category: 'Lifecycle',
      status: 'idle',
      androidLimitation: 'None. Foreground Service with type mediaProjection is designed for whole-device capture.',
    },
    {
      id: 'tc_4_open_other_app',
      number: 4,
      title: 'Child Starts Mirroring -> Opens Another App',
      trigger: 'Child opens YouTube or Chrome during active mirroring.',
      expectedResult: 'Screen capture and WebRTC stream continue seamlessly displaying the other app.',
      actualHandling: 'Flutter UI is stopped by Android OS, but native ScreenCaptureService continues drawing display frames to WebRTC video track.',
      category: 'Lifecycle',
      status: 'idle',
      androidLimitation: 'Apps containing FLAG_SECURE (banking, DRM content) will be blacked out by Android compositor automatically.',
    },
    {
      id: 'tc_5_swipe_recents',
      number: 5,
      title: 'Child Starts Mirroring -> Swipes Child from Recents',
      trigger: 'Child opens Android Recents screen and swipes away the Child app task.',
      expectedResult: 'Flutter Activity is destroyed, but native ScreenCaptureService DOES NOT STOP. WebRTC stream continues uninterrupted.',
      actualHandling: 'ScreenCaptureService.onTaskRemoved() is intercepted. stopSelf() is NOT called while mirroring is active. stopWithTask="false" in manifest.',
      category: 'Recents',
      status: 'idle',
      androidLimitation: 'Some aggressive OEM skins (e.g. MIUI/HyperOS aggressive task clear) force-kill services unless autostart/battery exemption is configured.',
    },
    {
      id: 'tc_6_screen_lock',
      number: 6,
      title: 'Child Starts Mirroring -> Screen Locks',
      trigger: 'Power button pressed or display times out.',
      expectedResult: 'Service remains alive. VirtualDisplay pauses frame production until screen wakes. Session does not crash.',
      actualHandling: 'DisplayManager pauses dirty frame callbacks. WebRTC maintains keepalive pings. Re-awakens on unlock.',
      category: 'Lifecycle',
      status: 'idle',
      androidLimitation: 'Android stops generating display buffer updates when screen is off to conserve battery.',
    },
    {
      id: 'tc_7_device_reboot',
      number: 7,
      title: 'Child Device Reboots -> BootReceiver Restores Presence',
      trigger: 'Child phone is restarted.',
      expectedResult: 'BootReceiver triggers upon BOOT_COMPLETED. Restores pairing and presence to READY. Awaits user authorization for future requests.',
      actualHandling: 'BootReceiver reads safe SharedPreferences, initializes NativeCaptureManager, reports state = READY. Never bypasses user consent.',
      category: 'Reboot',
      status: 'idle',
      androidLimitation: 'Direct-boot restrictions prior to first unlock; MediaProjection token cannot be pre-acquired.',
    },
    {
      id: 'tc_8_wifi_cellular_handoff',
      number: 8,
      title: 'Wi-Fi Drops and Switches to 4G/5G Cellular',
      trigger: 'Wi-Fi router disconnects; device falls back to mobile data.',
      expectedResult: 'MediaProjection and VirtualDisplay remain untouched. WebRTC performs ICE restart and resumes stream.',
      actualHandling: 'ConnectivityManager.NetworkCallback detects handoff. WebRTCService.restartIce() creates new SDP with updated ICE candidates.',
      category: 'Network',
      status: 'idle',
      androidLimitation: 'Brief 0.5s-2s freeze while NAT binding switches and ICE candidates re-pair.',
    },
    {
      id: 'tc_9_system_indicator_revoke',
      number: 9,
      title: 'Child Revokes Capture via Android Privacy Chip',
      trigger: 'Child taps green privacy chip / cast tile in status bar and stops capture.',
      expectedResult: 'Native MediaProjection.Callback.onStop() triggers. Service cleanly tears down. Parent notified state = REVOKED.',
      actualHandling: 'MediaProjection.Callback.onStop() fires. Service releases VirtualDisplay, transitions native state to REVOKED, sends session_end.',
      category: 'Security',
      status: 'idle',
      androidLimitation: 'Android 14+ gives user supreme control to revoke screen capture at any time.',
    },
    {
      id: 'tc_10_parent_stop',
      number: 10,
      title: 'Parent Presses Stop Mirroring',
      trigger: 'Parent taps red "Stop Mirroring" button on Parent device.',
      expectedResult: 'Signaling session_end sent. Child service cleanly terminates and resets to READY. Parent returns to dashboard.',
      actualHandling: 'Parent sends session_end message. Child SessionService invokes stopCapture(). ScreenCaptureService stops and removes notification.',
      category: 'Lifecycle',
      status: 'idle',
      androidLimitation: 'None. Clean peer-to-peer termination.',
    },
    {
      id: 'tc_11_child_notification_stop',
      number: 11,
      title: 'Child Presses Stop from Status Notification',
      trigger: 'Child taps "Stop Sharing" on ongoing Android notification.',
      expectedResult: 'PendingIntent triggers ACTION_STOP. Service releases projection and WebRTC tracks. Parent notified of session termination.',
      actualHandling: 'ScreenCaptureService.onStartCommand receives ACTION_STOP, calls stopCapture(), and broadcasts session_end.',
      category: 'Foreground',
      status: 'idle',
      androidLimitation: 'None. Mandatory Google Play requirement for all screen sharing apps.',
    },
    {
      id: 'tc_12_low_memory_kill',
      number: 12,
      title: 'Process Killed by Android Low-Memory Killer (LMK)',
      trigger: 'Heavy memory pressure causes Android OS to kill app process.',
      expectedResult: 'Service restarts via START_STICKY. Detects token expiration. Transitions to REAUTHORIZATION_REQUIRED with notification.',
      actualHandling: 'Android restarts service with null intent. Service detects lack of valid projection token, notifies user to re-authorize.',
      category: 'Lifecycle',
      status: 'idle',
      androidLimitation: 'MediaProjection tokens cannot be serialized or restored without fresh user consent on Android 14+.',
    },
    {
      id: 'tc_13_unpaired_request',
      number: 13,
      title: 'Unpaired Device Requests Screen Session',
      trigger: 'Rogue sender transmits session_request signaling packet.',
      expectedResult: 'Request is rejected immediately without displaying any prompt on Child device.',
      actualHandling: 'NativeSignalingReceiver checks senderId against NativeStorageHelper.getPairedParentId(). Discards unauthorized packet.',
      category: 'Security',
      status: 'idle',
      androidLimitation: 'None. Cryptographic pairing validation.',
    },
    {
      id: 'tc_14_child_denies_prompt',
      number: 14,
      title: 'Child Denies MediaProjection Prompt',
      trigger: 'Child taps "Cancel" on Android system MediaProjection dialog.',
      expectedResult: 'No crash. Parent is notified "MediaProjection permission denied". Both devices return to READY.',
      actualHandling: 'onActivityResult receives RESULT_CANCELED. Native state transitions to READY. Parent receives session_response with accepted=false.',
      category: 'Foreground',
      status: 'idle',
      androidLimitation: 'Android guarantees user can refuse screen recording at any point.',
    },
    {
      id: 'tc_15_poor_network_adaptation',
      number: 15,
      title: 'Poor Network -> Dynamic Bitrate Adaptation',
      trigger: 'Bandwidth drops below 800 kbps (simulated packet loss / RTT > 300ms).',
      expectedResult: 'WebRTC detects degradation and downscales bitrate and framerate (480p @ 15fps) to prevent disconnect.',
      actualHandling: 'WebRTC inbound/outbound RTP stats monitor RTT and packet loss. Encoded bitrate drops to 600 kbps.',
      category: 'Network',
      status: 'idle',
      androidLimitation: 'Physical cellular radio conditions may still cause transient packet drop.',
    },
  ]);

  const [isRunningAll, setIsRunningAll] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<string>('ALL');

  const runSingle = async (testId: string) => {
    setTests((prev) =>
      prev.map((t) => (t.id === testId ? { ...t, status: 'running', resultMessage: 'Simulating Android OS transition...' } : t))
    );

    const res = await onRunTest(testId);

    setTests((prev) =>
      prev.map((t) =>
        t.id === testId
          ? {
              ...t,
              status: res.passed ? 'passed' : 'failed',
              resultMessage: res.message,
            }
          : t
      )
    );
  };

  const runAll = async () => {
    setIsRunningAll(true);
    for (const test of tests) {
      await runSingle(test.id);
      await new Promise((r) => setTimeout(r, 350));
    }
    setIsRunningAll(false);
  };

  const categories = ['ALL', 'Recents', 'Foreground', 'Background', 'Lifecycle', 'Network', 'Security', 'Reboot'];
  const filteredTests = selectedCategory === 'ALL' ? tests : tests.filter((t) => t.category === selectedCategory);

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl p-5 shadow-xl text-slate-200 space-y-4">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-3 border-b border-slate-800 gap-3">
        <div>
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-emerald-400" />
            <h3 className="font-bold text-sm text-white">15-Point Android Lifecycle & Resilience Test Matrix</h3>
          </div>
          <p className="text-xs text-slate-400 mt-0.5">
            Strict verification of process death, swipe-from-Recents, START_STICKY, ICE restart, and MediaProjection consent.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={runAll}
            disabled={isRunningAll}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-600 hover:bg-blue-700 active:bg-blue-800 disabled:bg-slate-700 text-white rounded-lg text-xs font-semibold shadow-md transition-colors cursor-pointer"
          >
            {isRunningAll ? (
              <>
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                Running 15 Scenarios...
              </>
            ) : (
              <>
                <Play className="w-3.5 h-3.5" />
                Run All 15 Tests
              </>
            )}
          </button>
        </div>
      </div>

      {/* Category Filter Pills */}
      <div className="flex flex-wrap gap-1.5 pb-1">
        {categories.map((cat) => (
          <button
            key={cat}
            onClick={() => setSelectedCategory(cat)}
            className={`px-2.5 py-1 rounded-md text-[11px] font-medium transition-colors cursor-pointer ${
              selectedCategory === cat
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-750'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        {filteredTests.map((test) => (
          <div
            key={test.id}
            className="p-3.5 bg-slate-950 rounded-xl border border-slate-800 flex flex-col justify-between hover:border-slate-700 transition-colors"
          >
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <span className="font-mono text-[11px] font-bold text-blue-400">#{test.number}</span>
                <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-slate-800 text-slate-300">
                  {test.category}
                </span>
              </div>
              <h4 className="font-bold text-xs text-white mb-1">{test.title}</h4>
              <p className="text-[11px] text-slate-400 leading-relaxed mb-2">
                <span className="text-slate-500 font-semibold">Trigger: </span>
                {test.trigger}
              </p>
              <p className="text-[11px] text-slate-300 leading-relaxed mb-2">
                <span className="text-slate-500 font-semibold">Expected: </span>
                {test.expectedResult}
              </p>
              {test.androidLimitation && (
                <div className="p-2 rounded bg-slate-900/80 border border-slate-800/80 text-[10px] text-amber-300/90 mb-2 flex items-start gap-1.5">
                  <AlertTriangle className="w-3 h-3 text-amber-400 shrink-0 mt-0.5" />
                  <span>{test.androidLimitation}</span>
                </div>
              )}
            </div>

            <div className="pt-2.5 mt-1 border-t border-slate-900 flex items-center justify-between">
              <div className="text-[11px] flex items-center gap-1.5">
                {test.status === 'passed' && (
                  <>
                    <CheckCircle className="w-4 h-4 text-emerald-400 shrink-0" />
                    <span className="text-emerald-400 font-semibold text-[10px] leading-tight">{test.resultMessage}</span>
                  </>
                )}
                {test.status === 'failed' && (
                  <>
                    <XCircle className="w-4 h-4 text-rose-400 shrink-0" />
                    <span className="text-rose-400 font-semibold text-[10px] leading-tight">{test.resultMessage}</span>
                  </>
                )}
                {test.status === 'running' && (
                  <>
                    <RefreshCw className="w-3.5 h-3.5 animate-spin text-blue-400 shrink-0" />
                    <span className="text-blue-400 font-mono text-[10px]">Testing...</span>
                  </>
                )}
                {test.status === 'idle' && (
                  <span className="text-slate-500 text-[10px]">Ready</span>
                )}
              </div>

              <button
                onClick={() => runSingle(test.id)}
                disabled={test.status === 'running' || isRunningAll}
                className="px-2.5 py-1 bg-slate-800 hover:bg-slate-700 active:bg-slate-750 disabled:bg-slate-900 text-slate-200 rounded text-[11px] font-medium transition-colors cursor-pointer shrink-0 ml-2"
              >
                Run
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
