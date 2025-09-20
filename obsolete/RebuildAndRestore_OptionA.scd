// RebuildAndRestore_OptionA.scd
// v0.1
// MD 20250917-1230
//
// Purpose: Recover class-managed wiring and Option A without touching sink sources.
// Style: tilde vars, var-first, no server.sync, Server.default.bind.

(
var log;
log = { arg s; ("[RECOVER] " ++ s).postln };

if(~mpb.isNil) { "[RECOVER] ~mpb is nil".warn; ^nil };

Server.default.bind({
    ~mpb.rebuildUnbound(~mpb.currentChain);   // uses Ndef(left) <<> Ndef(right) internally
    ~mpb.rebuildUnbound(~mpb.nextChain);
});

~mpb.playCurrent;
~mpb.enforceExclusiveCurrentOptionA(0.1);

AppClock.sched(0.25, {
    var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying;
    ("[RECOVER] [PLAY] A=% B=%".format(a, b)).postln;
    nil
});
)
