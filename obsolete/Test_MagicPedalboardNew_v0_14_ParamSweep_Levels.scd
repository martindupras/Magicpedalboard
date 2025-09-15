// Test_MagicPedalboardNew_v0_14_ParamSweep_Levels.scd
// Crossfade switch + parameter sweeps + GUI meters (no server.sync; safe resets)
// MD 20250912-1451

(
s.waitForBoot({
    // ─────────────────────────────────────────────────────────
    // 0) Preflight (safe): clear JITLib state, keep default group
    // ─────────────────────────────────────────────────────────
    var preflightCleanup;
    var m, gui;
	var meterWin, meterA, meterB, meterSynthA, meterSynthB, busA, busB;

    preflightCleanup = {
        "[-] QA Preflight: clearing Ndefs & ProxySpaces…".postln;
        Ndef.all.keysValuesDo { arg keySym, proxyRef;
            if(proxyRef.isPlaying) { ("[CLEAN] stop " ++ keySym).postln; proxyRef.stop };
            proxyRef.clear;
        };
        if(ProxySpace.respondsTo(\all)) {
            ProxySpace.all.keysValuesDo { arg serverRef, proxySpace;
                if(proxySpace.notNil) { ("[CLEAN] ProxySpace on " ++ serverRef).postln; proxySpace.clear };
            };
        };
        if(currentEnvironment.notNil and: { currentEnvironment.class.name == "ProxySpace" }) {
            "[CLEAN] Pop current ProxySpace env".postln;
            currentEnvironment.pop;
        };
        s.initTree;
        s.defaultGroup.freeAll;
        "== Preflight done ==".postln;
    };
    preflightCleanup.();

    // ─────────────────────────────────────────────────────────
    // 1) Minimal sources / processors
    // ─────────────────────────────────────────────────────────
    Ndef(\ts0, { Silent.ar(2) });
    Ndef(\tsSaw, { Saw.ar(200, 0.18) ! 2 });
    Ndef(\tsSine, { SinOsc.ar(333, 0, 0.22) ! 2 });
    Ndef(\tsDust, { Dust.ar(2000) ! 2 });

    // processors
    Ndef(\tremolo, { arg rate = 4, depth = 0.8;
        var x;
        x = \in.ar(2);
        x * SinOsc.kr(rate).range(1 - depth, 1)
    });

    Ndef(\lofi, { arg bits = 6, rate = 6000;
        var x;
        x = \in.ar(2);
        Decimator.ar(x, rate, bits)
    });

    Ndef(\atten, { arg gain = 0.25;
        var x;
        x = \in.ar(2);
        x * gain
    });

    // ─────────────────────────────────────────────────────────
    // 2) Pedalboard + GUI
    // ─────────────────────────────────────────────────────────

    m = MagicPedalboardNew.new;
    gui = MagicDisplayGUI.new(1);
    m.setDisplay(gui);

    // start from silence on CURRENT
    m.reset;
    m.setSourceCurrent(\ts0);
    m.setSource(\ts0);
    m.clearChain; // NEXT => [sink, source]
    m.switchChain(0.1); // ensure CURRENT is also [sink, ts0]
    m.clearChain;
    m.switchChain(0.1);

    // ─────────────────────────────────────────────────────────
    // 3) Level meters (SendReply -> OSCdef -> LevelIndicator)
    // ─────────────────────────────────────────────────────────
    // Two synthdefs to avoid dynamic path strings in UGen
    SynthDef(\busMeterA, { arg inBus, rate = 15;
        var sig, amp;
        sig = In.ar(inBus, 2);
        amp = Amplitude.ar(sig).clip(0, 1);
        SendReply.kr(Impulse.kr(rate), '/ampA', A2K.kr(amp));
    }).add;

    SynthDef(\busMeterB, { arg inBus, rate = 15;
        var sig, amp;
        sig = In.ar(inBus, 2);
        amp = Amplitude.ar(sig).clip(0, 1);
        SendReply.kr(Impulse.kr(rate), '/ampB', A2K.kr(amp));
    }).add;

    // Meter GUI

    meterWin = Window("Levels – chainA / chainB", Rect(100, 500, 460, 120)).front.alwaysOnTop_(true);
    meterA = LevelIndicator(meterWin, Rect(10, 10, 440, 24));
    StaticText(meterWin, Rect(10, 36, 440, 16)).string_("chainA");
    meterB = LevelIndicator(meterWin, Rect(10, 60, 440, 24));
    StaticText(meterWin, Rect(10, 86, 440, 16)).string_("chainB");

    busA = Ndef(\chainA).bus;
    busB = Ndef(\chainB).bus;

    Server.default.bind({
        meterSynthA = Synth(\busMeterA, [\inBus, busA.index, \rate, 20]);
        meterSynthB = Synth(\busMeterB, [\inBus, busB.index, \rate, 20]);
    });

    OSCdef(\ampA, { arg msg;
        var leftAmp, rightAmp, level;
        leftAmp = msg[3];
        rightAmp = msg[4];
        level = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
        AppClock.sched(0, { meterA.value = level; nil });
    }, '/ampA');

    OSCdef(\ampB, { arg msg;
        var leftAmp, rightAmp, level;
        leftAmp = msg[3];
        rightAmp = msg[4];
        level = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
        AppClock.sched(0, { meterB.value = level; nil });
    }, '/ampB');

    // ─────────────────────────────────────────────────────────
    // 4) Narrative: crossfades + parameter sweeps
    // ─────────────────────────────────────────────────────────
    Routine({
        var sweepSteps, stepIndex, sweepDepths, depthIndex, show;
        var waitShort, waitMed, waitLong;

        show = { m.printChains };
        waitShort = { 1.0.wait };
        waitMed   = { 2.0.wait };
        waitLong  = { 3.0.wait };

        // A) make CURRENT audible with Saw
        m.setSourceCurrent(\tsSaw);
        m.playCurrent;
        show.();
        waitMed.();

        // B) prepare NEXT: Saw + Tremolo (deep), then crossfade switch
        m.setSource(\tsSaw);
        m.add(\tremolo);
        m.bypass(\tremolo, false);
        m.switchChain(0.10); // ~100 ms crossfade
        show.();
        waitMed.();

        // C) Sweep tremolo rate 2 -> 12 Hz and back while listening
        sweepSteps = Array.series(11, 2, 1); // 2..12
        stepIndex = 0;
        "— Sweeping tremolo rate —".postln;
        sweepSteps.do { arg rateValue;
            Ndef(\tremolo).set(\rate, rateValue);
            0.25.wait;
        };
        sweepSteps.reverse.do { arg rateValue;
            Ndef(\tremolo).set(\rate, rateValue);
            0.25.wait;
        };

        // D) Toggle bypass on CURRENT tremolo
        m.bypassCurrent(\tremolo, true);  waitShort.(); m.bypassCurrent(\tremolo, false); waitShort.();

        // E) Prepare NEXT: add atten + lofi near sink; swap; then crossfade switch
        m.addAt(\atten, 1);
        m.addAt(\lofi, 2);
        m.swap(1, 2); // \lofi before \atten
        m.switchChain(0.12); // slightly longer crossfade
        show.();
        waitMed.();

        // F) Sweep lofi params
        "— Sweeping lofi —".postln;
        // bits: 4..10
        (4..10).do { arg bitsValue;
            Ndef(\lofi).set(\bits, bitsValue);
            0.2.wait;
        };
        // rate: 4000..12000
        (4000, 500 .. 12000).do { arg srValue;
            Ndef(\lofi).set(\rate, srValue);
            0.2.wait;
        };

        // G) Return to silence via NEXT -> \ts0 and crossfade
        m.setSource(\ts0);
        m.clearChain; // NEXT to [sink, source]
        m.switchChain(0.10);
        show.();
        waitLong.();

        // done
        "Done. Stopping current.".postln;
        m.stopCurrent;

        // cleanup meters
        Server.default.bind({
            meterSynthA.free;
            meterSynthB.free;
        });
        OSCdef(\ampA).free;
        OSCdef(\ampB).free;

    }).play(SystemClock);
});
)
