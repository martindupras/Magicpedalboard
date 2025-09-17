// StartHere_CleanBoot_OneWindow_BringUp.scd
// v0.4
// MD 20250917-1338
//
// Purpose: Deterministic clean boot from a fresh (or messy) state:
//          - Close any existing MagicDisplayGUI windows (singleton)
//          - Quit server if running, then boot + wait for boot
//          - Init class tree, clear default group
//          - Build sinks (\\in.ar(2)) + sources (\\ts0 silent, \\testmelody)
//          - Create GUI + MPB (meters off), set CURRENT=\\testmelody
//          - Enforce Option A (NEXT silent), enable meters, verify A XOR B
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        all server ops inside Server.default.bind; GUI via AppClock only.

(
var log, s, closeGuiWindows, waitForServerDown, waitForBootFlagged,
    bootClean, buildAudio, makeGuiAndMpb, baseline, metersOn, verify;

log = { arg t; ("[START] " ++ t).postln };
s = Server.default;

// Close any MagicDisplayGUI windows (singleton policy)
closeGuiWindows = {
    AppClock.sched(0.0, {
        Window.allWindows
            .select({ arg w; (w.name ? "").asString.beginsWith("MagicDisplayGUI") })
            .do(_.close);
        nil
    });
};

// Poll until server is fully down
waitForServerDown = {
    Routine({
        while({ s.serverRunning }, { 0.05.wait });
    })
};

// Boot and set a flag from s.waitForBoot
waitForBootFlagged = {
    var booted = false;
    s.waitForBoot({
        s.initTree;       // safe initialization
        s.defaultGroup.freeAll;
        booted = true;
        log.("server booted + tree inited + default group cleared");
    });
    Routine({
        while({ booted.not }, { 0.05.wait });
    })
};

// Clean boot sequence (quit if running, then boot and wait)
bootClean = {
    Routine({
        if(s.serverRunning) {
            s.quit;
            waitForServerDown.value.play(SystemClock).yield; // block routine until down
        };
        s.boot;
        waitForBootFlagged.value.play(SystemClock).yield;    // block routine until booted
    })
};

// Build sinks and sources (server ops)
buildAudio = {
    Server.default.bind({
        // Sinks: robust stereo consumers
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
        // Sources
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
    log.("sinks + sources ready");
};

// GUI + MPB (meters off first)
makeGuiAndMpb = {
    AppClock.sched(0.0, {
        ~gui = MagicDisplayGUI.new;
        ~mpb = MagicPedalboardNew.new(~gui);
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(false) };
        // Alias for adapter scripts that expect ~pedalboard
        if(~pedalboard.isNil and: { ~mpb.notNil }) { ~pedalboard = ~mpb };
        log.("GUI + MPB created (meters off)");
        nil
    });
};

// Set baseline: CURRENT <- \testmelody; play + Option A
baseline = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
    ~mpb.enforceExclusiveCurrentOptionA(0.1);  // NEXT silent at source
    log.("baseline set (CURRENT=\\testmelody, Option A)");
};

// Meters on (after everything stable)
metersOn = {
    AppClock.sched(0.05, {
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(true) };
        log.("meters enabled");
        nil
    });
};

// Verify A/B flags
verify = {
    ~mpb.printChains;
    AppClock.sched(0.20, {
        var a = Ndef(\chainA).isPlaying, b = Ndef(\chainB).isPlaying;
        ("[PLAY] A=% B=%".format(a, b)).postln;
        nil
    });
};

// --- Run the whole sequence deterministically inside one Routine ---
Routine({
    // 1) GUI singleton
    closeGuiWindows.value; 0.10.wait;

    // 2) Clean boot (quit if needed, then boot + wait)
    bootClean.value.play(SystemClock).yield;

    // 3) Build audio graph on server
    buildAudio.value;
    0.05.wait;

    // 4) GUI + MPB
    makeGuiAndMpb.value;
    0.15.wait;

    // 5) Baseline + meters + verify
    baseline.value;
    metersOn.value;
    verify.value;
}).play(SystemClock);
)
