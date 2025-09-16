// demo_commandtree_milestone.scd
// v0.1
// MD 20250916-0852

(
// ---- A) Audio source + basic FX (no server.sync, safe to re-run) ----
Server.default.boot;  // boot if not already

// Ensure an internal musical test source (stereo) as \testmelody
Server.default.bind({
    Ndef(\testmelody, {
        var trig = Impulse.kr(3.2);
        var seq = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
        var f  = Demand.kr(trig, 0, seq);
        var env = Decay2.kr(trig, 0.01, 0.35);
        var tone = SinOsc.ar(f) * env * 0.25;
        Pan2.ar(tone, ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6))
    });
    Ndef(\testmelody).ar(2);
});

// Optional: simple FX defaults (if not already defined elsewhere)
Server.default.bind({
    Ndef(\delay, { |in, time=0.45, fb=0.35, mix=0.5|
        var sig = \in.ar(2);
        var delayed = CombC.ar(sig, 2.0, time.clip(0.01, 2.0), time * (fb.clip(0,0.95) * 6 + 0.1));
        XFade2.ar(sig, delayed, mix.clip(0,1) * 2 - 1)
    });
    Ndef(\chorus, { |in, rate=0.8, depth=0.008, base=0.020|
        var sig = \in.ar(2);
        var mod = base.clip(0.0, 0.05) + (SinOsc.kr(rate.clip(0.1,5), 0, depth.clip(0.0,0.02)));
        DelayC.ar(sig, 0.1, mod)
    });
});

// ---- B) Bring up your single GUI window (runner you already have) ----
~md_bootProbeScenario.();   // ensures one MagicDisplayGUI window + PROBE FRAME
// ---- C) Ensure pedalboard & bind GUI as display if not already done ----
~gui = ~gui ?? { MagicDisplayGUI.new() };         // class builds window on AppClock internally
~pedalboard = ~pedalboard ?? { MagicPedalboardNew.new(~gui) };
~pedalboard.setSource(\testmelody);               // audible source
~pedalboard.switchChain(0.12);                    // fade in CURRENT

// ---- D) CommandManager (imports ~/CommandTreeSavefiles/myTree.json) ----
~cm = ~cm ?? { CommandManager.new };              // uses your importer path
// If you edited myTree.xml, convert to JSON now (uncomment):
// ~ct_convertXmlToJson.("~/myTree.xml", "~/CommandTreeSavefiles/myTree.json");
// ~cm = CommandManager.new;  // reinit to re-import
// ---- E) Demo sequence using your queue + SEND and the adapter ----
// 1) Add delay to NEXT (your current XML tokens may just be "delay"; adapter maps it to add/delay)
~cm.midiManager.queue.clear;
~cm.midiManager.queue.enqueueCommand(\delay);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 2) Switch to hear it (CURRENT <- NEXT)
~cm.midiManager.queue.enqueueCommand(\switch);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 3) Bypass delay ON (then OFF), then switch again
~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\on);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// Optional: turn bypass OFF and switch back
~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\off);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

~pedalboard.printChains;   // posts and drives GUI detail view
)
