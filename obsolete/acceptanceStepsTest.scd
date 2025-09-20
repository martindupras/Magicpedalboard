// acceptanceStepsTest.scd
// v0.1
// MD 20250916

// [1] Add delay to NEXT (B while A is current)
~mpb.add(\delay);
~mpb.printChains;

// [2] Switch (A -> B) with a short fade
~mpb.switchChain(0.12);
("After switch: A.playing=" ++ Ndef(\chainA).isPlaying ++ "  B.playing=" ++ Ndef(\chainB).isPlaying).postln;
~mpb.printChains;

// [3] Bypass ON (CURRENT)
~mpb.bypassCurrent(\delay, true);
~mpb.printChains;

// [4] Bypass OFF (CURRENT)
~mpb.bypassCurrent(\delay, false);
~mpb.printChains;

// [5] Switch back (B -> A)
~mpb.switchChain(0.12);
("Final: A.playing=" ++ Ndef(\chainA).isPlaying
 ++ "  B.playing=" ++ Ndef(\chainB).isPlaying).postln;
~mpb.printChains;
