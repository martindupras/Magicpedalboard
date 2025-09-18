// CT_TokenQueue_Manual_Milestone.scd
// v0.1.1
// MD 2025-09-18 15:19 BST

// Purpose:
// - Prove that MagicPedalboardNew responds to CommandTree-like *tokens* today,
//   without any Routine/Task runners (no chance of resume errors).
// - Steps: ensure sources (idempotent) -> apply tokens in order -> single tail verify.
// Style:
// - var-first in every function/closure; lowercase names; no server.sync;
// - server ops inside Server.default.bind only where needed; GUI on AppClock.

(
var log, ensureSources, guardSwitchAudible, applyPath, verifyTail, ok;

log = { arg s; var t; t = "[TOKENS] " ++ s; t.postln };

// quick guards
ok = (~mpb.isNil.not) and: { ~gui.isNil.not } and: { ~ct_applyOSCPathToMPB.notNil };
if(ok.not) {
    "[TOKENS] Missing ~mpb/~gui or adapter. Run StartHere... and adapter_*.scd first.".warn;
    ^nil;
};

// define generated sources if needed (no SoundIn)
ensureSources = {
    Server.default.bind({
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig, seq, f, env, pan;
                trig = Impulse.kr(3.2);
                seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                f    = Demand.kr(trig, 0, seq);
                env  = Decay2.kr(trig, 0.01, 0.35);
                pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
                Pan2.ar(SinOsc.ar(f) * env * 0.25, pan)
            });
        };
        Ndef(\testmelody).ar(2);
        Ndef(\ts0, { Silent.ar(2) });  Ndef(\ts0).ar(2);
    });
};

// ensure NEXT isn’t silent before switching
guardSwitchAudible = {
    var effNext, last;
    effNext = ~mpb.effectiveNext;
    last = effNext[effNext.size - 1];
    if(last == \ts0) {
        log.("guard: NEXT tail \\ts0 -> injecting /setSource/testmelody before /switch");
        ~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);
    };
};

// tiny wrapper around your adapter path applier (for logging)
applyPath = { arg path;
    var p;
    p = path;
    log.("apply -> " ++ p);
    ~ct_applyOSCPathToMPB.(p, ~mpb, ~gui);
};

// verify once after fades
verifyTail = {
    AppClock.sched(0.8, {
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
        ~mpb.printChains;
        nil
    });
};

// ---- run steps synchronously (no Routine/Task) ----
ensureSources.();

// 1) Make both chains end with \testmelody once (idempotent), and keep Option A:
if(~mpb.effectiveCurrent.last != \testmelody) { ~mpb.setSourceCurrent(\testmelody) };
if(~mpb.effectiveNext   .last != \testmelody) { ~mpb.setSource(\testmelody) };
~mpb.enforceExclusiveCurrentOptionA(0.1);

// 2) Mimic CommandTree tokens via canonical adapter paths:

// ["insert","delay"]  -> "/add/delay"  (applies to NEXT)
applyPath.("/add/delay");

// ["switch"] -> "/switch"  (guard ensures audible NEXT)
guardSwitchAudible.();
applyPath.("/switch");

// ["bypass","delay","on"]  -> "/bypass/delay/on"  (acts on NEXT chain in your adapter semantics)
applyPath.("/bypass/delay/on");

// ["bypass","delay","off"] -> "/bypass/delay/off"
applyPath.("/bypass/delay/off");

// ["switch"] -> "/switch" (again)
guardSwitchAudible.();
applyPath.("/switch");

// 3) One final verification print (PLAY flags + chains)
verifyTail.();
)
