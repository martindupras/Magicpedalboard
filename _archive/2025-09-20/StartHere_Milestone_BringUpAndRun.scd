// StartHere_Milestone_BringUpAndRun.scd
// v0.1.5b
// MD 20250918-18:36 BST

/*
Purpose
- Clean, deterministic bring-up (fresh boot) + today's CommandTree-mimic milestone playlist.
- Simpler, robust boot sequencing: poll 'serverRunning'/'booting' (no doWhenBooted), so it proceeds
  even if the server is already booting. Extra step logs to confirm progression.

Style
- tilde vars at top-level; var-first in every function/closure; lowercase method names; no server.sync;
- server ops inside Server.default.bind; GUI ops on AppClock; JITLib operator exactly "<<>";
- generated audio only (no SoundIn); sinks/processors read from \in.ar(2).
*/

(
var log, step, pollUntil, freshBoot, makeGui, makeMpb, ensureSources;
var settleBeforeMeters, loadAdapterRobust, installInlineAdapter;
var waitOnMpbReadyThen, enableMetersAfterReady, runMilestone, runAll;
var gapSeconds, meterDelaySec;

// ---------- capture this script's directory once (for absolute loads) ----------
~scriptDir = ~scriptDir ?? {
    var pathString, dirString;
    pathString = thisProcess.nowExecutingPath;
    dirString = if(pathString.notNil) { PathName(pathString).pathOnly } { thisProcess.cwd };
    dirString
};
("[DEBUG] scriptDir=" ++ ~scriptDir).postln;

// ---------- small logger ----------
log = { arg messageString;
    var lineText;
    lineText = "[RUN] " ++ messageString;
    lineText.postln;
};

// terse step tagger
step = { arg tag; ("[STEP] " ++ tag).postln };

// ---------- generic AppClock poll (no server.sync) ----------
pollUntil = { arg conditionFunc, everySeconds = 0.05, onOkFunc;
    var tickFunc, secondsLocal, condFuncLocal, onOkLocal;
    condFuncLocal = conditionFunc;
    secondsLocal = everySeconds ? 0.05;
    onOkLocal = onOkFunc ? { nil };
    tickFunc = {
        var okNow;
        okNow = condFuncLocal.value;
        if(okNow) { onOkLocal.value; nil } { AppClock.sched(secondsLocal, tickFunc) }
    };
    AppClock.sched(0, tickFunc);
};

// ---------- reset globals before start ----------
~gui = nil;
~mpb = nil;

// ---------- 0) Fresh boot (polling): quit -> wait down -> boot -> wait up -> initTree ----------
freshBoot = {
    var serverRef, waitDown, waitUp, doInitTree;
    serverRef = Server.default;

    doInitTree = {
        var ignore;
        ignore = nil;
        Server.default.bind({
            serverRef.initTree;
            serverRef.defaultGroup.freeAll;
        });
        MagicDisplay.setMeterChannels(2); // compile-time meter defs to 2ch
        log.("server tree inited; meter defs set to 2ch");
    };

    waitUp = {
        var cond;
        cond = { serverRef.serverRunning };
        pollUntil.value(cond, 0.05, {
            doInitTree.value;
        });
    };

    waitDown = {
        var cond;
        cond = { serverRef.serverRunning.not and: { serverRef.booting.not } };
        pollUntil.value(cond, 0.05, {
            log.("fresh boot: starting server…");
            serverRef.boot;
            waitUp.value;
        });
    };

    if(serverRef.serverRunning or: { serverRef.booting }) {
        log.("fresh boot: quitting current server…");
        serverRef.quit;
        // give the server a moment to start going down, then poll until fully down
        AppClock.sched(0.05, { waitDown.value; nil });
    }{
        log.("fresh boot: starting server…");
        serverRef.boot;
        waitUp.value;
    };
};

// ---------- 1) GUI: close old MagicDisplayGUI and create a fresh one ----------
makeGui = {
    var closeOldFunc;
    closeOldFunc = {
        var windowsList;
        windowsList = Window.allWindows.select({ arg w;
            var nameString, isMagic;
            nameString = w.tryPerform(\name);
            isMagic = nameString.notNil and: { nameString.asString.beginsWith("MagicDisplayGUI") };
            isMagic
        });
        windowsList.do({ arg w; w.close });
        log.("closed any existing MagicDisplayGUI windows");
    };
    AppClock.sched(0, {
        closeOldFunc.value;
        ~gui = MagicDisplayGUI.new;
        nil
    });
};

// ---------- 2) MPB: create AFTER GUI exists ----------
makeMpb = {
    pollUntil.value({ ~gui.notNil }, 0.05, {
        AppClock.sched(0, {
            ~mpb = MagicPedalboardNew.new(~gui);
            log.("MagicPedalboardNew created");
            nil
        });
    });
};

// ---------- 3) Sources (generated only) ----------
ensureSources = {
    Server.default.bind({
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig, seq, freqSig, envAmp, panPos, outSig;
                trig    = Impulse.kr(3.2);
                seq     = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                freqSig = Demand.kr(trig, 0, seq);
                envAmp  = Decay2.kr(trig, 0.01, 0.35);
                panPos  = ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
                outSig  = Pan2.ar(SinOsc.ar(freqSig) * envAmp * 0.25, panPos);
                outSig
            });
        };
        Ndef(\testmelody).ar(2);
        Ndef(\ts0, { Silent.ar(2) });
        Ndef(\ts0).ar(2);
    });
    log.("sources ensured (\\testmelody stereo; \\ts0 silent stereo)");
};

// ---------- 4) Settle BEFORE meters: Option A + pin sinks (NO setSourcesBoth here) ----------
settleBeforeMeters = {
    pollUntil.value({ ~mpb.notNil }, 0.05, {
        ~mpb.playCurrent;                         // deterministic CURRENT audible
        ~mpb.enforceExclusiveCurrentOptionA(0.1); // NEXT silent at source

        Server.default.bind({
            Ndef(\chainA).mold(2, \audio);
            Ndef(\chainB).mold(2, \audio);
        });

        ~mpb.printChains;
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    });
};

// ---------- 5) Adapter: absolute-load robustly; fallback to inline mini-adapter ----------
installInlineAdapter = {
    if(~ct_applyOSCPathToMPB.isNil) {
        ~ct_applyOSCPathToMPB = { arg pathString, mpb, gui;
            var tokens, normalized, verbLower, argsList, onOffStr, procSym, idxA, idxB, lastTail;
            tokens = pathString.asString.split($/).reject({ arg t; t.isEmpty }).collect(_.asString);
            normalized = if(tokens.size > 0 and: { tokens[0] == "commands" }) { tokens.copyRange(1, tokens.size - 1) } { tokens };
            verbLower = (normalized.size > 0).if({ normalized[0].toLower }, { "" });
            argsList  = (normalized.size > 1).if({ normalized.copyRange(1, normalized.size - 1) }, { [] });

            switch(verbLower,
                "add",      { if(argsList.size >= 1) { procSym = argsList[0].asSymbol; mpb.add(procSym) } },
                "bypass",   {
                    if(argsList.size >= 2) {
                        procSym  = argsList[0].asSymbol;
                        onOffStr = argsList[1].toLower;
                        onOffStr = (["on","off","true","false","1","0"].includes(onOffStr)).if({
                            if((onOffStr=="true") or: { onOffStr=="1" }) { "on" } { onOffStr }
                        }, { "on" });
                        mpb.bypass(procSym, onOffStr=="on");
                    };
                },
                "removeat", { if(argsList.size >= 1) { mpb.removeAt(argsList[0].asInteger) } },
                "swap",     { if(argsList.size >= 2) { idxA=argsList[0].asInteger; idxB=argsList[1].asInteger; mpb.swap(idxA, idxB) } },
                "setsource",{ if(argsList.size >= 1) { mpb.setSource(argsList[0].asSymbol) } },
                "switch",   {
                    lastTail = mpb.effectiveNext.last;
                    if(lastTail == \ts0) { mpb.setSource(\testmelody) }; // guard
                    mpb.switchChain(0.12);
                },
                { /* ignore unknown */ }
            );
        };
        log.("inline mini-adapter installed (fallback)");
    };
};

loadAdapterRobust = {
    var adapterFileLower, adapterFileCamel, existsLower, existsCamel;
    if(~ct_applyOSCPathToMPB.notNil) {
        log.("adapter already present");
        ^this;
    };
    adapterFileLower = (~scriptDir +/+ "adapter_commandtree_to_magicpedalboard.scd").standardizePath;
    adapterFileCamel = (~scriptDir +/+ "adapter_CommandTree_to_MagicPedalboard.scd").standardizePath;
    existsLower = File.exists(adapterFileLower);
    existsCamel = File.exists(adapterFileCamel);

    if(existsLower) {
        adapterFileLower.load; log.("adapter loaded: " ++ adapterFileLower);
    }{
        if(existsCamel) {
            adapterFileCamel.load; log.("adapter loaded: " ++ adapterFileCamel);
        }{
            log.("adapter file not found near script; installing fallback");
            installInlineAdapter.value;
        };
    };
};

// ---------- 6) Readiness gate only after ~mpb exists ----------
waitOnMpbReadyThen = { arg onReadyFunc;
    var onOkLocal;
    onOkLocal = onReadyFunc ? { nil };
    pollUntil.value({ ~mpb.notNil }, 0.05, {
        ~mpb.waitUntilReady(2.5, 0.05, {
            ("[PLAY] A=% B=%"
                .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
            onOkLocal.value;
        });
    });
};

// ---------- 7) Re-enforce Option A and enable meters AFTER readiness (with a short delay) ----------
enableMetersAfterReady = {
    var postDelay;
    postDelay = meterDelaySec ? 0.25; // small settle delay

    AppClock.sched(postDelay, {
        ~mpb.enforceExclusiveCurrentOptionA(0.1); // re-check exclusivity before meters

        if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
            ~gui.enableMeters(false);
            ~gui.enableMeters(true);
            log.("meters enabled after readiness");
        };
        ("[CHECK] Ndef chain channels -> A:% , B:%"
            .format(Ndef(\chainA).tryPerform(\numChannels), Ndef(\chainB).tryPerform(\numChannels))).postln;
        nil
    });
};

// ---------- 8) Milestone playlist (single prime sets sources) ----------
runMilestone = {
    var gapLocal, applyPathFunc, primeFunc, playlistArray, stepIndex, stepCount, stepFunc;
    gapLocal = 0.60;

    applyPathFunc = { arg pathString;
        var lineText;
        lineText = "[TOKENS] apply -> " ++ pathString;
        lineText.postln;
        ~ct_applyOSCPathToMPB.(pathString, ~mpb, ~gui);
    };

    primeFunc = {
        ~mpb.setSourcesBoth(\testmelody);     // single place we set both tails today
        ~mpb.enforceExclusiveCurrentOptionA(0.1);
        ~mpb.printChains;
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    };

    playlistArray = [
        "/add/delay",
        "/switch",
        "/bypass/delay/on",
        "/bypass/delay/off",
        "/switch"
    ];
    stepIndex = 0;
    stepCount = playlistArray.size;

    stepFunc = {
        var doneNow;
        doneNow = (stepIndex >= stepCount);
        if(doneNow) {
            AppClock.sched(0.9, {
                ("[PLAY] A=% B=%"
                    .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
                ~mpb.printChains;
                nil
            });
            ^nil
        };
        applyPathFunc.value(playlistArray[stepIndex]);
        stepIndex = stepIndex + 1;
        AppClock.sched(gapLocal, stepFunc);
    };

    primeFunc.value;
    AppClock.sched(gapLocal, stepFunc);
};

// ---------- 9) Orchestrate strictly in order ----------
runAll = {
    var proceedAfterBoot;
    proceedAfterBoot = {
        makeGui.value;           step.("GUI");
        makeMpb.value;           step.("MPB create");
        ensureSources.value;     step.("sources");
        settleBeforeMeters.value;step.("settle-before-meters");
        loadAdapterRobust.value; step.("adapter");
        waitOnMpbReadyThen.value({
            enableMetersAfterReady.value; step.("meters");
            runMilestone.value;          step.("playlist");
        });
    };
    log.("orchestration start");
    freshBoot.value;             step.("boot-in-progress");
    // Continue once server is really running and tree initialized
    pollUntil.value({ Server.default.serverRunning }, 0.05, {
        // a tiny guard in case initTree hasn't run yet
        AppClock.sched(0.10, { proceedAfterBoot.value; nil });
    });
};

gapSeconds    = 0.60;
meterDelaySec = 0.25;

// fire
runAll.value;
)
