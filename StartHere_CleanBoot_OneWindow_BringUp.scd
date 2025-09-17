// StartHere_CleanBoot_OneWindow_BringUp.scd
// v0.5.1
// MD 20250917-1453
//
// Purpose: From a fresh interpreter, produce one MagicDisplayGUI window,
//          audible CURRENT (\testmelody), NEXT silent (Option A), meters on,
//          and verify A=true B=false. Includes a robust boot prelude and
//          (re)defines meter SynthDefs safely (compile-time channel count).
// Style: tilde vars, var-first, lowercase names; no server.sync;
//        server ops inside Server.default.bind; GUI via AppClock; single window.

(
var log, server, schedule, numChConst,
    closeGuiWindows, ensureServerReady, ensureMeterDefs, checkChainChannels,
    buildAudio, makeGuiAndMpb, baseline, metersOn, verify;

// --- Utilities ----------------------------------------------------------------

log = { arg msg; ("[START] " ++ msg).postln };
server = Server.default;
schedule = { arg dt = 0.0, func; AppClock.sched(dt.max(0), { func.value; nil }) };

// Decide a compile-time channel count for meter SynthDefs and sinks/sources.
// If ~defaultNumChannels is set and valid, use it; otherwise fall back to 2.
numChConst = (
    ~defaultNumChannels.isKindOf(Integer) and: { ~defaultNumChannels > 0 }
).if({ ~defaultNumChannels }, { 2 });

// 1) Close any MagicDisplayGUI windows (singleton)
closeGuiWindows = {
    schedule.(0.0, {
        Window.allWindows
            .select({ arg w; (w.name ? "").asString.beginsWith("MagicDisplayGUI") })
            .do(_.close);
        log.("closed any existing MagicDisplayGUI windows");
    });
};

// 2) Ensure server is ready (no quitting a healthy server), then clean tree
ensureServerReady = { arg afterBootFunc;
    if(server.serverRunning) {
        log.("server already running → reusing");
    }{
        if(server.booting) {
            log.("server already booting → waiting…");
        }{
            log.("booting server…");
            server.boot;
        };
    };

    // Run when server is booted (immediate if already running)
    server.waitForBoot({
        Server.default.bind({
            server.initTree;
            server.defaultGroup.freeAll;
        });
        log.("tree inited + default group cleared");
        afterBootFunc.value;
    });
};

// 3) Ensure meter SynthDefs exist (compile-time channel count; mono-mix inside)
ensureMeterDefs = {
    var needA, needB;
    needA = SynthDescLib.global.at(\busMeterA).isNil;
    needB = SynthDescLib.global.at(\busMeterB).isNil;

    if(needA or: { needB }) {
        ("[START] (re)defining meter synths with numChConst=" ++ numChConst).postln;

        Server.default.bind({
            SynthDef(\busMeterA, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                // choose \bus if >=0, else \in (UGen-domain select)
                useBus = Select.kr(bus >= 0, [in, bus]);
                // read exactly numChConst channels (compile-time integer captured from outer scope)
                sig    = In.ar(useBus, numChConst);
                // mix to mono to avoid language-level max across UGen arrays
                mono   = Mix(sig);
                // meters
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterA", [rms, peak]);
            }).add;

            SynthDef(\busMeterB, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                useBus = Select.kr(bus >= 0, [in, bus]);
                sig    = In.ar(useBus, numChConst);
                mono   = Mix(sig);
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterB", [rms, peak]);
            }).add;
        });
    };
};

// Optional: prints A/B channel counts if chains already exist
checkChainChannels = {
    var a, b;
    a = Ndef(\chainA).tryPerform(\numChannels);
    b = Ndef(\chainB).tryPerform(\numChannels);
    if(a.notNil or: { b.notNil }) {
        "[CHECK] Ndef chain channels → A:% , B:%".format(a, b).postln;
    };
};

// --- Build / Run steps --------------------------------------------------------

// 4) Build sinks and sources (server operations)
buildAudio = {
    Server.default.bind({
        // Sinks: robust consumers respect numChConst (stereo by default)
        Ndef(\chainA, { \in.ar(numChConst) }); Ndef(\chainA).ar(numChConst);
        Ndef(\chainB, { \in.ar(numChConst) }); Ndef(\chainB).ar(numChConst);

        // Sources: NEXT-safe silent + generated test melody
        Ndef(\ts0, { Silent.ar(numChConst) }); Ndef(\ts0).ar(numChConst);
        Ndef(\testmelody, {
            var trig, seq, f, env, tone, pan;
            trig = Impulse.kr(3.2);
            seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
            f    = Demand.kr(trig, 0, seq);
            env  = Decay2.kr(trig, 0.01, 0.35);
            tone = SinOsc.ar(f) * env * 0.25;
            pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
            Pan2.ar(tone, pan)
        }); Ndef(\testmelody).ar(numChConst);
    });
    log.("sinks + sources defined");
};

// 5) Create GUI + MPB (meters OFF initially)
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

// 6) Baseline: CURRENT <- \testmelody; play; enforce Option A (NEXT silent)
baseline = {
    schedule.(0.10, {
        ~mpb.setSourceCurrent(\testmelody);
        ~mpb.playCurrent;
        ~mpb.enforceExclusiveCurrentOptionA(0.1);  // NEXT silenced at source (Option A)
        log.("baseline set: CURRENT=\\testmelody (Option A)");
    });
};

// 7) Meters ON after everything is stable (ensure defs just-in-time)
metersOn = {
    schedule.(0.20, {
        ensureMeterDefs.value; // idempotent safety before enabling
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(true) };
        log.("meters enabled");
    });
};

// 8) Verify final state
verify = {
    schedule.(0.30, {
        ~mpb.printChains;
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
        checkChainChannels.value;
    });
};

// --- Execute clean sequence (select-all and evaluate once) -------------------
closeGuiWindows.value;
ensureServerReady.value({
    // Ensure meter defs exist early (before GUI attaches) — harmless if already present
    ensureMeterDefs.value;

    buildAudio.value;
    makeGuiAndMpb.value;
    baseline.value;
    metersOn.value;
    verify.value;
});
)
