import React, { useState } from 'react';
import { DeviceState, SessionState } from '../types';
import {
  Smartphone,
  CheckCircle2,
  StopCircle,
  Radio,
  Settings,
  Bell,
  Chrome,
  Image,
  Youtube,
  MessageSquare,
  ShieldAlert,
  HelpCircle,
} from 'lucide-react';

interface Props {
  deviceState: DeviceState;
  sessionState: SessionState;
  isCapturing: boolean;
  onAcceptPrompt: () => void;
  onDenyPrompt: () => void;
  onStopCapture: () => void;
  onStartRealShare: () => void;
  isRealScreenShare: boolean;
  activeApp: string;
  setActiveApp: (app: string) => void;
  showSetupWizard: boolean;
  setShowSetupWizard: (show: boolean) => void;
}

export const ChildDeviceView: React.FC<Props> = ({
  deviceState,
  sessionState,
  isCapturing,
  onAcceptPrompt,
  onDenyPrompt,
  onStopCapture,
  onStartRealShare,
  isRealScreenShare,
  activeApp,
  setActiveApp,
  showSetupWizard,
  setShowSetupWizard,
}) => {
  const [setupStep, setSetupStep] = useState(0);

  const isMirroring = deviceState === 'MIRRORING' || isCapturing;
  const isPrompting = sessionState === 'REQUESTED';

  return (
    <div className="w-[330px] h-[640px] bg-slate-900 rounded-[42px] p-3 shadow-2xl border-4 border-slate-700 flex flex-col relative overflow-hidden select-none">
      {/* Phone Camera Hole */}
      <div className="absolute top-4 left-1/2 -translate-x-1/2 w-28 h-5 bg-black rounded-full z-30 flex items-center justify-center">
        <div className="w-3 h-3 rounded-full bg-slate-950 border border-slate-800" />
      </div>

      {/* Screen Frame */}
      <div className="w-full h-full bg-slate-100 rounded-[34px] overflow-hidden flex flex-col relative text-slate-900 pt-7">
        {/* Android Status Bar */}
        <div className="px-5 py-1 text-[11px] font-semibold flex justify-between items-center text-slate-600 bg-white border-b border-slate-200/50">
          <div className="flex items-center gap-1.5">
            <span>09:41</span>
            {isMirroring && (
              <span className="flex items-center gap-1 bg-blue-100 text-blue-700 px-1 py-0.2 rounded text-[9px] font-bold">
                <Radio className="w-2.5 h-2.5 text-blue-600 animate-pulse" />
                Casting
              </span>
            )}
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-[10px] font-mono">Wi-Fi</span>
            <div className="w-4 h-2 border border-slate-600 rounded-xs relative">
              <div className="w-3 h-full bg-slate-700" />
            </div>
          </div>
        </div>

        {/* Android 14/15 Foreground Service Notification Bar (Always Visible During Mirroring) */}
        {isMirroring && (
          <div className="bg-blue-600 text-white px-3 py-1.5 text-[11px] flex items-center justify-between shadow-sm animate-in fade-in">
            <div className="flex items-center gap-1.5 truncate">
              <Bell className="w-3.5 h-3.5 text-blue-200 shrink-0" />
              <span className="truncate font-medium">Screen Mirroring Active</span>
            </div>
            <button
              onClick={onStopCapture}
              className="bg-white text-blue-700 hover:bg-blue-50 text-[10px] font-bold px-1.5 py-0.5 rounded cursor-pointer"
            >
              Stop
            </button>
          </div>
        )}

        {/* SETUP WIZARD OVERLAY */}
        {showSetupWizard ? (
          <div className="flex-1 p-4 bg-white flex flex-col justify-between overflow-y-auto">
            <div>
              <div className="flex items-center justify-between pb-3 border-b border-slate-100">
                <h3 className="font-bold text-sm text-slate-800">Child Setup Wizard</h3>
                <span className="text-xs text-blue-600 font-semibold">Step {setupStep + 1} of 4</span>
              </div>

              {setupStep === 0 && (
                <div className="py-4 space-y-2">
                  <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center mb-2">
                    <Smartphone className="w-5 h-5" />
                  </div>
                  <h4 className="font-bold text-sm text-slate-900">How Screen Sharing Works</h4>
                  <p className="text-xs text-slate-600 leading-relaxed">
                    This legitimate parental guidance feature allows your verified parent to view your screen in real time.
                  </p>
                  <div className="p-2.5 bg-slate-50 rounded-lg text-[11px] text-slate-700 space-y-1">
                    <p className="font-semibold text-slate-800">Guarantees:</p>
                    <p>• Never secret: status notification stays visible</p>
                    <p>• Screen only: no microphone or camera used</p>
                    <p>• Tap Stop anytime to disconnect immediately</p>
                  </div>
                </div>
              )}

              {setupStep === 1 && (
                <div className="py-4 space-y-2">
                  <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center mb-2">
                    <Bell className="w-5 h-5" />
                  </div>
                  <h4 className="font-bold text-sm text-slate-900">Notification Permission</h4>
                  <p className="text-xs text-slate-600 leading-relaxed">
                    Android 13+ requires <span className="font-mono text-slate-800">POST_NOTIFICATIONS</span> so the mandatory Foreground Service notice can remain visible while capturing.
                  </p>
                  <div className="p-2.5 bg-emerald-50 text-emerald-800 rounded-lg text-xs flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                    Permission Status: Granted
                  </div>
                </div>
              )}

              {setupStep === 2 && (
                <div className="py-4 space-y-2">
                  <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center mb-2">
                    <Settings className="w-5 h-5" />
                  </div>
                  <h4 className="font-bold text-sm text-slate-900">MediaProjection Policy</h4>
                  <p className="text-xs text-slate-600 leading-relaxed">
                    Android 14 & 15 require user consent each time a new capture session starts. The app handles this safely without trying to bypass security.
                  </p>
                </div>
              )}

              {setupStep === 3 && (
                <div className="py-4 space-y-2 text-center">
                  <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto mb-2">
                    <CheckCircle2 className="w-6 h-6" />
                  </div>
                  <h4 className="font-bold text-sm text-slate-900">Device Ready</h4>
                  <p className="text-xs text-slate-600">
                    Linked to parent account: <strong>Azad's Phone</strong>
                  </p>
                </div>
              )}
            </div>

            <div className="flex gap-2 pt-3 border-t border-slate-100">
              {setupStep > 0 && (
                <button
                  onClick={() => setSetupStep((s) => s - 1)}
                  className="px-3 py-2 bg-slate-100 text-slate-700 text-xs font-semibold rounded-lg"
                >
                  Back
                </button>
              )}
              <button
                onClick={() => {
                  if (setupStep < 3) {
                    setSetupStep((s) => s + 1);
                  } else {
                    setShowSetupWizard(false);
                  }
                }}
                className="flex-1 py-2 bg-blue-600 text-white text-xs font-semibold rounded-lg hover:bg-blue-700 cursor-pointer"
              >
                {setupStep === 3 ? 'Complete Setup' : 'Continue'}
              </button>
            </div>
          </div>
        ) : (
          // Standard Child App UI
          <div className="flex-1 p-4 flex flex-col justify-between bg-slate-50 overflow-y-auto">
            <div className="space-y-3">
              {/* Header with Setup trigger */}
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                  Child Device Manager
                </span>
                <button
                  onClick={() => setShowSetupWizard(true)}
                  className="text-xs text-blue-600 hover:text-blue-700 font-semibold flex items-center gap-1 cursor-pointer"
                >
                  <HelpCircle className="w-3.5 h-3.5" />
                  Setup
                </button>
              </div>

              {/* Status Card as requested */}
              <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-sm space-y-3 text-xs">
                <div>
                  <div className="text-slate-500 font-medium mb-1">Device Status</div>
                  <div className="flex items-center gap-1.5">
                    <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                    <span className="font-bold text-slate-800 text-sm">Connected</span>
                  </div>
                </div>

                <div className="pt-2 border-t border-slate-100">
                  <div className="text-slate-500 font-medium mb-1">Screen Mirroring</div>
                  <div className="flex items-center gap-1.5">
                    <span
                      className={`w-2.5 h-2.5 rounded-full ${
                        isMirroring ? 'bg-blue-600 animate-pulse' : 'bg-emerald-500'
                      }`}
                    />
                    <span className="font-bold text-slate-800 text-sm">
                      {isMirroring ? 'Mirroring' : 'Ready'}
                    </span>
                  </div>
                </div>

                <div className="pt-2 border-t border-slate-100">
                  <div className="text-slate-500 font-medium mb-0.5">Parent Device</div>
                  <div className="font-bold text-slate-900 text-sm">Azad's Phone</div>
                </div>
              </div>

              {/* Interactive Phone Simulation Apps */}
              <div className="bg-white rounded-2xl p-3 border border-slate-200 shadow-sm">
                <div className="text-[11px] font-semibold text-slate-600 mb-2 flex items-center justify-between">
                  <span>Simulate Child Screen Content</span>
                  <span className="text-[10px] text-blue-600 font-mono">Active: {activeApp}</span>
                </div>
                <div className="grid grid-cols-4 gap-2 text-center">
                  {[
                    { id: 'Chrome', icon: Chrome, label: 'Browser', color: 'text-amber-500' },
                    { id: 'Photos', icon: Image, label: 'Photos', color: 'text-emerald-500' },
                    { id: 'YouTube', icon: Youtube, label: 'YouTube', color: 'text-rose-500' },
                    { id: 'Messages', icon: MessageSquare, label: 'Chat', color: 'text-blue-500' },
                  ].map((app) => {
                    const Icon = app.icon;
                    const isSelected = activeApp === app.id;
                    return (
                      <button
                        key={app.id}
                        onClick={() => setActiveApp(app.id)}
                        className={`p-2 rounded-xl flex flex-col items-center gap-1 transition-all cursor-pointer ${
                          isSelected ? 'bg-blue-50 border border-blue-300 shadow-xs' : 'hover:bg-slate-50'
                        }`}
                      >
                        <Icon className={`w-5 h-5 ${app.color}`} />
                        <span className="text-[10px] font-medium text-slate-700">{app.label}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Real Browser Screen Share Option */}
              <div className="bg-blue-50/70 border border-blue-200/80 rounded-xl p-2.5 text-[11px] text-blue-900 flex items-center justify-between">
                <span className="font-medium">
                  {isRealScreenShare ? 'Broadcasting your real display' : 'Share real browser tab / screen'}
                </span>
                <button
                  onClick={onStartRealShare}
                  className="px-2 py-1 bg-blue-600 text-white font-semibold rounded text-[10px] hover:bg-blue-700 cursor-pointer"
                >
                  {isRealScreenShare ? 'Switch Synthetic' : 'Share Display'}
                </button>
              </div>
            </div>

            {/* Stop Mirroring Button */}
            <div className="pt-3">
              <button
                onClick={onStopCapture}
                disabled={!isMirroring}
                className="w-full py-3 bg-rose-600 hover:bg-rose-700 active:bg-rose-800 disabled:bg-slate-200 disabled:text-slate-400 text-white rounded-xl text-sm font-bold flex items-center justify-center gap-2 shadow-sm transition-colors cursor-pointer"
              >
                <StopCircle className="w-4 h-4" />
                Stop Mirroring
              </button>
            </div>
          </div>
        )}

        {/* ANDROID SYSTEM MEDIAPROJECTION DIALOG SIMULATION */}
        {isPrompting && (
          <div className="absolute inset-0 bg-black/60 z-40 flex items-end p-3 animate-in fade-in">
            <div className="w-full bg-white rounded-3xl p-5 shadow-2xl border border-slate-200 text-left space-y-3">
              <div className="w-10 h-10 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center">
                <ShieldAlert className="w-5 h-5" />
              </div>
              <div>
                <h4 className="font-bold text-sm text-slate-900">
                  Start recording or casting with ScreenMirror?
                </h4>
                <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                  ScreenMirror will have access to all of the information that is visible on your screen or played from your device while recording or casting.
                </p>
              </div>

              <div className="p-2 bg-slate-100 rounded-lg text-[10px] text-slate-500 font-mono">
                Requested by: Azad's Phone (Parent)
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  onClick={onDenyPrompt}
                  className="flex-1 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-bold transition-colors cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  onClick={onAcceptPrompt}
                  className="flex-1 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-xs font-bold transition-colors cursor-pointer"
                >
                  Start Now
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
