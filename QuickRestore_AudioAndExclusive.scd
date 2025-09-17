// QuickRestore_AudioAndExclusive.scd
// v0.2
// MD 20250917-1338
//
// Purpose: If audio is quiet, rebuild class-managed wiring (uses Ndef(left) <<> Ndef(right))
//          and re-enforce Option A. No sink-source overwrites.

(
var log; log = { arg s; ("[RESTORE] " ++ s).postln };

if(~mpb.isNil) { "[RESTORE] ~mpb is nil".warn; ^nil };

Server.default.bind({
    ~mpb.rebuildUnbound(~mpb.currentChain);   // internally uses Ndef(left) <<> Ndef(right)
    ~mpb.rebuildUnbound(~mpb.nextChain);
});
~mpb.playCurrent;
~mpb.enforceExclusiveCurrentOptionA(0.1);

AppClock.sched(0.25, {
    var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying;
    ("[RESTORE] [PLAY] A=% B=%".format(a, b)).postln;
    nil
});
)
