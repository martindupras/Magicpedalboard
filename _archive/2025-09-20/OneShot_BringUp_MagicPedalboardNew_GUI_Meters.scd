// OneShot_BringUp_MagicPedalboardNew_GUI_Meters.scd
// v0.2.1
// MD 20250917-1208
//
// Purpose: Deterministic bring-up: disable meters early; stereo sinks (\in.ar(2)); \ts0 stereo Silent;
//          define \testmelody; play CURRENT; enforce Option A; then explicitly pause NEXT so
//          isPlaying=B=false; enable meters; verify A XOR B.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind. GUI on AppClock only; one window.

(
var log, step, t,
    doBoot, ensureGuiMpb_disableMetersEarly, ensureSinksStereo, ensureTs0SilentStereo,
    ensureTestMelody, startCurrent_enforceExclusive, forceNextPauseFlag, enableMetersClean, verifyState;

log  = { arg s; ("[BRINGUP] " ++ s).postln };
step = { arg sec, fn; AppClock.sched(sec, { fn.value; nil }) };

// timings (seconds)
t = (
    boot:     0.00,
    guiMpb:   0.35,
    sinks:    0.50,
    ts0:      0.65,
    source:   0.80,
    current:  1.00,
    nextPause:1.05,   // tiny step after Option A
    meters:   1.20,
    verify:   1.40
);

doBoot = {
    log.("boot audio");
    Server.default.boot;
};

ensureGuiMpb_disableMetersEarly = {
    log.("ensure GUI + pedalboard; disable meters early");
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    // proactively disable meters twice (beats any queued enable)
    AppClock.sched(0.00, { ~gui.enableMeters(false); nil });
    AppClock.sched(0.05, { ~gui.enableMeters(false); nil });

    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };
};

ensureSinksStereo = {
    log.("robust sinks: \\in.ar(2) + ar(2)");
    Server.default.bind({
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainA).ar(2);
        Ndef(\chainB, { \in.ar(2) }); Ndef(\chainB).ar(2);
    });
};

ensureTs0SilentStereo = {
    log.("define \\ts0 as stereo Silent (for NEXT)");
    Server.default.bind({
        Ndef(\ts0, { Silent.ar(2) }); Ndef(\ts0).ar(2);
    });
};

ensureTestMelody = {
    log.("define \\testmelody (stereo)");
    Server.default.bind({
        Ndef(\testmelody, {
            var trig = Impulse.kr(3.2);
            var seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
            var f    = Demand.kr(trig, 0, seq);
            var env  = Decay2.kr(trig, 0.01, 0.35);
            var tone = SinOsc.ar(f) * env * 0.25;
            var pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
            Pan2.ar(tone, pan)
        });
        Ndef(\testmelody).ar(2);
    });
};

startCurrent_enforceExclusive = {
    log.("CURRENT <- \\testmelody; play + enforce Option A");
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;                         // MPB enforces Option A after play
    ~mpb.enforceExclusiveCurrentOptionA(0.1); // belt-and-braces: NEXT hard-silenced + stop
};

forceNextPauseFlag = {
    // Ensure NEXT.isPlaying == false (state aligns with Option A audio silence)
    var nextSink;
    nextSink = ~mpb.nextChain[0];             // sink symbol (chainB if A is current)
    Server.default.bind({ Ndef(nextSink).pause });
    log.("NEXT paused (flag B=false)");
};

enableMetersClean = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        log.("enable meters (guards + re-sends SynthDefs)");
        ~gui.enableMeters(true);
    };
};

verifyState = {
    log.("verify");
    ~mpb.printChains;
    AppClock.sched(0.25, {
        var a = Ndef(\chainA).isPlaying;
        var b = Ndef(\chainB).isPlaying;
        ("[PLAY] A=% B=%".format(a, b)).postln;
        nil
    });
};

log.("start deterministic bring-up");
step.(t[\boot],     { doBoot.value });
step.(t[\guiMpb],   { ensureGuiMpb_disableMetersEarly.value });
step.(t[\sinks],    { ensureSinksStereo.value });
step.(t[\ts0],      { ensureTs0SilentStereo.value });
step.(t[\source],   { ensureTestMelody.value });
step.(t[\current],  { startCurrent_enforceExclusive.value });
step.(t[\nextPause],{ forceNextPauseFlag.value });   // <-- NEW tiny step
step.(t[\meters],   { enableMetersClean.value });
step.(t[\verify],   { verifyState.value });
)
