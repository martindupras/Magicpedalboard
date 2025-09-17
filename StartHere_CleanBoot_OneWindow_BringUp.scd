// StartHere_CleanBoot_OneWindow_BringUp.scd
// v0.5.5
// MD 20250917-1550
//
// Purpose: From a fresh interpreter, produce one MagicDisplayGUI window,
//          audible CURRENT (\testmelody), NEXT silent (Option A), meters on,
//          and verify A=true B=false. This version forces a clean server boot
//          and sequences steps with AppClock to avoid server/group races.
// Style: tilde vars, var-first, lowercase names; no server.sync;
//        server ops inside Server.default.bind; GUI via AppClock; single window.

(
var log, s, schedule, numChConst,
    closeGuiWindows, bootFreshThen, ensureMeterDefs, checkChainChannels,
    buildAudio, makeGuiAndMpb, baseline, metersOn, verify;

log = { arg msg; ("[START] " ++ msg).postln };
s   = Server.default;
schedule = { arg dt=0.0, func; AppClock.sched(dt.max(0), { func.value; nil }) };

// Channel constant for sinks/sources/meters (respects your global if present)
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

// 2) Fresh boot every time (quit if running/booting → boot), then clean tree
bootFreshThen = { arg afterBootFunc;
    if(s.serverRunning or: { s.booting }) {
        log.("server running/booting → quitting for clean boot");
        s.quit;
        schedule.(0.6, { // small delay to let quit complete
            log.("booting server…");
            s.boot;
        });
    }{
        log.("booting server…");
        s.boot;
    };

    // Continue ONLY AFTER the boot completes
    s.waitForBoot({
        log.("server booted");
        Server.default.bind({
            s.initTree;
            s.defaultGroup.freeAll;
        });
        log.("tree inited + default group cleared");
        afterBootFunc.value; // continue
    });
};

// 3) Ensure meter SynthDefs exist (compile-time channel count; mono-mix inside)
ensureMeterDefs = {
    var needA, needB, n;
    n = numChConst;
    needA = SynthDescLib.global.at(\busMeterA).isNil;
    needB = SynthDescLib.global.at(\busMeterB).isNil;

    if(needA or: { needB }) {
        ("[START] (re)defining meter synths with numChConst=" ++ n).postln;
        Server.default.bind({
            SynthDef(\busMeterA, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                useBus = Select.kr(bus >= 0, [in, bus]);   // prefer \bus if set; else \in
                sig    = In.ar(useBus, n);                 // compile-time channel count
                mono   = Mix(sig);                         // avoid language-level max on UGen arrays
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterA", [rms, peak]);
            }).add;

            SynthDef(\busMeterB, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                useBus = Select.kr(bus >= 0, [in, bus]);
                sig    = In.ar(useBus, n);
                mono   = Mix(sig);
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterB", [rms, peak]);
            }).add;
        });
    };
};

// Optional: print A/B channel counts when chains exist
checkChainChannels = {
    var a, b;
    a = Ndef(\chainA).tryPerform(\numChannels);
    b = Ndef(\chainB).tryPerform(\numChannels);
    if(a.notNil or: { b.notNil }) {
        "[CHECK] Ndef chain channels → A:% , B:%".format(a, b).postln;
    };
};

// 4) Build sinks and sources (server operations)
buildAudio = {
    Server.default.bind({
        // Sinks: must read \in.ar(defaultNumChannels)
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
    schedule.(0.00, {
        ~gui = MagicDisplayGUI.new;
        ~mpb = MagicPedalboardNew.new(~gui);
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(false) };
        if(~pedalboard.isNil and: { ~mpb.notNil }) { ~pedalboard = ~mpb };
        log.("GUI + MPB created (meters off)");
    });
};

// 6) Baseline: CURRENT <- \testmelody; play; enforce Option A (NEXT silent)
//    (Delay to allow MPB to build its server groups)
baseline = {
    schedule.(0.60, {
        // Nudge MPB to (re)build its CURRENT tree explicitly (it prints logs)
        if(~mpb.respondsTo(\rebuild)) { ~mpb.rebuild(\current) };
        // Give that rebuild bundle a moment to land
        schedule.(0.15, {
            ~mpb.setSourceCurrent(\testmelody);
            ~mpb.playCurrent;  // route CURRENT to chainA
            ~mpb.enforceExclusiveCurrentOptionA(0.1);  // NEXT silenced at source (Option A)
            log.("baseline set: CURRENT=\\testmelody (Option A)");
        });
    });
};

// 7) Meters ON after everything is stable
metersOn = {
    schedule.(0.95, {
        ensureMeterDefs.value; // idempotent guard
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(true) };
        log.("meters enabled");
    });
};

// 8) Verify final state
verify = {
    schedule.(1.15, {
        ~mpb.printChains;
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
        checkChainChannels.value;
    });
};

// --- Execute clean sequence (select-all and evaluate once) --------------------
closeGuiWindows.value;

bootFreshThen.value({
    // Define meter defs early (safe re-add) before GUI/MPB and meters
    ensureMeterDefs.value;

    buildAudio.value;
    makeGuiAndMpb.value;
    baseline.value;
    metersOn.value;
    verify.value;
});
)
