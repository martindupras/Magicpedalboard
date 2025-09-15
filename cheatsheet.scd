// cheatsheet.cd
// MD 20250913-1037

// Inspect
~pedalboard.printChains;            // or use your display adaptor

// Build NEXT non-destructively
~pedalboard.add(\delay);
~pedalboard.bypass(\delay, true);
~pedalboard.swap(1, 2);

// Go live with a short crossfade
~pedalboard.switchChain(0.1);

// Adjust CURRENT temporarily
~pedalboard.bypassAtCurrent(1, false);

// Change sources
~pedalboard.setSource(\ts1);
~pedalboard.setSourceCurrent(\ts2);

// Panic-safe reset
~pedalboard.reset;
