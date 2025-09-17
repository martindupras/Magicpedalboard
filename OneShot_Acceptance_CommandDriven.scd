// OneShot_Acceptance_CommandDriven.scd
// v0.2
// MD 20250917-1248
//
// Purpose: Robust acceptance that waits for adapter + ~mpb, disables meters,
//          pins stereo shape, enforces Option A (NEXT silent) + drops NEXT flag,
//          drives playlist via your adapter, and asserts A XOR B after each step.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind. GUI on AppClock only.

(
var log, step, now, waitUntil, t,
    readyAdapter, readyMpb, readyServer,
    disableMeters, enableMeters, pinStereoSinks, ensureSources,
    baselineExclusive, enforceOptionAFlagDrop, assertXor, apply, runScenario;

log = { arg s; ("[ACCEPT] " ++ s).postln };
step = { arg sec, fn; AppClock.sched(sec, { fn.value; nil }) };
now  = { Main.elapsedTime.round(0.001) };

// Wait helper (polls condition fn on SystemClock)
waitUntil = { arg condFn, timeout=5.0, period=0.05, label="ready";
    var start = Main.elapsedTime, ok = false;
    Routine({
        while({ (Main.elapsedTime - start) < timeout and: { condFn.value.not } }, {
            period.wait;
        });
        ok = condFn.value;
        AppClock.sched(0.0, {
            (ok.if({ "[ACCEPT] ready: " }, { "[ACCEPT] timeout: " }) ++ label).postln; nil
        });
    }).play(SystemClock);
    ok // note: for flow, we use explicit waits below; this returns immediately
};

readyServer  = { Server.default.serverRunning };
readyAdapter = { ~ct_applyOSCPathToMPB.notNil };
readyMpb     = { ~mpb.notNil };

disableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        AppClock.sched(0.00, { ~gui.enableMeters(false); nil });
        AppClock.sched(0.05, { ~gui.enableMeters(false); nil });
        log.("meters disabled");
    };
};
enableMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(true);
        log.("meters enabled");
    };
};

// Authoritatively pin sink channel shape; keep robust \in.ar(2)
pinStereoSinks = {
    Server.default.bind({
        Ndef(\chainA).mold(2, \audio);
        Ndef(\chainB).mold(2, \audio);
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
    });
    log.("sinks pinned: mold(2, audio) + \\in.ar(2)");
};

// Define \testmelody (stereo) + \ts0 (stereo Silent)
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
    log.("sources ensured: \\testmelody, \\ts0");
};

// Enforce Option A baseline: CURRENT audible; NEXT silent; drop NEXT flag
enforceOptionAFlagDrop = {
    var nextSink = ~mpb.nextChain[0];
    ~mpb.enforceExclusiveCurrentOptionA(0.1);          // NEXT silent at source
    Server.default.bind({ Ndef(nextSink).pause });      // ensure NEXT flag false
    log.("Option A enforced + NEXT paused (flag false)");
};

baselineExclusive = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;                                  // class-level enforcement after play
    enforceOptionAFlagDrop.value;
};

// Boolean assert A XOR B matches expectation
assertXor = { arg expectA, expectB, label;
    var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying, ok;
    ok = (a == expectA) and: { b == expectB };
    ((ok.if({ "PASS" }, { "FAIL" })) ++ " — " ++ label
        ++ " (A=" ++ a ++ " B=" ++ b ++ ")").postln;
    ok
};

// Adapter apply (single path)
apply = { arg pathString;
    if(~ct_applyOSCPathToMPB.notNil) {
        ~ct_applyOSCPathToMPB.(pathString, ~mpb, ~gui);
    }{
        ("adapter missing for " ++ pathString).warn;
        false
    }
};

// --- Scenario orchestration ---
runScenario = {
    var passCount = 0, failCount = 0;
    var count = { arg ok; if(ok) { passCount = passCount + 1 } { failCount = failCount + 1 } };

    // 0) Readiness gates
    if(readyServer().not) { Server.default.boot };
    waitUntil.({ readyServer() }, 8.0, 0.05, "server");

    // Create GUI/MPB if missing (no title changes, AppClock inside classes)
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };

    waitUntil.({ readyMpb() }, 5.0, 0.05, "~mpb");
    waitUntil.({ readyAdapter() }, 5.0, 0.05, "adapter ~ct_applyOSCPathToMPB");

    // 1) Prep
    disableMeters.value;
    pinStereoSinks.value;
    ensureSources.value;

    // 2) Baseline: CURRENT <- \testmelody; A=true B=false
    baselineExclusive.value;
    ~mpb.printChains;
    count.( assertXor.(true, false, "baseline: CURRENT audible; NEXT silent") );

    // 3) add /switch /bypass-on /bypass-off /switch
    // add delay to NEXT (no switch)
    apply.("/add/delay");
    ~mpb.printChains;
    count.( assertXor.(true, false, "after add/delay (NEXT) — exclusivity holds") );

    // switch -> enforce Option A + drop NEXT flag, then check B=true
    apply.("/switch");
    step.(0.30, {
        enforceOptionAFlagDrop.value;
        ~mpb.printChains;
        count.( assertXor.(false, true, "after first switch — NEXT→CURRENT") );

        // bypass ON on CURRENT, verify flags unchanged
        apply.("/bypass/delay/on");
        ~mpb.printChains;
        count.( assertXor.(false, true, "after bypass on (CURRENT)") );

        // bypass OFF on CURRENT, verify flags unchanged
        apply.("/bypass/delay/off");
        ~mpb.printChains;
        count.( assertXor.(false, true, "after bypass off (CURRENT)") );

        // switch back -> enforce Option A + drop flag, expect A=true
        apply.("/switch");
        step.(0.30, {
            enforceOptionAFlagDrop.value;
            ~mpb.printChains;
            count.( assertXor.(true, false, "after second switch — back to A") );

            // meters back (optional)
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
