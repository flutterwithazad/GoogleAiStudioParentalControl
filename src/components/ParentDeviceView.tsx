import React from 'react';
import { SessionState, WebRTCStatsData } from '../types';
import { ShieldCheck, StopCircle } from 'lucide-react';

interface Props {
  sessionState: SessionState;
  stats: WebRTCStatsData;
  isOnline: boolean;
  onViewScreen: () => void;
  onStopScreen: () => void;
  streamVideoRef: React.RefObject<HTMLVideoElement | null>;
  canvasStreamRef: React.RefObject<HTMLCanvasElement | null>;
  isRealScreenShare: boolean;
}

export const ParentDeviceView: React.FC<Props> = ({
  sessionState,
  stats,
  isOnline,
  onViewScreen,
  onStopScreen,
  streamVideoRef,
  canvasStreamRef,
  isRealScreenShare,
}) => {
  const isViewing =
    sessionState === 'CONNECTING' ||
    sessionState === 'CONNECTED' ||
    sessionState === 'RECONNECTING';

  return (
    <div className="w-[330px] h-[640px] bg-slate-900 rounded-[42px] p-3 shadow-2xl border-4 border-slate-700 flex flex-col relative overflow-hidden select-none">
      {/* Phone Earpiece & Camera Punch hole */}
      <div className="absolute top-4 left-1/2 -translate-x-1/2 w-28 h-5 bg-black rounded-full z-30 flex items-center justify-center">
        <div className="w-3 h-3 rounded-full bg-slate-950 border border-slate-800" />
      </div>

      {/* Screen Frame */}
      <div className="w-full h-full bg-slate-50 rounded-[34px] overflow-hidden flex flex-col relative text-slate-900 pt-7">
        {/* Android Status Bar */}
        <div className="px-5 py-1 text-[11px] font-semibold flex justify-between items-center text-slate-600 border-b border-slate-200/60 bg-white">
          <span>09:41</span>
          <div className="flex items-center gap-1.5">
            <span className="text-[10px] font-mono">5G</span>
            <div className="w-4 h-2 border border-slate-600 rounded-xs relative">
              <div className="w-2.5 h-full bg-slate-700" />
            </div>
          </div>
        </div>

        {isViewing ? (
          // Active Mirroring View: STRICTLY Screen, Status, Resolution, FPS, Bitrate, Stop Button. NOTHING ELSE.
          <div className="flex-1 bg-black flex flex-col justify-between relative overflow-hidden">
            {/* Top HUD overlay */}
            <div className="bg-black/90 px-3 py-2 border-b border-white/10 flex items-center justify-between z-20 text-white">
              <div className="flex items-center gap-2">
                <span
                  className={`w-2.5 h-2.5 rounded-full ${
                    sessionState === 'CONNECTED'
                      ? 'bg-emerald-400 animate-pulse'
                      : 'bg-amber-400'
                  }`}
                />
                <span className="text-xs font-bold tracking-wide">
                  {sessionState === 'CONNECTED' ? 'LIVE' : sessionState}
                </span>
              </div>
              <div className="text-[11px] font-mono text-slate-300">
                {stats.width}x{stats.height} • {stats.fps} FPS • {stats.bitrateKbps} kbps
              </div>
            </div>

            {/* Video Viewport */}
            <div className="flex-1 flex items-center justify-center relative overflow-hidden bg-slate-950">
              {sessionState === 'CONNECTED' ? (
                isRealScreenShare ? (
                  <video
                    ref={streamVideoRef}
                    autoPlay
                    playsInline
                    muted
                    className="w-full h-full object-contain"
                  />
                ) : (
                  <canvas
                    ref={canvasStreamRef}
                    width={720}
                    height={1280}
                    className="w-full h-full object-contain"
                  />
                )
              ) : (
                <div className="flex flex-col items-center gap-3 p-4 text-center">
                  <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
                  <p className="text-xs text-slate-300 font-medium">
                    {sessionState === 'REQUESTED'
                      ? 'Waiting for Child authorization...'
                      : 'Negotiating WebRTC PeerConnection...'}
                  </p>
                </div>
              )}
            </div>

            {/* Stop button ONLY */}
            <div className="p-3 bg-black/95 z-20">
              <button
                onClick={onStopScreen}
                className="w-full py-3 bg-rose-600 hover:bg-rose-700 active:bg-rose-800 text-white rounded-xl text-sm font-bold tracking-wide flex items-center justify-center gap-2 transition-colors shadow-lg cursor-pointer"
              >
                <StopCircle className="w-4 h-4" />
                Stop Mirroring
              </button>
            </div>
          </div>
        ) : (
          // Main Screen: Child Device Card, Status, View Screen Button
          <div className="flex-1 p-5 flex flex-col justify-between bg-slate-50">
            <div>
              <div className="flex items-center gap-2 mb-4">
                <ShieldCheck className="w-5 h-5 text-blue-600" />
                <h2 className="text-base font-bold text-slate-800 tracking-tight">
                  Child Device
                </h2>
              </div>

              {/* Card */}
              <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-sm space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-slate-900">
                    Child's Galaxy A54
                  </span>
                  <div className="flex items-center gap-1.5">
                    <span
                      className={`w-2 h-2 rounded-full ${
                        isOnline ? 'bg-emerald-500' : 'bg-slate-400'
                      }`}
                    />
                    <span
                      className={`text-xs font-semibold ${
                        isOnline ? 'text-emerald-700' : 'text-slate-500'
                      }`}
                    >
                      {isOnline ? 'Online' : 'Offline'}
                    </span>
                  </div>
                </div>

                <div className="text-xs text-slate-500">
                  Last Seen: <span className="text-slate-700 font-medium">Just now</span>
                </div>

                <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-xs">
                  <span className="text-slate-600 font-medium">Screen Mirroring</span>
                  <span className="font-semibold text-slate-800">
                    {sessionState === 'ENDED' ? 'Ready' : sessionState === 'FAILED' ? 'Failed' : 'Ready'}
                  </span>
                </div>
              </div>
            </div>

            {/* View Screen Button */}
            <div className="pt-4">
              <button
                onClick={onViewScreen}
                disabled={!isOnline}
                className="w-full py-3.5 bg-blue-600 hover:bg-blue-700 active:bg-blue-800 disabled:bg-slate-300 text-white rounded-xl font-bold text-sm shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                View Screen
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
