// Fix_ForceStereo_And_Rebuild.scd
// v0.1
// MD 20250917-1155
//
// Purpose: Force ar(2) on every Ndef in CURRENT and NEXT effective lists,
//          then rebuild both chains (uses <<> internally in your class).
//          Lightweight, no rewiring here beyond your rebuildUnbound.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var ensureStereo, touchAll, rebuildBoth, curEff, nxtEff;

ensureStereo = { arg keySym; Ndef(keySym).ar(2) };

curEff = ~mpb.effectiveCurrent;
nxtEff = ~mpb.effectiveNext;

Server.default.bind({
    curEff.do({ arg k; ensureStereo.(k) });
    nxtEff.do({ arg k; ensureStereo.(k) });
    ~mpb.rebuildUnbound(~mpb.currentChain);  // uses Ndef(left) <<> Ndef(right)
    ~mpb.rebuildUnbound(~mpb.nextChain);
});

// Post quick status afterwards
AppClock.sched(0.25, {
    ("[PLAY] A=% B=%"
        .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    nil
});
)
