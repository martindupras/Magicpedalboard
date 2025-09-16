// diag_fix_current_source_now.scd
// v0.1
// MD 20250916-1030

(
var log, ensureSource;

log = { arg msg; ("[FIX] " ++ msg).postln };

// Ensure a musical internal source exists (reuse if already defined)
ensureSource = {
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
    });
};

ensureSource.value;

// One GUI window (runner)
~md_bootProbeScenario.();

// Ensure GUI + Pedalboard, then set CURRENT source and start it
~gui = ~gui ?? { MagicDisplayGUI.new() };
~pedalboard = ~pedalboard ?? { MagicPedalboardNew.new(~gui) };

~pedalboard.reset;
~pedalboard.setSourceCurrent(\testmelody);   // <-- CURRENT, not NEXT
~pedalboard.playCurrent;                     // <-- start CURRENT so you hear it
~pedalboard.printChains;

log.("CURRENT should now be audible from \\testmelody.");
)
