// prep_demo_audio_gui_current.scd
// v0.1
// MD 20250916-1046

(
var ensureSource;

Server.default.boot;

// ensure a musical internal source
ensureSource = {
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
        // simple FX
        Ndef(\delay, { |in, time=0.45, fb=0.35, mix=0.5|
            var sig, delayed, bal;
            sig = \in.ar(2);
            delayed = CombC.ar(sig, 2.0, time.clip(0.01, 2.0), time * (fb.clip(0,0.95) * 6 + 0.1));
            bal = (mix.clip(0,1) * 2 - 1);
            XFade2.ar(sig, delayed, bal)
        });
    });
};

// one GUI window via your runner
~md_bootProbeScenario.();

// ensure GUI + pedalboard, and make CURRENT audible
~gui = ~gui ?? { MagicDisplayGUI.new() };
~pedalboard = ~pedalboard ?? { MagicPedalboardNew.new(~gui) };
~pedalboard.reset;
~pedalboard.setSourceCurrent(\testmelody);  // CURRENT, so it's audible immediately
~pedalboard.playCurrent;
~pedalboard.printChains;
)
