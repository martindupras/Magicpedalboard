// demo_commandtree_apply_now.scd
// v0.1
// MD 20250916-0942

(
var jsonPath, ensureAudioAndGui, ensurePedalboard, log;

jsonPath = "/Users/martindupras/CommandTreeSavefiles/myTree.json".standardizePath;

log = { arg messageString; ("[DEMO] " ++ messageString).postln };

// A) Audio: boot and ensure a musical internal source (stereo)
ensureAudioAndGui = {
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
        // Optional effects (safe if already defined)
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

    // Bring up your single GUI window via your runner
    ~md_bootProbeScenario.();  // one window + PROBE FRAME
};

// B) Pedalboard + GUI binding (reuse if present)
ensurePedalboard = {
    ~gui = ~gui ?? { MagicDisplayGUI.new() };  // class builds its window on AppClock internally
    ~pedalboard = ~pedalboard ?? { MagicPedalboardNew.new(~gui) };
    ~pedalboard.setSource(\testmelody);
    ~pedalboard.switchChain(0.12); // make CURRENT audible
};

// Run prep
ensureAudioAndGui.value;
ensurePedalboard.value;

// C) Reload CommandManager so it imports the updated JSON
~cm = CommandManager.new;     // imports "/Users/.../myTree.json" by design
log.("CommandManager reloaded.");

// D) Use the queue + SEND + adapter to apply actions

// 1) Add delay to NEXT
~cm.midiManager.queue.clear;
~cm.midiManager.queue.enqueueCommand(\add);
~cm.midiManager.queue.enqueueCommand(\delay);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 2) Switch to hear/see it as CURRENT
~cm.midiManager.queue.enqueueCommand(\switch);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 3) Bypass delay ON, then OFF, with another switch
~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\on);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\off);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// Print chain state (also drives GUI detailed view)
~pedalboard.printChains;
)
