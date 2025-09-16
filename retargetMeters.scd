// retargetMeters.scd
// v0.1
// MD 20250916

(
// Reattach meters to audio-rate buses
var doFix;
doFix = {
    if(~gui.notNil) { ~gui.enableMeters(false) };   // stop meter synths & OSCdefs
    Ndef(\chainA).ar(2);                            // ensure sinks are audio proxies
    Ndef(\chainB).ar(2);
    if(~gui.notNil) { ~gui.enableMeters(true) };    // restart meters on the audio buses
    "Meters reattached to audio-rate buses.".postln;
};
doFix.();
)
