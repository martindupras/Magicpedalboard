// MagicPedalboardTestRunner.sc
// v0.2.2
// MD 20250919

/*
Purpose:
- Unified bring-up, audio reset, GUI sync, and test runner for MagicPedalboardNew.
- Replaces StartHere_CleanBoot_OneWindow_BringUp.scd.
- Logs all steps using MDMiniLogger.
- Extensible with new test methods.

Style:
- var-first; lowercase methods; no server.sync.
- Server ops inside Server.default.bind; GUI ops on AppClock.
- No single-letter vars; all var declarations at top of each block.
*/

MagicPedalboardTestRunner : Object {
    var <logger, <pedalboard, <gui;

    *new { arg mpb, gui;
        ^super.new.init(mpb, gui);
    }

    init { arg mpb, gui;
        pedalboard = mpb;
        this.gui = gui;
        logger = MDMiniLogger.new("MagicPedalboardTestRunner");
        ^this;
    }

    bringUp {
        var trigger, sequence, freqDemand, envelope, toneSignal, panPosition;
        var isPlayingA, isPlayingB, currentSink;

        logger.info("Starting full bring-up...");

        Server.default.waitForBoot({
            Server.default.bind({
                Server.default.initTree;
                Server.default.defaultGroup.freeAll;
                logger.info("Server tree initialized.");
            });
        });

        Server.default.bind({
            Ndef(\chainA, { \in.ar(2) }).ar(2);
            Ndef(\chainB, { \in.ar(2) }).ar(2);
            Ndef(\ts0, { Silent.ar(2) }).ar(2);
            Ndef(\testmelody, {
                trigger = Impulse.kr(3.2);
                sequence = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
                freqDemand = Demand.kr(trigger, 0, sequence);
                envelope = Decay2.kr(trigger, 0.01, 0.35);
                toneSignal = SinOsc.ar(freqDemand) * envelope * 0.25;
                panPosition = ToggleFF.kr(trigger).linlin(0, 1, -0.6, 0.6);
                Pan2.ar(toneSignal, panPosition);
            }).ar(2);
            logger.info("Sinks and sources defined.");
        });

        pedalboard.reset;
        pedalboard.setSourceCurrent(\testmelody);
        pedalboard.playCurrent;
        pedalboard.enforceExclusiveCurrentOptionA(0.1);

        if(gui.notNil) {
            gui.enableMeters(false);
            gui.enableMeters(true);
            gui.window.front;
            gui.showExpectation("System ready", 0);
        };

        pedalboard.printChains;

        isPlayingA = Ndef(\chainA).isPlaying;
        isPlayingB = Ndef(\chainB).isPlaying;
        logger.info("Playback state: A.playing=" ++ isPlayingA ++ " B.playing=" ++ isPlayingB);
        logger.info("Bring-up complete.");
    }

    audioReset {
        logger.info("Running ~audioReset...");
        if(~audioReset.notNil) {
            ~audioReset.();
            logger.info("~audioReset complete.");
        } {
            logger.warn("~audioReset is not defined.");
        };
    }

    syncGui {
        var currentSink;
        if(gui.notNil) {
            currentSink = pedalboard.effectiveCurrent[0];
            gui.window.front;
            gui.highlightCurrentColumn(currentSink);
            gui.showChainsDetailed(
                pedalboard.effectiveCurrent,
                pedalboard.effectiveNext,
                pedalboard.bypassKeysCurrent,
                pedalboard.bypassKeysNext,
                pedalboard.effectiveCurrent,
                pedalboard.effectiveNext
            );
            logger.info("GUI synced with audio state.");
        };
    }

    runAcceptanceTest {
        logger.info("Running acceptance test...");
        pedalboard.add(\delay);
        pedalboard.switchChain(0.12);
        pedalboard.bypassCurrent(\delay, true);
        pedalboard.bypassCurrent(\delay, false);
        pedalboard.switchChain(0.12);
        pedalboard.printChains;
        logger.info("Acceptance test complete.");
    }

    verifyAudioState {
        var isPlayingA, isPlayingB;
        isPlayingA = Ndef(\chainA).isPlaying;
        isPlayingB = Ndef(\chainB).isPlaying;
        logger.info("Audio state: A.playing=" ++ isPlayingA ++ " B.playing=" ++ isPlayingB);
    }

    help {
        "Available methods: bringUp, audioReset, syncGui, runAcceptanceTest, verifyAudioState".postln;
    }
}
