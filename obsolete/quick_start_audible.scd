// quick_start_audible.scd
// v0.1

(
// 0) Recompile classes first (Cmd+Shift+L) if you just edited them.
// 1) GUI + pedalboard
~gui = ~gui ?? { MagicDisplayGUI.new };
~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };

// 2) Make CURRENT use our internal melody, play it
~mpb.setSourceCurrent(\testmelody);
~mpb.playCurrent;

// 3) Add delay to NEXT and switch (should hear the echo)
~mpb.add(\delay);
~mpb.switchChain(0.12);

// 4) If you still hear nothing, run the recover helper:
~recoverIfSilent.();

// 5) Inspect
~mpb.printChains;
"[[PLAY]] A=%  B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying).postln;
)
