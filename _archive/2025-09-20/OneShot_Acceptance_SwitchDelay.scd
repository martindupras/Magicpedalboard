// OneShot_Acceptance_SwitchDelay.scd
// v0.1
// MD 20250916-1618

// Purpose: Automated acceptance: baseline -> add \delay to NEXT -> switch (0.12s) -> verify exclusive playback and chain contents; includes basic PASS/FAIL counting and GUI meter retarget.
// Style: tilde vars, var-first, lowercase names, no server.sync, Server.default.bind for server ops.

(
var log, passCount, failCount, assertTrue, step, timePlan, ensureSinks, ensureGuiMpb, ensureSource, ensureDelayProc, verifyExclusive, runScenario;

log = { arg s; ("[ACCEPT] " ++ s).postln };

passCount = 0; failCount = 0;
assertTrue = { arg cond, label;
    var text;
    text = if(cond) { "PASS" } { "FAIL" };
    ("[ACCEPT] " ++ text ++ " — " ++ label).postln;
    if(cond) { passCount = passCount + 1 } { failCount = failCount + 1 };
};

step = { arg sec, fn; AppClock.sched(sec, { fn.value; nil }) };

timePlan = ( sinks:0.05, gui:0.10, source:0.20, meters:0.30, baseline:0.45, add:0.60, switch:0.80, verify2:1.10, bypassOn:1.30, bypassOff:1.50, switchBack:1.70, summary:1.95 );

// 1) Robust sinks (consumes \in) + AR buses
ensureSinks = {
    log.("ensure sinks robust + audio-rate");
    Server.default.bind({
        Ndef(\chainA, { \in.ar(2) });
        Ndef(\chainB, { \in.ar(2) });
        Ndef(\chainA).ar(2);
        Ndef(\chainB).ar(2);
    });
};

// 2) GUI + MPB
ensureGuiMpb = {
    log.("ensure GUI + MPB");
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };
};

// 3) Known-good internal source
ensureSource = {
    log.("define \\testmelody");
    Server.default.bind({
        Ndef(\testmelody, {
            var trig, seq, f, env, tone, panPos;
            trig = Impulse.kr(3.2);
            seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
            f    = Demand.kr(trig, 0, seq);
            env  = Decay2.kr(trig, 0.01, 0.35);
            tone = SinOsc.ar(f) * env * 0.25;
            panPos = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
            Pan2.ar(tone, panPos)
        });
        Ndef(\testmelody).ar(2);
    });
};

// 4) Ensure proc (\delay) exists (stereo)
ensureDelayProc = {
    log.("ensure \\delay processor exists");
    Server.default.bind({
        Ndef(\delay, { |time=0.45, fb=0.35, mix=0.5|
            var sig = \in.ar(2);
            var delayed = CombC.ar(sig, 2.0, time.clip(0.01,2.0), time * (fb.clip(0,0.95)*6 + 0.1));
            XFade2.ar(sig, delayed, (mix.clip(0,1) * 2 - 1))
        });
        Ndef(\delay).ar(2);
    });
};

// helper: verify exclusive CURRENT (A XOR B playing)
verifyExclusive = { arg expectAPlaying, expectBPlaying, label;
    var a, b, match;
    a = Ndef(\chainA).isPlaying;
    b = Ndef(\chainB).isPlaying;
    match = (a == expectAPlaying) and: { b == expectBPlaying };
    assertTrue.(match, label ++ " (A=" ++ a ++ " B=" ++ b ++ ")");
};

// 5) Scenario: baseline -> add \delay (NEXT) -> switch -> verify -> bypass current on/off -> switch back
runScenario = {
    log.("baseline: CURRENT <- \\testmelody; play A, stop B; meters reattach");
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
    Server.default.bind({
        if(Ndef(\chainB).isPlaying) { Ndef(\chainB).stop };
        if(Ndef(\chainA).isPlaying.not) { Ndef(\chainA).play(numChannels: 2) };
    });
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) { ~gui.enableMeters(false); ~gui.enableMeters(true) };

    ~mpb.printChains;
    verifyExclusive.(true, false, "baseline exclusive: A=true, B=false");

    log.("add \\delay to NEXT, then switch (0.12s)");
    ~mpb.add(\delay);
    ~mpb.printChains;
    ~mpb.switchChain(0.12);

    // verify after fade
    step.(0.25, {
        verifyExclusive.(false, true, "after switch: A=false, B=true");
        ~mpb.printChains;

        log.("bypassCurrent(\\delay, true) then false");
        ~mpb.bypassCurrent(\delay, true);
        ~mpb.printChains;
        ~mpb.bypassCurrent(\delay, false);
        ~mpb.printChains;

        log.("switch back to A");
        ~mpb.switchChain(0.12);

        step.(0.25, {
            verifyExclusive.(true, false, "after switch-back: A=true, B=false");
            ("[ACCEPT] Summary: PASS=" ++ passCount ++ " FAIL=" ++ failCount).postln;
        });
    });
};

// --- run sequence (no server.sync; AppClock timing) ---
Server.default.boot;
step.(timePlan[\sinks], { ensureSinks.value });
step.(timePlan[\gui],   { ensureGuiMpb.value });
step.(timePlan[\source],{ ensureSource.value });
step.(timePlan[\meters],{ if(~gui.notNil, { ~gui.enableMeters(false); ~gui.enableMeters(true) }) });
step.(timePlan[\baseline], { runScenario.value });

)
