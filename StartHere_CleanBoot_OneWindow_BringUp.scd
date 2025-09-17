// StartHere_CleanBoot_OneWindow_BringUp.scd
// v0.5
// MD 20250917-1346
//
// Purpose: From a fresh interpreter, produce one MagicDisplayGUI window,
//          audible CURRENT (\testmelody), NEXT silent (Option A), meters on,
//          and verify A=true B=false.
// Style: tilde vars, var-first, lowercase names; no server.sync;
//        server ops inside Server.default.bind; GUI via AppClock.

(
var log, s, schedule, closeGuiWindows, bootIfNeededThen, buildAudio, makeGuiAndMpb, baseline, metersOn, verify;

log = { arg msg; ("[START] " ++ msg).postln };
s   = Server.default;
schedule = { arg dt=0.0, func; AppClock.sched(dt.max(0), { func.value; nil }) };

// 1) Close any MagicDisplayGUI windows (singleton)
closeGuiWindows = {
    schedule.(0.0, {
        Window.allWindows
            .select({ arg w; (w.name ? "").asString.beginsWith("MagicDisplayGUI") })
            .do(_.close);
        log.("closed any existing MagicDisplayGUI windows");
    });
};

// 2) After server is booted, do the rest
bootIfNeededThen = { arg afterBootFunc;
    if(s.serverRunning) {
        // Quit first to avoid stale state; boot shortly after
        log.("server running → quitting");
        s.quit;
        schedule.(0.6, { // small delay to let quit complete
            log.("booting server…");
            s.boot;
        });
    }{
        log.("booting server…");
        s.boot;
    };
    // Everything below happens ONLY AFTER the boot completes:
    s.waitForBoot({
        log.("server booted");
        s.initTree; s.defaultGroup.freeAll;
        log.("tree inited + default group cleared");
        afterBootFunc.value; // continue
    });
};

// 3) Build sinks and sources (server operations)
buildAudio = {
    Server.default.bind({
        // Sinks: robust stereo consumers
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);

        // Sources: NEXT-safe silent + generated test melody
        Ndef(\ts0, { Silent.ar(2) }); Ndef(\ts0).ar(2);
        Ndef(\testmelody, {
            var trig = Impulse.kr(3.2);
            var seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
            var f    = Demand.kr(trig, 0, seq);
            var env  = Decay2.kr(trig, 0.01, 0.35);
            var tone = SinOsc.ar(f) * env * 0.25;
            var pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
            Pan2.ar(tone, pan)
        }); Ndef(\testmelody).ar(2);
    });
    log.("sinks + sources defined");
};

// 4) Create GUI + MPB (meters OFF initially)
makeGuiAndMpb = {
    schedule.(0.0, {
        ~gui = MagicDisplayGUI.new;
        ~mpb = MagicPedalboardNew.new(~gui);
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(false) };
        // Alias for adapter scripts
        if(~pedalboard.isNil and: { ~mpb.notNil }) { ~pedalboard = ~mpb };
        log.("GUI + MPB created (meters off)");
    });
};

// 5) Baseline: CURRENT <- \testmelody; play; enforce Option A (NEXT silent)
baseline = {
    schedule.(0.10, {
        ~mpb.setSourceCurrent(\testmelody);
        ~mpb.playCurrent;
        ~mpb.enforceExclusiveCurrentOptionA(0.1);  // NEXT silenced at source
        log.("baseline set: CURRENT=\\testmelody (Option A)");
    });
};

// 6) Meters ON after everything is stable
metersOn = {
    schedule.(0.20, {
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(true) };
        log.("meters enabled");
    });
};

// 7) Verify final state
verify = {
    schedule.(0.30, {
        ~mpb.printChains;
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    });
};

// --- Execute clean sequence ---
closeGuiWindows.value;
bootIfNeededThen.value({
    buildAudio.value;
    makeGuiAndMpb.value;
    baseline.value;
    metersOn.value;
    verify.value;
});
)
