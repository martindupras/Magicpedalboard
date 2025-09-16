// diag_pedalboard_current_play.scd
// v0.1
// MD 20250916-1019

(
var log;

log = { arg msg; ("[DIAG] " ++ msg).postln };

// Bring up a single GUI window (your runner), then ensure pedalboard exists
~md_bootProbeScenario.();   // one window + PROBE FRAME (GUI ops on AppClock)

// Create or reuse GUI + Pedalboard
~gui = ~gui ?? { MagicDisplayGUI.new() };
~pedalboard = ~pedalboard ?? { MagicPedalboardNew.new(~gui) };

// Clean and start CURRENT audibly
~pedalboard.reset;
~pedalboard.setSource(\toneTest);
~pedalboard.playCurrent;    // <-- critical for immediate audibility
~pedalboard.printChains;

log.("Pedalboard: reset -> setSource toneTest -> playCurrent — you should hear steady tone now.");
)
