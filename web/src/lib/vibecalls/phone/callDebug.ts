/* eslint-disable no-console */

/**
 * FamilyGram phone-call debug: visible console lines + a copyable ring buffer.
 *
 * In DevTools console (both browsers):
 *   __fgCallDebug.dump()      // full JSON of last events
 *   __fgCallDebug.snapshot()  // last summary only
 *   __fgCallDebug.clear()
 *   __fgCallDebug.help()
 */

export type CallDebugLevel = 'info' | 'warn' | 'error';

export type CallDebugEntry = {
  t: string;
  level: CallDebugLevel;
  msg: string;
  data?: Record<string, unknown>;
};

const MAX_ENTRIES = 400;
const buffer: CallDebugEntry[] = [];
let enabled = true;
let seq = 0;

function safeJson(value: unknown): unknown {
  try {
    return JSON.parse(JSON.stringify(value, (_k, v) => {
      if (typeof v === 'bigint') return v.toString();
      if (v instanceof Error) {
        return { name: v.name, message: v.message, stack: v.stack };
      }
      if (typeof MediaStream !== 'undefined' && v instanceof MediaStream) {
        return {
          id: v.id,
          active: v.active,
          tracks: v.getTracks().map((tr) => ({
            kind: tr.kind,
            id: tr.id,
            enabled: tr.enabled,
            muted: tr.muted,
            readyState: tr.readyState,
            label: tr.label?.slice(0, 40),
          })),
        };
      }
      if (typeof MediaStreamTrack !== 'undefined' && v instanceof MediaStreamTrack) {
        return {
          kind: v.kind,
          id: v.id,
          enabled: v.enabled,
          muted: v.muted,
          readyState: v.readyState,
        };
      }
      return v;
    }));
  } catch {
    return String(value);
  }
}

export function setCallDebugEnabled(value: boolean) {
  enabled = value;
  console.info(`[PhoneCall][debug] ${value ? 'enabled' : 'disabled'}`);
}

export function isCallDebugEnabled() {
  return enabled;
}

export function callDebugLog(
  level: CallDebugLevel,
  msg: string,
  data: Record<string, unknown> = {},
) {
  if (!enabled) return;

  const entry: CallDebugEntry = {
    t: new Date().toISOString(),
    level,
    msg,
    data: Object.keys(data).length ? (safeJson(data) as Record<string, unknown>) : undefined,
  };
  buffer.push(entry);
  if (buffer.length > MAX_ENTRIES) {
    buffer.splice(0, buffer.length - MAX_ENTRIES);
  }

  const n = ++seq;
  const prefix = `[PhoneCall][P2P][#${n}] ${msg}`;
  const payload = entry.data ?? {};

  // Use info/warn (not console.debug) so Chrome shows lines without "Verbose".
  if (level === 'error') {
    console.error(prefix, payload);
  } else if (level === 'warn') {
    console.warn(prefix, payload);
  } else {
    console.info(prefix, payload);
  }
}

export function callDebugClear() {
  buffer.length = 0;
  seq = 0;
  console.info('[PhoneCall][debug] buffer cleared');
}

export function callDebugDump(): string {
  const text = JSON.stringify({
    generatedAt: new Date().toISOString(),
    count: buffer.length,
    entries: buffer,
  }, null, 2);
  console.info('[PhoneCall][debug] dump copied to return value; length=', text.length);
  return text;
}

export function callDebugSnapshot(): CallDebugEntry[] {
  return buffer.slice(-40);
}

export function callDebugHelp() {
  console.info([
    'FamilyGram call debug',
    '  __fgCallDebug.dump()      → JSON string of last events (copy from return value)',
    '  __fgCallDebug.snapshot()  → last ~40 entries',
    '  __fgCallDebug.clear()',
    '  __fgCallDebug.enable() / .disable()',
    'Filter console with: PhoneCall',
    'Make a video call on BOTH browsers, then run dump() on each and compare.',
  ].join('\n'));
}

export function installCallDebugGlobal() {
  if (typeof window === 'undefined') return;
  (window as any).__fgCallDebug = {
    dump: callDebugDump,
    snapshot: callDebugSnapshot,
    clear: callDebugClear,
    help: callDebugHelp,
    enable: () => setCallDebugEnabled(true),
    disable: () => setCallDebugEnabled(false),
    get entries() {
      return buffer.slice();
    },
  };
  console.info(
    '%c[FamilyGram] Call debug ready. Type __fgCallDebug.help()',
    'color:#5CC85E;font-weight:bold',
  );
}
