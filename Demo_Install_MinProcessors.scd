// Demo_Install_MinProcessors.scd
// v0.1.0
// MD 2025-09-18 11:58 BST

/* Purpose
   - Install a minimal, safe stereo \delay processor so chains like
     [chainX, delay, testmelody] are AUDIBLE.
   - Generated audio only; processors read from \in.ar(2); no SoundIn.
   - Idempotent; safe to re-run.

   Style
   - var-first in every function/closure; lowercase method names.
   - No server.sync; wrap server ops in Server.default.bind.
   - JITLib connections elsewhere MUST use Ndef(left) <<> Ndef(right).
*/

(
var installDelay;
installDelay = {
    Server.default.bind({
        // Simple feedback delay. Reads from \in.ar(2) per project policy.
        Ndef(\delay, {
            var inSig, maxDelay, time, fb, mix, wet;
            inSig    = \in.ar(2);              // <- policy: processors read from \in.ar(defaultNumChannels)
            maxDelay = 1.0;
            time     = (\time.kr(0.25)).clip(0.0, maxDelay);
            fb       = (\fb.kr(0.25)).clip(0.0, 0.95);
            mix      = (\mix.kr(0.35)).clip(0.0, 1.0);
            wet      = DelayC.ar(inSig + (LocalIn.ar(2) * fb), maxDelay, time);
            LocalOut.ar(wet);
            XFade2.ar(inSig, wet, (mix * 2) - 1) * 0.9
        });
        // Pin stereo/audio-rate bus shape (authoritative shape)
        Ndef(\delay).mold(2, \audio);
    });
    "[MINPROC] Installed \\delay (stereo)".postln;
};
installDelay.();
)
