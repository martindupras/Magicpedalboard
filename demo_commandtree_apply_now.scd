// demo_commandtree_apply_now.scd
// v0.2
// MD 20250916-1003

(
var ensureAudio, ensureGui, ensurePedalboard, ensureAdapter, log;

// simple logger
log = { arg messageString; ("[DEMO] " ++ messageString).postln };

// A) Audio: boot + musical internal source (stereo)
ensureAudio = {
    Server.default.boot;
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

        // lightweight FX (safe to re-run)
        Ndef(\delay, { |in, time=0.45, fb=0.35, mix=0.5|
            var sig = \in.ar(2);
            var delayed = CombC.ar(sig, 2.0, time.clip(0.01, 2.0), time * (fb.clip(0,0.95) * 6 + 0.1));
            XFade2.ar(sig, delayed, (mix.clip(0,1) * 2 - 1))
        });
        Ndef(\chorus, { |in, rate=0.8, depth=0.008, base=0.020|
            var sig = \in.ar(2);
            var mod = base.clip(0.0, 0.05) + (SinOsc.kr(rate.clip(0.1,5), 0, depth.clip(0.0,0.02)));
            DelayC.ar(sig, 0.1, mod)
        });
    });
};

// B) GUI: your runner guarantees one window + PROBE FRAME
ensureGui = {
    ~md_bootProbeScenario.();
};

// C) Pedalboard + GUI binding (reuse if present)
ensurePedalboard = {
    if(~gui.isNil) { ~gui = MagicDisplayGUI.new() };
    if(~pedalboard.isNil) { ~pedalboard = MagicPedalboardNew.new(~gui) };
    ~pedalboard.setSource(\testmelody);
    ~pedalboard.switchChain(0.12);
};

// D) Adapter presence
ensureAdapter = {
    if(~ct_sendAndApply.isNil) {
        "[DEMO] Please evaluate adapter_commandtree_to_magicpedalboard.scd first.".warn;
    };
};

// ---- run prep ----
ensureAudio.value;
ensureGui.value;
ensurePedalboard.value;
ensureAdapter.value;

// E) Reload CommandManager (imports updated myTree.json automatically)
~cm = CommandManager.new;
log.("CommandManager reloaded.");

// F) Drive actions via queue + SEND + adapter

// 1) add delay
~cm.midiManager.queue.clear;
~cm.midiManager.queue.enqueueCommand(\add);
~cm.midiManager.queue.enqueueCommand(\delay);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 2) switch (make it CURRENT, audible)
~cm.midiManager.queue.enqueueCommand(\switch);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 3) bypass delay ON, then OFF, then switch back
~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\on);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\off);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// Inspect (also drives GUI detailed view)
~pedalboard.printChains;
)
