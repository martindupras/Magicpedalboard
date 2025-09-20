// MPBTest_BringUp.sc
// v0.1.9
// MD 20250920-1919

// Purpose
// - Fresh-boot bring-up with Grid GUI by default; avoids display=nil and close/create races.
// Style
// - var-first; lowercase; AppClock for GUI; Server.default.bind for audio; no server.sync.

MPBTest_BringUp : Object {
    classvar < version;
    var < logger, < pedalboard, < gui, < readyFlag, < numChannels, < testAmp;

    *initClass { version = "v0.1.9"; ("MPBTest_BringUp " ++ version).postln; }

    *new {
        arg useGui = true, channels = 2, sourceAmp = 0.40, publishToTildes = true,
            freshBoot = true, guiClassSym = \MagicDisplayGUI_GridDemo, closeExistingGUIs = true;
        ^super.new.init(useGui, channels, sourceAmp, publishToTildes, freshBoot, guiClassSym, closeExistingGUIs)
    }

    init { arg useGui, channels, sourceAmp, publishToTildes, freshBoot, guiClassSym, closeExistingGUIs;
        var s, doFreshBoot, startBoot, afterBoot, scheduleGuiClose, scheduleGuiCreate;
        var ensureSinks, ensureSources, setSourcesAndPlay, enforceOptionA, attachMeters, postBaseline, maybePublish;

        logger     = MDMiniLogger.new("MPBTest_BringUp");
        readyFlag  = false;
        numChannels = (channels ? 2).asInteger.max(1);
        testAmp     = (sourceAmp ? 0.40).asFloat.clip(0.05, 1.0);
        s = Server.default;

        // --- audio preparation ---
        ensureSinks = {
            Server.default.bind({
                Ndef(\chainA, { \in.ar(numChannels) }); Ndef(\chainA).ar(numChannels);
                Ndef(\chainB, { \in.ar(numChannels) }); Ndef(\chainB).ar(numChannels);
            });
        };

        ensureSources = {
            Server.default.bind({
                Ndef(\testmelody, {
                    var trig = Impulse.kr(3.2);
                    var seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                    var f    = Demand.kr(trig, 0, seq);
                    var env  = Decay2.kr(trig, 0.01, 0.35);
                    var pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
                    Pan2.ar(SinOsc.ar(f) * env * testAmp, pan)
                });
                Ndef(\testmelody).ar(numChannels);
                Ndef(\ts0, { Silent.ar(numChannels) }).ar(numChannels);
            });
        };

        setSourcesAndPlay = {
            pedalboard.setDefaultSource(\testmelody);
            pedalboard.setSourceCurrent(\testmelody);
            pedalboard.playCurrent;
        };

        enforceOptionA = {
            pedalboard.enforceExclusiveCurrentOptionA(0.1);
            Server.default.bind({
                var nextSink = pedalboard.nextChain[0];
                Ndef(nextSink).end;
                Ndef(nextSink).mold(numChannels, \audio);
            });
        };

        attachMeters = {
            if(gui.notNil and: { gui.respondsTo(\enableMeters) }) {
                gui.enableMeters(false); gui.enableMeters(true);
            };
        };

        postBaseline = {
            pedalboard.printChains;
            ("[[PLAY]] A=% B=%".format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
            readyFlag = true;
        };

        maybePublish = {
            if(publishToTildes) { ~bring = this; ~mpb = pedalboard; ~gui = gui };
        };

        // --- GUI sequencing to avoid races ---
        scheduleGuiClose = {
            if(closeExistingGUIs and: { useGui }) {
                AppClock.sched(0.00, {
                    var wins = Window.allWindows.select({ arg w;
                        var nm = w.tryPerform(\name) ? "";
                        nm.asString.beginsWith("MagicDisplayGUI")
                    });
                    wins.do(_.close);
                    nil
                });
            };
        };

        scheduleGuiCreate = {
            if(useGui) {
                AppClock.sched(0.05, {
                    gui = guiClassSym.asClass.new;   // MagicDisplayGUI_GridDemo by default
                    gui.window.front.alwaysOnTop_(true);
                    // Build pedalboard only **after** GUI exists so display is bound at construction
                    pedalboard = MagicPedalboardNew.new(gui);
                    setSourcesAndPlay.value;
                    enforceOptionA.value;
                    attachMeters.value;
                    postBaseline.value;
                    maybePublish.value;
                    nil
                });
            }{
                // Headless: create pedalboard immediately (no display)
                AppClock.sched(0.00, {
                    pedalboard = MagicPedalboardNew.new(nil);
                    setSourcesAndPlay.value;
                    enforceOptionA.value;
                    postBaseline.value;
                    maybePublish.value;
                    nil
                });
            };
        };

        // --- boot choreography ---
        afterBoot = {
            ensureSinks.value;
            ensureSources.value;
            scheduleGuiClose.value;
            scheduleGuiCreate.value;
        };

        startBoot = {
            s.doWhenBooted({ afterBoot.value });
            if(s.serverRunning.not) { s.boot };
        };

        doFreshBoot = {
            var waitDown;
            if(s.serverRunning) {
                if(gui.notNil and: { gui.respondsTo(\enableMeters) }) { gui.enableMeters(false) };
                s.quit;
                waitDown = {
                    if(s.serverRunning.not) { startBoot.value; nil } {
                        AppClock.sched(0.05, waitDown)
                    }
                };
                AppClock.sched(0.05, waitDown);
            }{
                startBoot.value;
            };
        };

        if(freshBoot) { doFreshBoot.value } { startBoot.value };
        ^this
    }

    isReady { ^readyFlag }
    getPedalboard { ^pedalboard }
    getGui { ^gui }
    getChannels { ^numChannels }
}
