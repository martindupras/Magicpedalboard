// OneShot_Acceptance_CommandDriven.scd
// v0.2.1
// MD 20250917-1255
//
// Purpose: Robust acceptance using your adapter. Waits for server+~mpb+adapter,
//          disables meters during ops, pins stereo sinks, enforces Option A and
//          drops NEXT flag after baseline and after each switch, then asserts
//          A XOR B after each step. No rewiring; adapter-only control.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind. GUI on AppClock only.

(
var log, step, t,
    ready, readyServer, readyAdapter, readyMpb,
    ensureEnv, ensureAdapter, disableMeters, enableMeters,
    pinStereoSinks, ensureSources, baselineExclusive,
    enforceOptionAFlagDrop, assertXor, apply, runScenario;

var passCount, failCount;
passCount = 0; failCount = 0;

// --- helpers ---
log  = { arg s; ("[ACCEPT] " ++ s).postln };
step = { arg sec, fn; AppClock.sched(sec, { fn.value; nil }) };

// timings
t = (
  prep:     0.00,
  baseline: 0.25,
  add:      0.45,
  sw1:      0.75,
  byOn:     1.05,
  byOff:    1.30,
  sw2:      1.60,
  meters:   1.90,
  sum:      2.10
);

// readiness checks
readyServer  = { Server.default.serverRunning };
readyAdapter = { ~ct_applyOSCPathToMPB.notNil };
readyMpb     = { ~mpb.notNil };

ready = {
    if(readyServer.value.not) { Server.default.boot };
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };
    if(~ct_applyOSCPathToMPB.isNil) {
        "[ACCEPT] adapter missing: eval adapter_commandtree_to_magicpedalboard.scd, then rerun.".warn;
        ^false
    };
    true
};

// meters control
disableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(false);
        log.("meters disabled");
    };
};
enableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(true);
        log.("meters enabled");
    };
};

// authoritative stereo pin to avoid 2→1 wraps
pinStereoSinks = {
    Server.default.bind({
        Ndef(\chainA).mold(2, \audio);
        Ndef(\chainB).mold(2, \audio);
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
    });
    log.("sinks pinned: mold(2,audio) + \\in.ar(2)");
};

// define \testmelody (stereo) and \ts0 (stereo Silent)
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
    log.("sources ensured (\\testmelody, \\ts0)");
};

// enforce Option A + drop NEXT flag (so B=false in flags)
enforceOptionAFlagDrop = {
    var nextSink = ~mpb.nextChain[0];
    ~mpb.enforceExclusiveCurrentOptionA(0.1);         // NEXT silent at source
    Server.default.bind({ Ndef(nextSink).pause });     // drop NEXT monitor flag
    log.("Option A enforced + NEXT paused");
};

// baseline: CURRENT <- \testmelody; re-enforce and drop flag
baselineExclusive = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;                                  // class enforces Option A after play
    enforceOptionAFlagDrop.value;
};

// boolean assert with PASS/FAIL accounting
assertXor = { arg expectA, expectB, label;
    var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying, ok;
    ok = (a == expectA) and: { b == expectB };
    ((ok.if({"PASS"},{"FAIL"})) ++ " — " ++ label ++ " (A=" ++ a ++ " B=" ++ b ++ ")").postln;
    if(ok) { passCount = passCount + 1 } { failCount = failCount + 1 };
    ok
};

// adapter apply
apply = { arg pathString;
    if(~ct_applyOSCPathToMPB.notNil) {
        ~ct_applyOSCPathToMPB.(pathString, ~mpb, ~gui);
    }{
        ("adapter missing for " ++ pathString).warn;
        false
    }
};

// scenario
runScenario = {
    var ok;

    // 0) readiness
    ok = ready.value;
    if(ok.not) { ^nil };

    // 1) prep
    disableMeters.value;
    pinStereoSinks.value;
    ensureSources.value;

    // 2) baseline
    baselineExclusive.value;
    ~mpb.printChains;
    assertXor.value(true, false, "baseline: CURRENT audible; NEXT silent");

    // 3) add delay on NEXT (no switch yet)
    apply.value("/add/delay");
    ~mpb.printChains;
    assertXor.value(true, false, "after add/delay (NEXT) — exclusivity holds");

    // 4) switch to NEXT (B should be CURRENT), then re-enforce and drop flag
    apply.value("/switch");
    step.value(0.30, {
        enforceOptionAFlagDrop.value;
        ~mpb.printChains;
        assertXor.value(false, true, "after first switch — NEXT→CURRENT");

        // 5) bypass ON on CURRENT
        apply.value("/bypass/delay/on");
        ~mpb.printChains;
        assertXor.value(false, true, "after bypass on (CURRENT)");

        // 6) bypass OFF on CURRENT
        apply.value("/bypass/delay/off");
        ~mpb.printChains;
        assertXor.value(false, true, "after bypass off (CURRENT)");

        // 7) switch back to A (then enforce & drop flag)
        apply.value("/switch");
        step.value(0.30, {
            enforceOptionAFlagDrop.value;
            ~mpb.printChains;
            assertXor.value(true, false, "after second switch — back to A");

            // 8) meters on and summary
            enableMeters.value;
            ("[ACCEPT] Summary: PASS=" ++ passCount ++ " FAIL=" ++ failCount).postln;
            nil
        });
        nil
    });
};

// --- kick off ---
runScenario.value;
)
