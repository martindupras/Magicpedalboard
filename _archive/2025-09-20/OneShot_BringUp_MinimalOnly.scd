// OneShot_BringUp_MinimalOnly.scd
// v0.1
// MD 20250916-1608

(
// =========================================================

// Purpose: bring up to a clean audible baseline (no FX demo);
//          robust sinks; retarget meters; verify.
// Style: tilde vars, var-first, lowercase names, no server.sync,
//        server ops inside Server.default.bind.

// =========================================================

var log, step, t, doBoot, ensureSinks, ensureGuiMpb, ensureSource,
    enforceExclusiveCurrent, ensureMetersOk, verifyState;

log = { arg s; ("[BRINGUP] " ++ s).postln };
step = { arg sec, fn; AppClock.sched(sec, { fn.value; nil }) };

// timings
t = ( boot:0.00, sinks:0.40, guiMpb:0.55, source:0.75, current:0.95, meters:1.15, verify:1.35 );

doBoot = { log.("boot audio"); Server.default.boot; };

ensureSinks = {
    log.("ensure sinks robust + AR");
    Server.default.bind({
        Ndef(\chainA, { \in.ar(2) }); Ndef(\chainB, { \in.ar(2) });
        Ndef(\chainA).ar(2);          Ndef(\chainB).ar(2);
    });
};

ensureGuiMpb = {
    log.("ensure GUI + MPB");
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };
};

ensureSource = {
    log.("define \\testmelody (stereo)");
    Server.default.bind({
        Ndef(\testmelody, {
            var trig=Impulse.kr(3.2), seq=Dseq([220,277.18,329.63,392,329.63,277.18,246.94],inf);
            var f=Demand.kr(trig,0,seq), env=Decay2.kr(trig,0.01,0.35);
            var tone=SinOsc.ar(f)*env*0.25, pan=ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
            Pan2.ar(tone, pan)
        });
        Ndef(\testmelody).ar(2);
    });
};

enforceExclusiveCurrent = {
    log.("CURRENT <- \\testmelody; play A, stop B");
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
    Server.default.bind({
        if(Ndef(\chainB).isPlaying) { Ndef(\chainB).stop };
        if(Ndef(\chainA).isPlaying.not) { Ndef(\chainA).play(numChannels: 2) };
    });
};

ensureMetersOk = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        log.("meters retarget");
        ~gui.enableMeters(false); ~gui.enableMeters(true);
    };
};

verifyState = {
    log.("verify");
    ~mpb.printChains;
    AppClock.sched(0.15, {
        "[PLAY] A=%  B=%"
        .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)
        .postln; nil
    });
};

log.("starting bring‑up (minimal)");
step.(t[\boot],    { doBoot.value });
step.(t[\sinks],   { ensureSinks.value });
step.(t[\guiMpb],  { ensureGuiMpb.value });
step.(t[\source],  { ensureSource.value });
step.(t[\current], { enforceExclusiveCurrent.value });
step.(t[\meters],  { ensureMetersOk.value });
step.(t[\verify],  { verifyState.value });

)
