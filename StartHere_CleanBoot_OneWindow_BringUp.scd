// StartHere_CleanBoot_OneWindow_BringUp.scd
// v0.3
// MD 20250917-1253
//
// Purpose: From a fresh interpreter, boot server safely, ensure exactly ONE
//          MagicDisplayGUI window, create ~mpb, build robust stereo sinks,
//          define sources (\testmelody, \ts0), set CURRENT to \testmelody,
//          enforce Option A (NEXT silent), enable meters, verify A XOR B.
// Style: tilde vars, var-first, lowercase names, no server.sync;
//        server ops inside Server.default.bind; GUI via AppClock.

(
var log, closeGuiWindows, bootServerClean, initGuiAndMpb,
    ensureSinksStereo, ensureSources, setBaselineCurrent,
    enforceOptionA, enableMeters, verify, s;

log = { arg s; ("[START] " ++ s).postln };

// 0) (re)boot server safely and clear node tree
bootServerClean = {
    s = Server.default;
    // If running, quit first to avoid stale state
    if(s.serverRunning) { s.quit };
    s.waitForBoot({
        s.initTree;
        s.defaultGroup.freeAll;
        log.("server booted + tree inited + default group cleared");
    });
};

// 1) close any existing MagicDisplayGUI windows (singleton)
closeGuiWindows = {
    AppClock.sched(0.0, {
        Window.allWindows
            .select({ arg w; (w.name ? "").asString.beginsWith("MagicDisplayGUI") })
            .do(_.close);
        nil
    });
};

// 2) new GUI + MPB (tilde-vars)
initGuiAndMpb = {
    AppClock.sched(0.05, {
        ~gui = MagicDisplayGUI.new;
        ~mpb = MagicPedalboardNew.new(~gui);
        // meters OFF initially (we'll re-enable later)
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(false) };
        log.("GUI + MPB created (meters off)");
        nil
    });
};

// 3) robust stereo sinks: \in.ar(2) + ar(2)
//    (required by your sink design; non-intrusive to class wiring)
ensureSinksStereo = {
    Server.default.bind({
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
    });
    log.("sinks ready: \\in.ar(2) + ar(2)");
};

// 4) define \ts0 (stereo Silent) + \testmelody (stereo generated audio)
ensureSources = {
    Server.default.bind({
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
    log.("sources ready: \\ts0 (silent), \\testmelody (stereo)");
};

// 5) set CURRENT source and play (class-managed wiring uses <<> internally)
setBaselineCurrent = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
    log.("CURRENT <- \\testmelody; playing");
};

// 6) enforce Option A (NEXT silent)
//    (class implementation; no direct sink-source overwrites here)
enforceOptionA = {
    ~mpb.enforceExclusiveCurrentOptionA(0.1);
    log.("Option A enforced (NEXT silent)");
};

// 7) meters ON (after sinks/sources are stable)
enableMeters = {
    AppClock.sched(0.10, {
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(true) };
        log.("meters enabled");
        nil
    });
};

// 8) verify (print chains; A XOR B)
verify = {
    ~mpb.printChains;
    AppClock.sched(0.20, {
        var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying;
        ("[PLAY] A=% B=%".format(a, b)).postln;
        nil
    });
};

// --- run sequence deterministically ---
closeGuiWindows.value;
Server.default.boot;
bootServerClean.value;               // waits for boot + inits tree + clears group
initGuiAndMpb.value;
AppClock.sched(0.20, {
    ensureSinksStereo.value;
    ensureSources.value;
    setBaselineCurrent.value;
    enforceOptionA.value;
    enableMeters.value;
    verify.value;
    // make adapter scripts happy:
    if(~pedalboard.isNil and: { ~mpb.notNil }) { ~pedalboard = ~mpb };
    nil
});
)
