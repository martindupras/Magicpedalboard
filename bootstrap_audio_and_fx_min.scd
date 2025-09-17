// bootstrap_audio_and_fx_min.scd
// v0.1

(
Server.default.boot;
Server.default.bind({
    // Musical test source (stereo) – guaranteed audibility
    Ndef(\testmelody, {
        var trig = Impulse.kr(3.2);
        var seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
        var f    = Demand.kr(trig, 0, seq);
        var env  = Decay2.kr(trig, 0.01, 0.35);
        var tone = SinOsc.ar(f) * env * 0.25;
        var pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
        Pan2.ar(tone, pan)
    });
    Ndef(\testmelody).ar(2);

    // Minimal \delay (stereo) – matches your style using \in.ar
    Ndef(\delay, { |in, time=0.45, fb=0.35, mix=0.5|
        var sig    = \in.ar(2);
        var delayed= CombC.ar(sig, 2.0, time.clip(0.01, 2.0),
                              time * (fb.clip(0.0, 0.95) * 6 + 0.1));
        XFade2.ar(sig, delayed, mix.clip(0,1) * 2 - 1)
    });
    Ndef(\delay).ar(2);
});
)
