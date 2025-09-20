// audibleSanity.scd
// v0.2
// MD 20250916

(
// --- A) Boot and define an internal source (stereo) ---
var ensureAudio, defineTestSource, overrideTs0, ensureGuiAndPedalboard, startCurrent, verify;

ensureAudio = {
    Server.default.boot;
};

defineTestSource = {
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

// --- B) Force ts0 to be internal (NOT SoundIn) for all tests today ---
overrideTs0 = {
    Server.default.bind({
        Ndef(\ts0, {
            var trig, seq, f, env, tone, panPos;
            trig = Impulse.kr(3.0);
            seq  = Dseq([196, 246.94, 329.63, 261.63, 329.63, 246.94], inf);
            f    = Demand.kr(trig, 0, seq);
            env  = Decay2.kr(trig, 0.01, 0.40);
            tone = Pulse.ar(f, 0.5) * env * 0.20;
            panPos = LFTri.kr(0.1).linlin(-1, 1, -0.5, 0.5);
            Pan2.ar(tone, panPos)
        });
        Ndef(\ts0).ar(2);
    });
};

// --- C) GUI + Pedalboard, sinks ar(2), meters on ---
ensureGuiAndPedalboard = {
    ~gui = ~gui ?? { MagicDisplayGUI.new };
    ~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };

    Server.default.bind({
        Ndef(\chainA).ar(2);
        Ndef(\chainB).ar(2);
    });

    // toggle meters cleanly once (your enableMeters now guards for audio-rate + server)
    ~gui.enableMeters(false);
    ~gui.enableMeters(true);
};

// --- D) Set CURRENT source to internal generator and play ---
startCurrent = {
    ~mpb.setSourceCurrent(\testmelody); // generated source
    ~mpb.playCurrent;
};

// --- E) Verify status ---
verify = {
    ~mpb.printChains;
    ("[sanity] chainA.isPlaying=% chainB.isPlaying=%"
        .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
};

ensureAudio.value;
defineTestSource.value;
overrideTs0.value;
ensureGuiAndPedalboard.value;
startCurrent.value;
verify.value;
)
