// Test_MagicAudio_BringUp_A_B.scd
// v0.9.3
// MD 20250919-09:16 BST

/*
Purpose
- Robust audio bring-up (no SoundIn), Option A for NEXT:
  - Atomic build into a dedicated root group (~mpRoot).
  - A audible; B muted at source until switch.
  - FX via Ndef(\chainX).filter dictionary.
  - Helpers: ~applyToNext, ~clearNext, ~switchNow, ~audioReset.

Style
- var-first; lowercase; AppClock-only; no server.sync.
*/

(
var boot, installFxDict, buildOnce, installHelpers, announce;
var s;

boot = {
    var run;
    run = {
        s = Server.default;
        s.waitForBoot({
            Server.default.bind({
                s.initTree;
                s.defaultGroup.freeAll;
            });
            ("[AUDIO] server booted: " ++ s.addr).postln;
        });
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

installFxDict = {
    var run;
    run = {
        ~fx = IdentityDictionary[
            \delay -> { arg in, time=0.35, decay=2.0, max=1.0;
                time = time.clip(0.005, max);
                CombC.ar(in, max, time, decay)
            },
            \reverb -> { arg in, mix=0.20, room=0.60, damp=0.50;
                FreeVerb.ar(in, mix.clip(0,1), room.clip(0,1), damp.clip(0,1))
            },
            \chorus -> { arg in, depth=0.003, rate=0.25;
                var mod;
                mod = SinOsc.kr(rate).range(depth * -1, depth);
                DelayC.ar(in, depth*2 + 0.01, mod + depth + 0.005)
            },
            \tremolo -> { arg in, rate=5, depth=0.6;
                var lfo;
                lfo = LFTri.kr(rate).range(1-depth, 1);
                in * lfo
            }
        ];
        "[FX] dictionary installed (\\delay, \\reverb, \\chorus, \\tremolo)".postln;
        nil
    };
    AppClock.sched(0.02, { run.value; nil });
};

buildOnce = {
    var run;
    run = {
        var lat, atomBuild, stopClear;
        lat = s.latency ? 0.2;

        atomBuild = {
            // stop/clear any prior proxies quietly
            stopClear = { arg name;
                var p = Ndef(name);
                if(p.isPlaying) { p.stop };
                p.clear;
            };
            [\out, \mix, \chainA, \chainB, \srcA, \srcB].do(stopClear);

            // new root group
            if(~mpRoot.notNil) { try { ~mpRoot.free } };
            ~mpRoot = Group.head(s);

            // sources
            Ndef(\srcA).fadeTime = 0.02;
            Ndef(\srcA).source = { arg amp=0.20;
                var t, seq, freq, sig;
                t   = Impulse.kr(2);
                seq = Demand.kr(t, 0, Dseq([220, 277, 247, 294, 330, 262], inf));
                freq= Lag.kr(seq, 0.02);
                sig = Mix.new(VarSaw.ar(freq * [1, 0.501], 0, 0.4)) * 0.35;
                sig = LPF.ar(sig, 6000);
                Pan2.ar(sig, 0) * amp;
            };

            Ndef(\srcB).fadeTime = 0.02;
            Ndef(\srcB).source = { arg amp=0.20, muted=1;
                var t, seq, freq, sig;
                t   = Impulse.kr(2);
                seq = Demand.kr(t, 0, Dseq([196, 233, 262, 220, 294, 247], inf));
                freq= Lag.kr(seq, 0.02);
                sig = Mix.new(VarSaw.ar(freq * [1, 0.503], 0, 0.4)) * 0.35;
                sig = LPF.ar(sig, 5400);
                sig = Pan2.ar(sig, 0) * amp;
                Select.ar(muted.clip(0,1), [sig, Silent.ar(2)])
            };

            // chains
            Ndef(\chainA).fadeTime = 0.02;
            Ndef(\chainA).source = { Ndef(\srcA).ar };

            Ndef(\chainB).fadeTime = 0.02;
            Ndef(\chainB).source = { Ndef(\srcB).ar };

            // mix and out
            Ndef(\mix).fadeTime = 0.02;
            Ndef(\mix).source = { Ndef(\chainA).ar + Ndef(\chainB).ar };

            Ndef(\out).fadeTime = 0.02;
            Ndef(\out).source = { Ndef(\mix).ar };

            // play out into our group (positional group arg #6)
            Ndef(\out).play(0, nil, ~mpRoot, 1.0, 1.0, 0.02, \addToHead);

            // initial params
            Ndef(\srcA).set(\amp, 0.20);
            Ndef(\srcB).set(\amp, 0.20, \muted, 1); // Option A
        };

        s.makeBundle(lat, atomBuild);
        AppClock.sched(lat + 0.05, { "[AUDIO] atomic graph built + out playing".postln; nil });
        nil
    };
    AppClock.sched(0.04, { run.value; nil });
};

installHelpers = {
    var run;
    run = {
        ~currentIsA = true;
        ~ampA = 0.20; ~ampB = 0.20;

        ~applyToNext = { arg fxSym, params = ( );
            var f;
            f = ~fx[fxSym];
            if(f.isNil) {
                ("[FX] unknown: " ++ fxSym).warn;
            }{
                Ndef(\chainB).filter(fxSym, f, params);
                "[FX] applied to NEXT: ".post; fxSym.postln;
            };
        };

        ~clearNext = {
            Ndef(\chainB).clear;
            Ndef(\chainB).source = { Ndef(\srcB).ar };
            "[FX] NEXT cleared".postln;
        };

        ~switchNow = {
            if(~currentIsA) {
                Ndef(\srcA).set(\amp, 0.0);
                Ndef(\srcB).set(\muted, 0, \amp, ~ampB);
                ~currentIsA = false;
                if(~gui.notNil) { ~gui.highlightCurrentColumn(\chainB) };
                "[SWITCH] B is now CURRENT".postln;
            }{
                Ndef(\srcB).set(\amp, 0.0, \muted, 1);
                Ndef(\srcA).set(\amp, ~ampA);
                ~currentIsA = true;
                if(~gui.notNil) { ~gui.highlightCurrentColumn(\chainA) };
                "[SWITCH] A is now CURRENT".postln;
            };
        };

        ~audioReset = {
            var lat, doReset;
            lat = s.latency ? 0.2;
            doReset = {
                [\out, \mix, \chainA, \chainB, \srcA, \srcB].do({ arg k;
                    var p = Ndef(k);
                    if(p.isPlaying) { p.stop };
                    p.clear;
                });
                if(~mpRoot.notNil) { try { ~mpRoot.free } };
            };
            s.makeBundle(lat, doReset);
            AppClock.sched(lat + 0.05, { buildOnce.value; nil });
            "[AUDIO] reset requested".postln;
        };

        // initial GUI hint
        if(~gui.notNil) { ~gui.highlightCurrentColumn(\chainA) };
        nil
    };
    AppClock.sched(0.10, { run.value; nil });
};

announce = {
    var run;
    run = {
        "[READY] Audio up. Helpers: ~applyToNext.(\\delay), ~clearNext.(), ~switchNow.(), ~audioReset.()".postln;
        nil
    };
    AppClock.sched(0.12, { run.value; nil });
};

boot.value;
installFxDict.value;
buildOnce.value;
installHelpers.value;
announce.value;
)
