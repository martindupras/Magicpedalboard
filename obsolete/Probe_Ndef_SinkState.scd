// Probe_Ndef_SinkState.scd
// v0.1
// MD 20250916-1700

//
// Purpose: Safely inspect a sink Ndef’s current source object and playing/paused/monitor status.
//          Uses .source (not .sourceCode) and prints class + optional asCompileString if available.
// Style:   tilde vars, var-first, lowercase names, no server.sync, Server.default.bind for server ops.

(
var key, nx, srcObj, srcClass, srcCode, mon, playing, paused;

key = \chainA; // change to \chainA if you want to probe A

nx       = Ndef(key);
srcObj   = nx.source;                 // current source object (Function or other)
srcClass = srcObj.class;
srcCode  = srcObj.tryPerform(\asCompileString); // may be nil if not supported
mon      = nx.monitor;                // monitor object (if any)
playing  = nx.isPlaying;
paused   = nx.paused ? false;         // NodeProxy sometimes keeps paused flag internally

("[PROBE] key=%  class=%  playing=%  paused=%  hasMonitor=%"
    .format(key, srcClass, playing, paused, mon.notNil)).postln;

if(srcCode.notNil) {
    "[PROBE] source asCompileString:".postln;
    srcCode.postln;
} {
    "[PROBE] source does not implement asCompileString; printing .source:".postln;
    srcObj.postln;
};
)
