// diag_mpb_audio_path.scd
// v0.1
// MD 20250916-1012

(
var log, ensureAudio, playDirect, patchChainManually, patchViaPedalboard;

log = { arg msg; ("[DIAG] " ++ msg).postln };

// A) Boot audio + define a clearly audible test source (stereo)
ensureAudio = {
    Server.default.boot;
    Server.default.bind({
        Ndef(\toneTest, {
            var sig;
            sig = Saw.ar([120, 180]) * 0.15; // steady tone, obvious
            sig
        });
        Ndef(\toneTest).ar(2);
    });
    log.("Audio booted and \\toneTest defined.");
};

// B) Direct play (bypass chain) — you MUST hear a steady tone
playDirect = {
    Ndef(\toneTest).play;
    log.("Direct play \\toneTest — you should hear steady tone now.");
};

// C) Manual chain patch: route \\toneTest -> \\chainA (no pedalboard API)
// Expectation: you still hear tone via \\chainA after .play
patchChainManually = {
    // ensure chainA exists
    Ndef(\chainA, { \in.ar(2) });
    Ndef(\chainA) <<>> Ndef(\toneTest);
    Ndef(\chainA).play;
    log.("Manual patch: chainA <<>> toneTest; chainA.play — you should still hear tone.");
};

// D) Pedalboard flow: reset -> setSource -> **playCurrent** (explicit) -> print
patchViaPedalboard = {
    ~gui = ~gui ?? { MagicDisplayGUI.new() };
    ~pedalboard = ~pedalboard ?? { MagicPedalboardNew.new(~gui) };
    ~pedalboard.reset;              // clean chains
    ~pedalboard.setSource(\toneTest);
    ~pedalboard.playCurrent;        // explicit start of CURRENT
    ~pedalboard.printChains;
    log.("Pedalboard: reset -> setSource toneTest -> playCurrent — you should hear tone.");
};

// --- run steps ---
ensureAudio.value;
playDirect.value;

// comment out the direct play once you confirm sound, then test the next steps:
// Ndef(\toneTest).stop;  // uncomment to stop direct play

// patchChainManually.value;  // uncomment to test manual chain route
// Ndef(\chainA).stop;        // stop manual chain when done

// patchViaPedalboard.value;  // uncomment to test pedalboard path (preferred for demo)
)
