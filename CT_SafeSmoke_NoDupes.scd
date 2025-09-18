// CT_SafeSmoke_NoDupes.scd
// v0.1.1
// MD 2025-09-18 11:30 BST

// Purpose:
// - Safe CommandTree-mimic smoke: add exactly one \delay to NEXT, ensure NEXT source is \testmelody,
//   then switch once and verify exclusivity with audio.
// Style:
// - tilde vars; var-first in functions/closures; lowercase names; no server.sync;
// - server ops inside Server.default.bind only when creating/updating Ndefs.

(
var log, countKey, assertOnce, printChainsShort, ensureAdapterOnce, ensureSource;
log = { arg s; ("[CT] " ++ s).postln };
countKey = { arg array, key; var c=0; array.do({ arg k; if(k == key) { c = c + 1 } }); c };
assertOnce = { arg list, key, label;
    var n; n = countKey.(list, key);
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
    // Ensure \testmelody exists (stereo). Cheap and idempotent.
    Server.default.bind({
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig = Impulse.kr(3.2);
                var seq = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                var f = Demand.kr(trig, 0, seq);
                var env = Decay2.kr(trig, 0.01, 0.35);
                var pan = ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
                Pan2.ar(SinOsc.ar(f) * env * 0.25, pan)
            });
        };
        Ndef(\testmelody).ar(2);
    });
};

// --- run the safe smoke ---
ensureAdapterOnce.();
ensureSource.();

// 0) Baseline visibility
~mpb.printChains;

// 1) Clean NEXT
~mpb.clearChain;
~mpb.printChains;

// 2) Add exactly one delay to NEXT via adapter
~ct_applyOSCPathToMPB.("/add/delay", ~mpb, ~gui);

// 3) Ensure NEXT source is audible BEFORE switching  <<—— added fix
~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);

// Inspect NEXT; assert only one 'delay'
printChainsShort.();
assertOnce.(~mpb.effectiveNext, \delay, "after /add/delay + /setSource/testmelody");

// 4) Switch once with a short fade; CURRENT should now include \delay and end with \testmelody
~mpb.switchChain(0.12);

// 5) Post-switch checks
AppClock.sched(0.40, {
    printChainsShort.();
    ("[PLAY] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    nil
});
)
