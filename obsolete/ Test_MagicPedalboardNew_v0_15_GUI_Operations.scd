// Test_MagicPedalboardNew_v0_15_GUI_Operations.scd
// Visual ops list + expectation + 3s countdown + meters in GUI
// MD 20250912-1511

(
s.waitForBoot({
    // ─────────────────────────────────────────────────────────
    // 0) Preflight (safe, no s.freeAll; var-first)
    // ─────────────────────────────────────────────────────────
    var preflightCleanup;
	    var m, gui, setHear, ops, doStep;

    preflightCleanup = {
        "[-] Preflight: clearing Ndefs & ProxySpaces…".postln;
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
    Ndef(\ts0,  { Silent.ar(2) });
    Ndef(\tsSaw, { Saw.ar(200, 0.18) ! 2 });
    Ndef(\tsSine,{ SinOsc.ar(333, 0, 0.22) ! 2 });
    Ndef(\tsDust,{ Dust.ar(2000) ! 2 });

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
    // 2) Pedalboard + GUI setup
    // ─────────────────────────────────────────────────────────

    m = MagicPedalboardNew.new;
    gui = MagicDisplayGUI.new(1);
    m.setDisplay(gui);

    // Start from a known silent baseline on CURRENT
    m.reset;
    m.setSourceCurrent(\ts0);
    m.setSource(\ts0);
    m.clearChain;
    m.switchChain(0.1);
    m.clearChain;
    m.switchChain(0.1);

    // Enable meters (embedded)
    gui.enableMeters(true);

    setHear = { arg textString, seconds = 0;
        gui.showExpectation(textString, seconds);
    };

    // ─────────────────────────────────────────────────────────
    // 3) Define operations (strings + actions)
    // ─────────────────────────────────────────────────────────
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
            ratesUp = (2..12);
            ratesDown = ratesUp.reverse;
            setHear.("Rate sweep on CURRENT tremolo.", 0);
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
            m.swap(1, 2);       // lofi before atten
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

    // Bind operations and "Next" button
    gui.setOperations(ops.collect({ arg x; x[\label] }));

    doStep = { arg indexToRun;
        var entry;
        entry = ops[indexToRun];
        if(entry.notNil) {
            // Run on a SystemClock Routine to allow waits inside actions
            Routine({
                entry[\action].value;
            }).play(SystemClock);
        };
    };

    gui.setNextAction({ arg indexToRun; doStep.(indexToRun) });

    // Provide an initial hint
    gui.showExpectation("Press 'Next' to begin. The next action will run after a 3-second visual countdown.", 0);
});
)
