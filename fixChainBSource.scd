// fixChainBSource.scd
// v0.1
// MD 20250917-1241

~ct_applyOSCPathToMPB.("/setSource/testmelody", ~mpb, ~gui);
~ct_applyOSCPathToMPB.("/add/delay", ~mpb, ~gui);  // optional FX on NEXT
~ct_applyOSCPathToMPB.("/switch",    ~mpb, ~gui);
