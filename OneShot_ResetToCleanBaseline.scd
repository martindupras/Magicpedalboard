// OneShot_ResetToCleanBaseline.scd
// v0.6
// MD 20250916-1708

//
// Purpose: Reset to a clean, audible baseline and GUARANTEE exclusivity by silencing NEXT.
//          Ensures robust sinks (\in.ar(2)), defines \testmelody, uses MPB.reset, then enforces
//          CURRENT-only by muting NEXT at the sink source; retargets meters and prints final state.
// Style:   tilde vars; var-first; lowercase names; no server.sync; Server.default.bind for server ops.

(
var log, ensureSinksRobust, ensureSource, ensureGuiMpb, doMpbReset,
    setCurrent, enforceExclusiveBySilence, retargetMeters, verify;

log = { arg s; ("[RESET] " ++ s).postln; };

// Robust sinks + AR
ensureSinksRobust = {
    Server.default.bind({
        Ndef(\chainA, { \in.ar(2) });
        Ndef(\chainB, { \in.ar(2) });
        Ndef(\chainA).ar(2);
        Ndef(\chainB).ar(2);
    });
};

// Internal source
ensureSource = {
    Server.default.bind({
        Ndef(\testmelody, {
            var trig, seq, f, env, tone, pan;
            trig = Impulse.kr(3.2);
            seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
            f    = Demand.kr(trig,0,seq);
            env  = Decay2.kr(trig,0.01,0.35);
            tone = SinOsc.ar(f) * env * 0.25;
            pan  = ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
            Pan2.ar(tone, pan)
        });
        Ndef(\testmelody).ar(2);
    });
};

// GUI + MPB and reset
ensureGuiMpb = {
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };
};
doMpbReset = { ~mpb.reset };

// CURRENT <- testmelody; play
setCurrent = {
    ~mpb.setSourceCurrent(\testmelody);
    ~mpb.playCurrent;
};

// Silencing strategy: mute NEXT sink’s source (hard silence), keep CURRENT robust+playing
enforceExclusiveBySilence = {
    var currentSink, nextSink;
    currentSink = ~mpb.effectiveCurrent[0];
    nextSink    = ~mpb.effectiveNext[0];

    Server.default.bind({
        // CURRENT robust + playing
        Ndef(currentSink, { \in.ar(2) });
        Ndef(currentSink).ar(2);
        Ndef(currentSink).fadeTime_(0.05);
        if(Ndef(currentSink).isPlaying.not) { Ndef(currentSink).play(numChannels: 2) };

        // NEXT silenced at source (even if its monitor claims 'playing', it contributes 0 audio)
        Ndef(nextSink, { Silent.ar(2) });
        Ndef(nextSink).ar(2);
        Ndef(nextSink).fadeTime_(0.01);
        Ndef(nextSink).stop;
    });
    log.("exclusive enforced by silencing NEXT " ++ nextSink.asString);
};

// meters after AR
retargetMeters = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(false);
        ~gui.enableMeters(true);
    };
};

// final print
verify = {
    ~mpb.printChains;
    AppClock.sched(0.25, {
        ("[PLAY] A=%  B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
        nil
    });
};

log.("start");
Server.default.boot;

ensureSinksRobust.value;
ensureGuiMpb.value;
doMpbReset.value;
ensureSource.value;
setCurrent.value;
enforceExclusiveBySilence.value;
retargetMeters.value;
verify.value;
)
