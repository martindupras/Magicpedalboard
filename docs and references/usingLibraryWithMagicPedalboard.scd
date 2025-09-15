// usingLibraryWithMagicPedalboard.scd
// MD 20250915-0914


(
// If you’ve loaded MagicProcessorLibrary_defs.scd already:
~procLib.ensureMany([\ts0, \delay, \tremolo, \reverb, \chorus, \drive], 2);

// Then (re)build your pedalboard chains knowing those symbols resolve:
~pedalboard.reset;
~pedalboard.add(\delay);
~pedalboard.switchChain(0.1);
)
