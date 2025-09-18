// StartHere_Milestone_BringUpAndRun.scd
// v0.1.1
// MD 20250918-16:05 BST

/* Purpose
   - End-to-end: clean bring-up (single window, meters) + today's milestone playlist.
   - Fixes race where ~mpb was nil when .waitUntilReady was called.
   - Pins sinks to stereo early and enforces Option A before enabling meters.
   Style
   - tilde vars at top-level; var-first in every function/closure; lowercase methods; no server.sync;
   - server ops in Server.default.bind; GUI ops on AppClock; JITLib operator exactly "<<>";
   - generated audio only; sinks/processors read from \in.ar(2).
*/

(
var log, pollUntil, bootAndInit, makeGui, makeMpb, pinSinksAndOptionA, ensureSources, loadAdapter;
var waitOnMpbReady, enableMetersSafe, runMilestone, runAll, gapSeconds;

// ---- logger
log = { arg s; ("[RUN] " ++ s).postln };

// ---- small AppClock poll helper
pollUntil = { arg condFunc, everySeconds = 0.05, onOkFunc;
    var tick;
    tick = {
        var ok;
        ok = condFunc.value;
        if(ok) { onOkFunc.value; nil } { AppClock.sched(everySeconds, tick) }
    };
    AppClock.sched(0, tick);
};

// ---- 1) Boot server if needed, init tree, set meter channel defs
bootAndInit = {
    var s, doInit;
    s = Server.default;
    doInit = {
        Server.default.bind({
            s.initTree;
            s.defaultGroup.freeAll;
        });
        // define meter SynthDefs (compile-time channel count)
        MagicDisplay.setMeterChannels(2);
        log.("server tree inited; meter defs set to 2ch");
    };
    if(s.serverRunning.not) {
        log.("booting server…");
        s.boot;
        // wait until serverRunning without server.sync
        pollUntil.value({ Server.default.serverRunning }, 0.05, { doInit.value });
    }{
        log.("server already running; reusing");
        doInit.value;
    };
};

// ---- 2) Close old GUI windows, then make a fresh GUI (AppClock)
makeGui = {
    var closeOld;
    closeOld = {
        var wins;
        wins = Window.allWindows.select({ arg w;
            var nm; nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        wins.do({ arg w; w.close });
        log.("closed any existing MagicDisplayGUI windows");
    };
    AppClock.sched(0, {
        closeOld.value;
        ~gui = MagicDisplayGUI.new;
        nil
    });
};

// ---- 3) Make the pedalboard AFTER GUI exists (AppClock chain)
makeMpb = {
    pollUntil.value({ ~gui.notNil }, 0.05, {
        AppClock.sched(0, {
            ~mpb = MagicPedalboardNew.new(~gui);
            log.("MagicPedalboardNew created");
            nil
        });
    });
};

// ---- 4) Ensure generated sources only (no SoundIn)
ensureSources = {
    Server.default.bind({
        if(Ndef(\testmelody).source.isNil) {
            Ndef(\testmelody, {
                var trig, seq, f, env, pan;
                trig = Impulse.kr(3.2);
                seq  = Dseq([220,277.18,329.63,392,329.63,277.18,246.94], inf);
                f    = Demand.kr(trig, 0, seq);
                env  = Decay2.kr(trig, 0.01, 0.35);
                pan  = ToggleFF.kr(trig).linlin(0,1,-0.6,0.6);
                Pan2.ar(SinOsc.ar(f) * env * 0.25, pan)
            });
        };
        Ndef(\testmelody).ar(2);
        Ndef(\ts0, { Silent.ar(2) }); Ndef(\ts0).ar(2);
    });
    log.("sources ensured (\testmelody stereo; \ts0 silent stereo)");
};

// ---- 5) Pin sinks to stereo and enforce Option A BEFORE meters try to attach
pinSinksAndOptionA = {
    pollUntil.value({ ~mpb.notNil }, 0.05, {
        // enforce class-level Option A which also molds sinks
        ~mpb.enforceExclusiveCurrentOptionA(0.1);
        // extra belt-and-braces: pin explicitly
        Server.default.bind({
            Ndef(\chainA).mold(2, \audio);
            Ndef(\chainB).mold(2, \audio);
        });
        log.("sinks pinned to 2ch; Option A enforced");
        // quick visibility
        ~mpb.printChains;
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    });
};

// ---- 6) Adapter (idempotent)
loadAdapter = {
    if(~ct_applyOSCPathToMPB.isNil) {
        "adapter_commandtree_to_magicpedalboard.scd".loadRelative;
        log.("adapter loaded");
    }{
        log.("adapter already present");
    };
};

// ---- 7) Wait on MPB readiness ONLY when ~mpb exists
waitOnMpbReady = { arg onReadyFunc;
    var onReadyLocal;
    onReadyLocal = onReadyFunc ? { nil };
    pollUntil.value({ ~mpb.notNil }, 0.05, {
        ~mpb.waitUntilReady(2.5, 0.05, {
            // meters later; just a status now
            ("[PLAY] A=% B=%"
                .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
            onReadyLocal.value;
        });
    });
};

// ---- 8) Enable meters safely AFTER readiness
enableMetersSafe = {
    if(~gui.notNil and: { ~gui.respondsTo(\enableMeters) }) {
        ~gui.enableMeters(false);
        ~gui.enableMeters(true);
        log.("meters enabled after readiness");
    };
    // chain sanity line expected by your prompt
    ("[CHECK] Ndef chain channels -> A:% , B:%"
        .format(Ndef(\chainA).tryPerform(\numChannels), Ndef(\chainB).tryPerform(\numChannels))).postln;
};

// ---- 9) Milestone playlist via adapter
runMilestone = {
    var applyPath, prime, playlist, idx, total, step, gap;

    gap = gapSeconds ? 0.60;
    applyPath = { arg p;
        ("[TOKENS] apply -> " ++ p).postln;
        ~ct_applyOSCPathToMPB.(p, ~mpb, ~gui);
    };

    prime = {
        ~mpb.setSourcesBoth(\testmelody); // today both end with testmelody
        ~mpb.enforceExclusiveCurrentOptionA(0.1);
        ~mpb.printChains;
        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    };

    playlist = [
        "/add/delay",
        "/switch",
        "/bypass/delay/on",
        "/bypass/delay/off",
        "/switch"
    ];
    idx = 0; total = playlist.size;

    step = {
        if(idx >= total) {
            AppClock.sched(0.9, {
                ("[PLAY] A=% B=%"
                    .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
                ~mpb.printChains;
                nil
            });
            ^nil
        };
        applyPath.value(playlist[idx]);
        idx = idx + 1;
        AppClock.sched(gap, step);
    };

    prime.value;
    AppClock.sched(gap, step);
};

// ---- 10) Orchestrate
runAll = {
    bootAndInit.value;
    // wait for server to be running before touching GUI/MPB
    pollUntil.value({ Server.default.serverRunning }, 0.05, {
        makeGui.value;
        makeMpb.value;
        ensureSources.value;
        pinSinksAndOptionA.value;   // before meters
        loadAdapter.value;
        waitOnMpbReady.value({
            enableMetersSafe.value;
            runMilestone.value;
        });
    });
};

gapSeconds = 0.60;
runAll.value;
)
