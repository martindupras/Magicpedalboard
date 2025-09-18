// CT_SafeSmoke_NoDupes.scd
// v0.1
// MD 2025-09-18 10:16 BST
//
// Purpose:
// - Safely test CommandTree adapter without duplicate insertions.
// - Add exactly one \delay to NEXT, then switch once and verify audio.
// Style:
// - tilde vars; var-first; lowercase; no server.sync;
// - server ops inside Server.default.bind only when creating/updating Ndefs.

(
var log, countKey, assertOnce, printChainsShort, ensureAdapterOnce, ensureSource;

log = { arg s; ("[CT] " ++ s).postln };
countKey = { arg array, key; var c=0; array.do({ arg k; if(k == key) { c = c + 1 } }); c };
assertOnce = { arg list, key, label;
    var n;
    n = countKey.(list, key);
    ("[ASSERT] " ++ label ++ " — '" ++ key.asString ++ "' count=" ++ n).postln;
    if(n != 1) { ("[ASSERT] expected exactly 1; got " ++ n).warn };
};
printChainsShort = {
    var cur = ~mpb.effectiveCurrent, nxt = ~mpb.effectiveNext;
    ("[CHAINS] CURRENT=" ++ cur).postln;
    ("[CHAINS] NEXT   =" ++ nxt).postln;
};
ensureAdapterOnce = {
    if(~ct_applyOSCPathToMPB.isNil) {
        "adapter_commandtree_to_magicpedalboard.scd".loadRelative;
        log.("adapter loaded");
    }{
        log.("adapter already present");
    };
};
ensureSource = {
    // Make sure testmelody exists and is stereo; runner should have done this, but it's cheap
    Server.default.bind({
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig = Impulse.kr(3.2);
                var seq = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
                var f = Demand.kr(trig, 0, seq);
                var env = Decay2.kr(trig, 0.01, 0.35);
                var tone = SinOsc.ar(f) * env * 0.25;
                var pan = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
                Pan2.ar(tone, pan)
            });
        };
        Ndef(\testmelody).ar(2);
    });
};

// ---- run the safe smoke ----
ensureAdapterOnce.();
ensureSource.();

// 0) Known baseline: CURRENT audible, NEXT silent (runner already enforces Option A)
~mpb.printChains;

// 1) CLEAN the NEXT chain before we add anything
~mpb.clearChain;
~mpb.printChains;

// 2) Apply exactly one path "/add/delay" via adapter (no fallback tokens)
~ct_applyOSCPathToMPB.("/add/delay", ~mpb, ~gui);

// 3) Inspect NEXT; assert only one 'delay'
printChainsShort.();
assertOnce.(~mpb.effectiveNext, \delay, "after /add/delay");

// 4) Switch once with a short fade; CURRENT should now include \delay
~mpb.switchChain(0.12);

// 5) Post-switch: ensure audio & exclusivity
AppClock.sched(0.40, {
    printChainsShort.();
    ("[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    nil
});
)
