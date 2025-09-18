// meters_preinstall_busmeters.scd
// v0.1
// MD 20250916-1051

(
SynthDef(\busMeterA, { |inbus=0, numch=2| var sig = In.ar(inbus, numch); 0 }).add;
SynthDef(\busMeterB, { |inbus=0, numch=2| var sig = In.ar(inbus, numch); 0 }).add;
"[Meters] Installed stub SynthDefs: busMeterA/B.".postln;
)
