import React from 'react';
import { StructuredLog } from '../types';
import { Terminal, Trash2 } from 'lucide-react';

interface Props {
  logs: StructuredLog[];
  onClear: () => void;
}

export const StructuredLogViewer: React.FC<Props> = ({ logs, onClear }) => {
  const getBadgeColor = (category: string) => {
    switch (category) {
      case '[SCREEN_CAPTURE]':
        return 'bg-blue-500/20 text-blue-400 border-blue-500/30';
      case '[MEDIA_PROJECTION]':
        return 'bg-purple-500/20 text-purple-400 border-purple-500/30';
      case '[FOREGROUND_SERVICE]':
        return 'bg-amber-500/20 text-amber-400 border-amber-500/30';
      case '[WEBRTC]':
        return 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
      case '[SIGNALING]':
        return 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30';
      case '[SESSION]':
        return 'bg-rose-500/20 text-rose-400 border-rose-500/30';
      default:
        return 'bg-slate-700 text-slate-300 border-slate-600';
    }
  };

  return (
    <div className="bg-slate-950 border border-slate-800 rounded-xl overflow-hidden shadow-xl flex flex-col h-72">
      <div className="px-4 py-2.5 bg-slate-900/90 border-b border-slate-800 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Terminal className="w-4 h-4 text-emerald-400" />
          <span className="text-xs font-mono font-semibold tracking-wide text-slate-200 uppercase">
            Android & WebRTC Structured Engine Logs
          </span>
          <span className="px-1.5 py-0.5 text-[10px] font-mono bg-slate-800 text-slate-400 rounded">
            {logs.length} events
          </span>
        </div>
        <button
          onClick={onClear}
          className="text-slate-400 hover:text-slate-200 transition-colors p-1 hover:bg-slate-800 rounded"
          title="Clear logs"
        >
          <Trash2 className="w-3.5 h-3.5" />
        </button>
      </div>

      <div className="p-3 overflow-y-auto font-mono text-xs space-y-1.5 flex-1 bg-slate-950/70">
        {logs.length === 0 ? (
          <div className="text-slate-600 text-center py-8 italic">
            No system events logged yet. Trigger session actions above to observe real-time pipeline events.
          </div>
        ) : (
          logs.map((log) => (
            <div key={log.id} className="flex items-start gap-2 hover:bg-slate-900/40 p-1 rounded transition-colors">
              <span className="text-slate-500 text-[11px] shrink-0">{log.timestamp}</span>
              <span
                className={`px-1.5 py-0.5 rounded text-[10px] font-bold border shrink-0 ${getBadgeColor(
                  log.category
                )}`}
              >
                {log.category}
              </span>
              <span
                className={`text-slate-300 break-all leading-relaxed ${
                  log.level === 'error' ? 'text-rose-400' : log.level === 'warn' ? 'text-amber-300' : ''
                }`}
              >
                {log.message}
              </span>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
