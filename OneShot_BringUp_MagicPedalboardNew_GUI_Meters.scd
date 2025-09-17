// OneShot_BringUp_MagicPedalboardNew_GUI_Meters.scd
// v0.1
// MD 20250916-1608

//
// Purpose: single‑run bring‑up to audible baseline; robust sinks;
//          retarget meters; quick FX switch demo.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

(
var log, step, delayA, doBoot, ensureSinks, ensureGuiMpb, ensureSource,
    enforceExclusiveCurrent, ensureMetersOk, verifyState, demoFx;

log = { arg messageString; ("[BRINGUP] " ++ messageString).postln };

step = { arg seconds, fn;
    AppClock.sched(seconds, { fn.value; nil })
};

// --- timings (seconds) ---
delayA = (
    boot:     0.00,
    sinks:    0.40,
    guiMpb:   0.55,
    source:   0.75,
    current:  0.95,
    meters:   1.15,
    verify:   1.35,
    demo:     1.75
);

// 1) Boot audio (safe to call repeatedly)
doBoot = {
    log.("boot audio");
    Server.default.boot;
};

// 2) Robust sinks + AR buses (ensures sinks actually consume \in)
ensureSinks = {
    log.("ensure sinks are robust and audio‑rate");
    Server.default.bind({
        Ndef(\chainA, { \in.ar(2) });
        Ndef(\chainB, { \in.ar(2) });
        Ndef(\chainA).ar(2);
        Ndef(\chainB).ar(2);
    });
};

// 3) Ensure GUI + MPB (reuse if present)
ensureGuiMpb = {
    log.("ensure GUI + pedalboard");
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };
};

// 4) Musical internal source + AR (guaranteed audible)
ensureSource = {
    log.("define \\testmelody source (stereo)");
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

// 5) CURRENT <- testmelody; play CURRENT; stop NEXT
enforceExclusiveCurrent = {
    log.("set CURRENT source and enforce exclusive playback");
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
    Server.default.bind({
        if(Ndef(\chainB).isPlaying) { Ndef(\chainB).stop };
        if(Ndef(\chainA).isPlaying.not) { Ndef(\chainA).play(numChannels: 2) };
    });
};

// 6) Retarget meters after sinks are definitely AR
ensureMetersOk = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        log.("retarget meters (off -> on)");
        ~gui.enableMeters(false);
        ~gui.enableMeters(true);
    }{
        log.("no GUI or enableMeters missing; skipping meter retarget");
    };
};

// 7) Verify state (posts chain details and playing flags)
verifyState = {
    log.("verify state");
    ~mpb.printChains;
    AppClock.sched(0.15, {
        var aPlaying, bPlaying, line;
        aPlaying = Ndef(\chainA).isPlaying;
        bPlaying = Ndef(\chainB).isPlaying;
        line = "[PLAY] A=%  B=%".format(aPlaying, bPlaying);
        line.postln;
        nil
    });
};

// 8) Demo FX: ensure \delay exists, add to NEXT, switch with short xfade
demoFx = {
    log.("demo FX: add \\delay to NEXT, then switch (0.12s)");
    Server.default.bind({
        Ndef(\delay, { |time=0.45, fb=0.35, mix=0.5|
            var sig = \in.ar(2);
            var delayed = CombC.ar(sig, 2.0, time.clip(0.01, 2.0), time * (fb.clip(0,0.95) * 6 + 0.1));
            XFade2.ar(sig, delayed, (mix.clip(0,1) * 2 - 1))
        });
        Ndef(\delay).ar(2);
    });
    ~mpb.add(\delay);        // add to NEXT
    ~mpb.switchChain(0.12);  // crossfade to hear delay
    ~mpb.printChains;
};

// --- schedule the steps (no server.sync; UI remains responsive) ---
log.("starting bring‑up sequence");
step.(delayA[\boot],    { doBoot.value });
step.(delayA[\sinks],   { ensureSinks.value });
step.(delayA[\guiMpb],  { ensureGuiMpb.value });
step.(delayA[\source],  { ensureSource.value });
step.(delayA[\current], { enforceExclusiveCurrent.value });
step.(delayA[\meters],  { ensureMetersOk.value });
step.(delayA[\verify],  { verifyState.value });
step.(delayA[\demo],    { demoFx.value });

)
