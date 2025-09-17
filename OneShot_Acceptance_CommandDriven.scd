// OneShot_Acceptance_CommandDriven.scd
// v0.2.2
// MD 20250917-1306
//
// Purpose: Robust acceptance using your adapter. Waits for server + ~mpb + adapter,
//          disables meters during ops, pins stereo sinks, enforces Option A and
//          hard-drops NEXT monitor (.end), recreates silent stereo NEXT, then asserts
//          A XOR B after each step. No rewiring; adapter-only control.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind. GUI on AppClock only.

(
var log, step, t,
    ready, disableMeters, enableMeters,
    pinStereoSinks, ensureSources, baselineExclusive,
    enforceOptionA_EndNext, assertXor, apply, runScenario;

var passCount, failCount;
passCount = 0; failCount = 0;

// helpers
log  = { arg s; ("[ACCEPT] " ++ s).postln };
step = { arg sec, fn; AppClock.sched(sec, { fn.value; nil }) };

// timings
t = ( prep:0.00, baseline:0.25, add:0.45, sw1:0.75, byOn:1.05, byOff:1.30, sw2:1.60, meters:1.90, sum:2.10 );

// readiness
ready = {
    if(Server.default.serverRunning.not) { Server.default.boot };
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };
    if(~ct_applyOSCPathToMPB.isNil) {
        "[ACCEPT] adapter missing: eval adapter_commandtree_to_magicpedalboard.scd, then rerun.".warn;
        ^false
    };
    true
};

// meters control
disableMeters = { if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(false); log.("meters disabled") } };
enableMeters  = { if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(true);  log.("meters enabled")  } };

// pin sinks (authoritative)
pinStereoSinks = {
    Server.default.bind({
        Ndef(\chainA).mold(2, \audio);
        Ndef(\chainB).mold(2, \audio);
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
    });
    log.("sinks pinned: mold(2,audio) + \\in.ar(2)");
};

// sources
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

// enforce Option A + hard-drop NEXT monitor + recreate silent stereo
enforceOptionA_EndNext = {
    var nextSink = ~mpb.nextChain[0];
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    Server.default.bind({
        Ndef(nextSink).end;                     // drop monitor/flag
        Ndef(nextSink, { Silent.ar(2) });       // recreate silent source
        Ndef(nextSink).mold(2, \audio);         // keep stereo for future switch
    });
    log.("Option A enforced + NEXT ended & recreated silent");
};

// baseline: CURRENT <- \testmelody
baselineExclusive = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
    enforceOptionA_EndNext.value;
};

// A XOR B assert
assertXor = { arg expectA, expectB, label;
    var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying, ok;
    ok = (a == expectA) and: { b == expectB };
    ((ok.if({"PASS"},{"FAIL"})) ++ " — " ++ label ++ " (A=" ++ a ++ " B=" ++ b ++ ")").postln;
    if(ok) { passCount = passCount + 1 } { failCount = failCount + 1 };
    ok
};

// adapter apply
apply = { arg pathString; ~ct_applyOSCPathToMPB.(pathString, ~mpb, ~gui) };

// scenario
runScenario = {
    if(ready.value.not) { ^nil };

    disableMeters.value;
    pinStereoSinks.value;
    ensureSources.value;

    baselineExclusive.value;
    ~mpb.printChains;
    assertXor.value(true, false, "baseline: CURRENT audible; NEXT silent");

    apply.value("/add/delay");
    ~mpb.printChains;
    assertXor.value(true, false, "after add/delay (NEXT) — exclusivity holds");

    apply.value("/switch");               // A->B
    step.value(0.35, {
        enforceOptionA_EndNext.value;     // hard-drop NEXT & recreate silent
        ~mpb.printChains;
        assertXor.value(false, true, "after first switch — NEXT→CURRENT");

        apply.value("/bypass/delay/on");
        ~mpb.printChains;
        assertXor.value(false, true, "after bypass on (CURRENT)");

        apply.value("/bypass/delay/off");
        ~mpb.printChains;
        assertXor.value(false, true, "after bypass off (CURRENT)");

        apply.value("/switch");           // B->A
        step.value(0.35, {
            enforceOptionA_EndNext.value;
            ~mpb.printChains;
            assertXor.value(true, false, "after second switch — back to A");

            enableMeters.value;
            ("[ACCEPT] Summary: PASS=" ++ passCount ++ " FAIL=" ++ failCount).postln;
            nil
        });
        nil
    });
};

// run
runScenario.value;
)
