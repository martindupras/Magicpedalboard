// Diag_Probe_Sinks_A_B.scd
// v0.1
// MD 20250917-1146
//
// Purpose: Inspect both sinks safely: source object/class, playing/paused,
// monitor present? Helps detect if NEXT is still monitored or sourcing non-silent audio.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var probe;

probe = { arg key;
    var nx = Ndef(key), srcObj, srcClass, srcCode, mon, playing, paused;
    srcObj  = nx.source;
    srcClass= srcObj.class;
    srcCode = srcObj.tryPerform(\asCompileString);
    mon     = nx.monitor;
    playing = nx.isPlaying;
    paused  = nx.paused ? false;
    ("[PROBE] key=% class=% playing=% paused=% hasMonitor=%"
        .format(key, srcClass, playing, paused, mon.notNil)).postln;
    if(srcCode.notNil) {
        "[PROBE] source asCompileString:".postln;
        srcCode.postln;
    }{
        "[PROBE] (no asCompileString) printing .source:".postln;
        srcObj.postln;
    };
};

probe.(\chainA);
probe.(\chainB);
)
