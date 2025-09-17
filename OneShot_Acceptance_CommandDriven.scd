// OneShot_Acceptance_CommandDriven.scd
// v0.1
// MD 20250917-1238
//
// Purpose: Canonical acceptance: baseline (CURRENT audible; NEXT silent) then
//          /add/delay → /switch → /bypass/delay/on → /bypass/delay/off → /switch,
//          with A/B exclusivity checks (A XOR B) and PASS/FAIL summary.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind. GUI on AppClock only.

(
var log, step, t,
    checkAdapter, ensureAlias, ensureStereoPins, ensureSources,
    baselineExclusive, assertXor, apply, scenario, summary;

var passCount, failCount;
passCount = 0; failCount = 0;

// --- helpers ---
log  = { arg s; ("[ACCEPT] " ++ s).postln };
step = { arg sec, fn; AppClock.sched(sec, { fn.value; nil }) };

// timeline (seconds)
t = (
  check:   0.00,
  pin:     0.05,
  source:  0.15,
  base:    0.30,
  add:     0.50,
  sw1:     0.80,
  byOn:    1.10,
  byOff:   1.40,
  sw2:     1.70,
  sum:     2.10
);

// adapter + alias checks
checkAdapter = {
    var ok1 = ~ct_applyOSCPathToMPB.notNil;
    if(ok1.not) { "[ACCEPT] adapter missing: eval adapter_commandtree_to_magicpedalboard.scd".warn; ^false };
    true
};
ensureAlias = {
    if(~pedalboard.isNil and: { ~mpb.notNil }) { ~pedalboard = ~mpb; };
};

// pin sinks to stereo decisively; keep robust \in.ar(2)
ensureStereoPins = {
    Server.default.bind({
        Ndef(\chainA).mold(2, \audio);
        Ndef(\chainB).mold(2, \audio);
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
    });
};

// define \testmelody (stereo), ensure \ts0 (stereo Silent)
ensureSources = {
    Server.default.bind({
        Ndef(\testmelody, {
            var trig = Impulse.kr(3.2);
            var seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
            var f    = Demand.kr(trig, 0, seq);
            var env  = Decay2.kr(trig, 0.01, 0.35);
            var tone = SinOsc.ar(f) * env * 0.25;
            var pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
            Pan2.ar(tone, pan)
        }); Ndef(\testmelody).ar(2);

        Ndef(\ts0, { Silent.ar(2) }); Ndef(\ts0).ar(2);
    });
};

// baseline: CURRENT <- \testmelody; Option A enforced; NEXT flag dropped
baselineExclusive = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;                         // class-level enforcement after play
    ~mpb.enforceExclusiveCurrentOptionA(0.1); // NEXT hard-silenced
    Server.default.bind({ Ndef(~mpb.nextChain[0]).pause }); // ensure B=false flag
};

// assert A XOR B equals expected; count PASS/FAIL
assertXor = { arg expectAPlaying, expectBPlaying, label;
    var a = Ndef(\chainA).isPlaying;
    var b = Ndef(\chainB).isPlaying;
    var ok = (a == expectAPlaying) and: { b == expectBPlaying };
    var tag = if(ok) { "PASS" } { "FAIL" };
    ("[ACCEPT] " ++ tag ++ " — " ++ label ++ " (A=" ++ a ++ " B=" ++ b ++ ")").postln;
    if(ok) { passCount = passCount + 1 } { failCount = failCount + 1 };
};

// apply one adapter path
apply = { arg pathString; ~ct_applyOSCPathToMPB.(pathString, ~mpb, ~gui) };

// main scenario
scenario = {
    if(checkAdapter.().not) { ^nil };
    ensureAlias.();
    ensureStereoPins.();
    ensureSources.();
    baselineExclusive.();
    ~mpb.printChains;
    assertXor.(true, false, "baseline: CURRENT audible; NEXT silent");

    // [1] add delay to NEXT (no switch yet)
    apply.("/add/delay");
    ~mpb.printChains;
    assertXor.(true, false, "after add/delay (NEXT) — exclusivity holds");

    // [2] switch (short crossfade) → expect B=true
    apply.("/switch");
    step.(0.30, {
        ~mpb.printChains;
        assertXor.(false, true, "after first switch — NEXT→CURRENT");

        // [3] bypass on (CURRENT)
        apply.("/bypass/delay/on");
        ~mpb.printChains;
        assertXor.(false, true, "after bypass on (CURRENT)");

        // [4] bypass off (CURRENT)
        apply.("/bypass/delay/off");
        ~mpb.printChains;
        assertXor.(false, true, "after bypass off (CURRENT)");

        // [5] switch back → expect A=true
        apply.("/switch");
        step.(0.30, {
            ~mpb.printChains;
            assertXor.(true, false, "after second switch — back to A");

            // summary
            ("[ACCEPT] Summary: PASS=" ++ passCount ++ " FAIL=" ++ failCount).postln;
            nil
        });
        nil
    });
};

// run the timed plan
Server.default.boot;
step.(t[\check],  { scenario.value });
)
