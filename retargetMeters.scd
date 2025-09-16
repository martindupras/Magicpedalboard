(
// retargetMeters.scd
// v0.1
// MD 20250916

var ensureAudioRateAndReloadMeters, hasGui;

ensureAudioRateAndReloadMeters = {
    hasGui = (~gui.notNil) and: { ~gui.isKindOf(MagicDisplayGUI) };

    // Turn meters off to free Synths/OSCdefs cleanly
    if(hasGui) { ~gui.enableMeters(false) };

    // Ensure sinks are audio-rate proxies (2 channels)
    Ndef(\chainA).ar(2);
    Ndef(\chainB).ar(2);

    // Turn meters back on; will now bind to the audio buses
    if(hasGui) { ~gui.enableMeters(true) };

    "[meters] reattached to audio-rate buses".postln;
};

ensureAudioRateAndReloadMeters.();
)
