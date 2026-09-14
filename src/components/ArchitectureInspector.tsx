import React, { useState } from 'react';
import { ShieldCheck, AlertTriangle, Layers, Cpu, Radio, Lock } from 'lucide-react';

export const ArchitectureInspector: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'android' | 'webrtc' | 'security' | 'lifecycle'>('android');

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl p-5 shadow-xl text-slate-200">
      {/* Tab Navigation */}
      <div className="flex flex-wrap gap-2 pb-4 border-b border-slate-800">
        {[
          { id: 'android', label: 'Android 14/15 Constraints', icon: ShieldCheck },
          { id: 'webrtc', label: 'MediaProjection -> WebRTC Pipeline', icon: Radio },
          { id: 'security', label: 'Legitimate vs Spyware Boundaries', icon: Lock },
          { id: 'lifecycle', label: 'Process Death & Foreground Services', icon: Layers },
        ].map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer ${
                isActive
                  ? 'bg-blue-600 text-white shadow-md'
                  : 'bg-slate-800 text-slate-400 hover:text-slate-200 hover:bg-slate-750'
              }`}
            >
              <Icon className="w-3.5 h-3.5" />
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Tab Content */}
      <div className="pt-4">
        {activeTab === 'android' && (
          <div className="space-y-3 text-xs leading-relaxed text-slate-300">
            <h4 className="text-sm font-bold text-white flex items-center gap-2">
              <Cpu className="w-4 h-4 text-blue-400" />
              Android MediaProjection & Foreground Service Restrictions
            </h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div className="p-3 bg-slate-950 rounded-xl border border-slate-800">
                <div className="font-bold text-amber-400 mb-1 flex items-center gap-1.5">
                  <AlertTriangle className="w-3.5 h-3.5" />
                  Android 14+ One-Time Token Lifecycle
                </div>
                <p>
                  Android 14 (<span className="font-mono text-slate-200">API 34</span>) enforces that MediaProjection tokens can no longer be cached indefinitely. Calling <span className="font-mono text-slate-200">getMediaProjection()</span> consumes the consent token. When a capture session terminates, a new consent intent must be authorized.
                </p>
              </div>

              <div className="p-3 bg-slate-950 rounded-xl border border-slate-800">
                <div className="font-bold text-blue-400 mb-1">
                  Mandatory Foreground Service Type
                </div>
                <p>
                  The service must declare <span className="font-mono text-slate-200">android:foregroundServiceType="mediaProjection"</span> in the Manifest and call <span className="font-mono text-slate-200">startForeground(id, notif, FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)</span> before or concurrently with creating the VirtualDisplay. Failing this throws an immediate <span className="font-mono text-rose-400">SecurityException</span>.
                </p>
              </div>

              <div className="p-3 bg-slate-950 rounded-xl border border-slate-800">
                <div className="font-bold text-emerald-400 mb-1">
                  Background-Start Restrictions
                </div>
                <p>
                  Android 14+ strictly prevents launching MediaProjection foreground services from the background. When the Parent requests a session, the Child app must either be brought to the foreground via high-priority notification or explicit user tap before starting capture.
                </p>
              </div>

              <div className="p-3 bg-slate-950 rounded-xl border border-slate-800">
                <div className="font-bold text-purple-400 mb-1">
                  System Privacy Indicators
                </div>
                <p>
                  Android OS draws a permanent system chip/icon in the status bar while capture is active. No legitimate app can (or should) suppress this indicator.
                </p>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'webrtc' && (
          <div className="space-y-3 text-xs leading-relaxed text-slate-300">
            <h4 className="text-sm font-bold text-white flex items-center gap-2">
              <Radio className="w-4 h-4 text-emerald-400" />
              Low Latency Screen Transport Pipeline
            </h4>
            <div className="p-4 bg-slate-950 rounded-xl border border-slate-800 font-mono text-slate-300 space-y-2">
              <div className="text-emerald-400 font-semibold">
                MediaProjection → VirtualDisplay → Surface → WebRTC VideoTrack → PeerConnection → SRTP/DTLS → Parent VideoView
              </div>
              <p className="text-slate-400 font-sans text-xs">
                Frames rendered by the Android WindowManager into the VirtualDisplay write directly into a hardware-backed Surface texture. This feeds WebRTC's H.264/VP8 hardware encoder with zero CPU copy overhead, ensuring battery efficiency and sub-100ms latency across 4G/5G networks.
              </p>
            </div>
            <div className="grid grid-cols-3 gap-2 text-center text-[11px]">
              <div className="p-2 bg-slate-950 rounded-lg border border-slate-800">
                <div className="font-bold text-slate-200">Good Network</div>
                <div className="text-slate-400">720p @ 30 FPS / ~2400 kbps</div>
              </div>
              <div className="p-2 bg-slate-950 rounded-lg border border-slate-800">
                <div className="font-bold text-slate-200">Normal Network</div>
                <div className="text-slate-400">720p @ 25 FPS / ~1400 kbps</div>
              </div>
              <div className="p-2 bg-slate-950 rounded-lg border border-slate-800">
                <div className="font-bold text-slate-200">Poor 4G / Congested</div>
                <div className="text-slate-400">480p @ 15 FPS / ~600 kbps</div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'security' && (
          <div className="space-y-3 text-xs leading-relaxed text-slate-300">
            <h4 className="text-sm font-bold text-white flex items-center gap-2">
              <Lock className="w-4 h-4 text-rose-400" />
              Compliance with Google Play & Android Security
            </h4>
            <div className="space-y-2">
              <div className="p-3 bg-emerald-950/40 border border-emerald-800/40 rounded-xl">
                <span className="font-bold text-emerald-400">Legitimate Parental Control Standards:</span>
                <ul className="list-disc list-inside mt-1 space-y-1 text-slate-300">
                  <li>Explicit child device pairing with authenticated parent credentials.</li>
                  <li>Persistent Foreground Service Notification informs child whenever screen is viewed.</li>
                  <li>Instant stop button available on Child status bar notification and main screen.</li>
                  <li>Strictly NO microphone, camera, contacts, or location snooping.</li>
                </ul>
              </div>
              <div className="p-3 bg-rose-950/40 border border-rose-800/40 rounded-xl">
                <span className="font-bold text-rose-400">Prohibited Surveillance Practices (Banned):</span>
                <p className="mt-1">
                  Attempting to hide MediaProjection dialogs, faking accessibility touches, running hidden services without ongoing notifications, or claiming "grant once and record forever without user interaction" violates Google Play Developer Policies and Android OS security.
                </p>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'lifecycle' && (
          <div className="space-y-3 text-xs leading-relaxed text-slate-300">
            <h4 className="text-sm font-bold text-white flex items-center gap-2">
              <Layers className="w-4 h-4 text-purple-400" />
              Process Lifecycle, Backgrounding & Clean Teardown
            </h4>
            <p>
              When the Child leaves the ScreenMirror app to browse other apps, the Foreground Service continues streaming the screen frames via the <span className="font-mono text-slate-200">VirtualDisplay</span>. If the user revokes permission from the system cast tile, <span className="font-mono text-slate-200">MediaProjection.Callback.onStop()</span> executes immediately, shutting down the encoder and sending a <span className="font-mono text-slate-200">session_end</span> message to the Parent.
            </p>
          </div>
        )}
      </div>
    </div>
  );
};
