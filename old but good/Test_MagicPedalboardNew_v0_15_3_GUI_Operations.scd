// Test_MagicPedalboardNew_v0_15_3_GUI_Operations.scd
// MD 20250912-1527

// Visual ops list + expectation + 3s countdown + embedded meters
// Strict var-first; no server.sync; safe resets; no double /n_free


(
s.waitForBoot({
    var preflightCleanup;
    var makeSourcesAndProcessors;
    var m, gui, setHear;
    var ops, doStep;

    // 0) Preflight (avoid double free: only clear Ndefs)
    preflightCleanup = {
        var needPopProxySpace;
        "[-] Preflight: clearing Ndefs & ProxySpaces…".postln;

        Ndef.all.keysValuesDo({ arg keySym, proxyRef;
            var exists;
            exists = proxyRef.notNil;
            if(exists) {
                proxyRef.clear; // no proxy.stop here → avoids duplicate /n_free
            };
        });

        if(ProxySpace.respondsTo(\all)) {
            ProxySpace.all.keysValuesDo({ arg serverRef, proxySpace;
                var existsPS;
                existsPS = proxySpace.notNil;
                if(existsPS) { proxySpace.clear };
            });
        };

        needPopProxySpace = currentEnvironment.notNil and: { currentEnvironment.class.name == "ProxySpace" };
        if(needPopProxySpace) {
            currentEnvironment.pop;
        };

        s.initTree;
        s.defaultGroup.freeAll;
        "== Preflight done ==".postln;
    };
    preflightCleanup.();

    // 1) Sources / processors
    makeSourcesAndProcessors = {
        var alreadyThere;
        alreadyThere = false;

        Ndef(\ts0,   { Silent.ar(2) });
        Ndef(\tsSaw, { Saw.ar(200, 0.18) ! 2 });
        Ndef(\tsSine,{ SinOsc.ar(333, 0, 0.22) ! 2 });
        Ndef(\tsDust,{ Dust.ar(2000) ! 2 });

        Ndef(\tremolo, { arg rate = 4, depth = 0.8;
            var inputSignal;
            inputSignal = \in.ar(2);
            inputSignal * SinOsc.kr(rate).range(1 - depth, 1)
        });

        Ndef(\lofi, { arg bits = 6, rate = 6000;
            var inputSignal;
            inputSignal = \in.ar(2);
            Decimator.ar(inputSignal, rate, bits)
        });

        Ndef(\atten, { arg gain = 0.25;
            var inputSignal;
            inputSignal = \in.ar(2);
            inputSignal * gain
        });
    };
    makeSourcesAndProcessors.();

    // 2) Pedalboard + GUI
    m = MagicPedalboardNew.new;
    gui = MagicDisplayGUI.new(1);
    m.setDisplay(gui);

    // known baseline
    m.reset;
    m.setSourceCurrent(\ts0);
    m.setSource(\ts0);
    m.clearChain;
    m.switchChain(0.1);
    m.clearChain;
    m.switchChain(0.1);

    gui.enableMeters(true);

    setHear = { arg textString, seconds = 0;
        gui.showExpectation(textString, seconds);
    };

    // 3) Ops (labels + actions)
    ops = Array.new;

    ops = ops.add((
        label: "Make CURRENT audible (Saw)",
        action: {
            var note;
            note = "CURRENT: plain Saw tone. Moderate level, stable pitch.";
            setHear.(note, 3);
            m.setSourceCurrent(\tsSaw);
            m.playCurrent;
        }
    ));

    ops = ops.add((
        label: "Prepare NEXT: add Tremolo; then crossfade switch",
        action: {
            var note;
            note = "Switch to Saw with Tremolo (deep). You should hear strong amplitude modulation.";
            setHear.(note, 3);
            m.setSource(\tsSaw);
            m.add(\tremolo);
            m.bypass(\tremolo, false);
            m.switchChain(0.10);
        }
    ));

    ops = ops.add((
        label: "Sweep Tremolo rate 2→12 Hz then back",
        action: {
            var ratesUp, ratesDown;
            setHear.("Rate sweep on CURRENT tremolo.", 0);
            ratesUp = (2..12);
            ratesDown = ratesUp.reverse;
            ratesUp.do({ arg rateValue; Ndef(\tremolo).set(\rate, rateValue); 0.2.wait; });
            ratesDown.do({ arg rateValue; Ndef(\tremolo).set(\rate, rateValue); 0.2.wait; });
        }
    ));

    ops = ops.add((
        label: "Toggle CURRENT tremolo bypass",
        action: {
            var note;
            note = "Bypass tremolo (plain Saw), then re-enable.";
            setHear.(note, 3);
            m.bypassCurrent(\tremolo, true);  0.5.wait;
            m.bypassCurrent(\tremolo, false); 0.5.wait;
        }
    ));

    ops = ops.add((
        label: "Prepare NEXT: add Atten + Lofi; swap; crossfade switch",
        action: {
            var note;
            note = "Attenuated + crushed Saw after switch.";
            setHear.(note, 3);
            m.addAt(\atten, 1);
            m.addAt(\lofi, 2);
            m.swap(1, 2);
            m.switchChain(0.12);
        }
    ));

    ops = ops.add((
        label: "Sweep Lofi params (bits 4..10, rate 4k..12k)",
        action: {
            var bitsSeq, rateSeq;
            setHear.("Lofi bits + rate sweeps.", 0);
            bitsSeq = (4..10);
            bitsSeq.do({ arg bitsValue; Ndef(\lofi).set(\bits, bitsValue); 0.2.wait; });
            rateSeq = Array.series(17, 4000, 500);
            rateSeq.do({ arg srValue; Ndef(\lofi).set(\rate, srValue); 0.2.wait; });
        }
    ));

    ops = ops.add((
        label: "Return to silence (NEXT→\\ts0) and crossfade",
        action: {
            var note;
            note = "Silence after switch.";
            setHear.(note, 3);
            m.setSource(\ts0);
            m.clearChain;
            m.switchChain(0.10);
        }
    ));

    // bind (GUI queues until UI exists)
    gui.setOperations(ops.collect({ arg x; x[\label] }));

    doStep = { arg indexToRun;
        var entry;
        entry = ops[indexToRun];
        if(entry.notNil) {
            Routine({
                entry[\action].value;
            }).play(SystemClock);
        };
    };

    gui.setNextAction({ arg indexToRun;
        doStep.(indexToRun);
    });

    gui.showExpectation("Press 'Next' to begin. The action runs after a 3-second visual countdown.", 0);
});
)
