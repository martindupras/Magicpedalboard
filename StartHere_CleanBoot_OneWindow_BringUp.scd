// StartHere_CleanBoot_OneWindow_BringUp.scd
// v0.5.9
// MD 20250917-1616
//
// Purpose:
//   Known-state bring-up with one MagicDisplayGUI window, CURRENT=\testmelody
//   audible, NEXT silent (Option A), meters on, and verify A=true B=false.
//   Handles the case where GUI/MPB init quits and reboots the server mid-sequence
//   by detecting the reboot, waiting for it, and re-publishing the graph afterward.
//
// Style:
//   - tilde vars only
//   - var-first in every block
//   - lowercase names
//   - no server.sync
//   - server ops inside Server.default.bind
//   - GUI via AppClock (single window named “MagicDisplayGUI…”)

(
var log, s, numChConst,
    closeGuiWindows, freshBoot, ensureMeterDefs, checkChainChannels,
    clearOldNdefs, buildAudio, makeGuiAndMpb,
    waitForServerDownThenUp, baselinePlayWithRetry, metersOn, verify,
    runSequence;

log = { arg msg; ("[START] " ++ msg).postln };
s   = Server.default;

// channel constant everywhere (respects your global default if set)
numChConst = (
    ~defaultNumChannels.isKindOf(Integer) and: { ~defaultNumChannels > 0 }
).if({ ~defaultNumChannels }, { 2 });

// 1) Close any MagicDisplayGUI windows (singleton)
closeGuiWindows = {
    var wins;
    wins = Window.allWindows
        .select({ arg w; (w.name ? "").asString.beginsWith("MagicDisplayGUI") });
    wins.do(_.close);
    log.("closed any existing MagicDisplayGUI windows");
};

// 2) Force a FRESH server (quit if running, then boot), then clean the tree
freshBoot = {
    var t0, timeout, keepWait;
    timeout = 5.0;

    if(s.serverRunning) {
        log.("server running → quitting for clean boot");
        s.quit;
        t0 = Main.elapsedTime;
        keepWait = true;
        while({ s.serverRunning and: { keepWait } }, {
            0.05.wait;
            if((Main.elapsedTime - t0) > timeout) {
                "[WARN] timeout waiting for server to quit".postln;
                keepWait = false;
            };
        });
    };

    log.("booting server…");
    s.boot;
    s.waitForBoot;

    Server.default.bind({
        s.initTree;
        s.defaultGroup.freeAll;
    });
    log.("tree inited + default group cleared");
};

// 3) Ensure meter SynthDefs exist (compile-time channel count; mono mix inside)
ensureMeterDefs = {
    var needA, needB, n;
    n = numChConst;
    needA = SynthDescLib.global.at(\busMeterA).isNil;
    needB = SynthDescLib.global.at(\busMeterB).isNil;

    if(needA or: { needB }) {
        ("[START] (re)defining meter synths with numChConst=" ++ n).postln;

        Server.default.bind({
            SynthDef(\busMeterA, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                useBus = Select.kr(bus >= 0, [in, bus]);  // prefer \bus if set; else \in
                sig    = In.ar(useBus, n);                // compile-time literal
                mono   = Mix(sig);                        // stable single-channel level
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterA", [rms, peak]);
            }).add;

            SynthDef(\busMeterB, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                useBus = Select.kr(bus >= 0, [in, bus]);
                sig    = In.ar(useBus, n);
                mono   = Mix(sig);
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterB", [rms, peak]);
            }).add;
        });
    };
};

// 4) Optional: print A/B channel counts if chains already exist
checkChainChannels = {
    var a, b;
    a = Ndef(\chainA).tryPerform(\numChannels);
    b = Ndef(\chainB).tryPerform(\numChannels);
    if(a.notNil or: { b.notNil }) {
        "[CHECK] Ndef chain channels → A:% , B:%".format(a, b).postln;
    };
};

// 5) Clear any previous proxies to avoid channel wrapping warnings
clearOldNdefs = {
    Server.default.bind({
        if(Ndef(\chainA).notNil) { Ndef(\chainA).clear(0) };
        if(Ndef(\chainB).notNil) { Ndef(\chainB).clear(0) };
        if(Ndef(\ts0).notNil)    { Ndef(\ts0).clear(0) };
        if(Ndef(\testmelody).notNil) { Ndef(\testmelody).clear(0) };
    });
};


// 6) Build sinks and sources (server ops)
buildAudio = {
    Server.default.bind({
        // Sinks: read \in.ar(defaultNumChannels)
        Ndef(\chainA, { \in.ar(numChConst) }); Ndef(\chainA).ar(numChConst);
        Ndef(\chainB, { \in.ar(numChConst) }); Ndef(\chainB).ar(numChConst);

        // Sources: NEXT-safe silent + generated test melody
        Ndef(\ts0, { Silent.ar(numChConst) }); Ndef(\ts0).ar(numChConst);

        Ndef(\testmelody, {
            var trig, seq, f, env, tone, pan;
            trig = Impulse.kr(3.2);
            seq  = Dseq([220, 277.18, 329.63, 392, 329.63, 277.18, 246.94], inf);
            f    = Demand.kr(trig, 0, seq);
            env  = Decay2.kr(trig, 0.01, 0.35);
            tone = SinOsc.ar(f) * env * 0.25;
            pan  = ToggleFF.kr(trig).linlin(0, 1, -0.6, 0.6);
            Pan2.ar(tone, pan)
        });
        Ndef(\testmelody).ar(numChConst);
    });
    log.("sinks + sources defined");
};

// 7) Create GUI + MPB (meters OFF initially). (We call this inside AppClock Routine)
makeGuiAndMpb = {
    ~gui = MagicDisplayGUI.new;
    ~mpb = MagicPedalboardNew.new(~gui);
    if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(false) };
    if(~pedalboard.isNil and: { ~mpb.notNil }) { ~pedalboard = ~mpb };
    log.("GUI + MPB created (meters off)");
};

// 8) Detect a **server restart** after MPB creation; wait for it and re-publish graph
waitForServerDownThenUp = {
    var sawDown, t0, timeout, bootKickSent, stableCount, stableNeeded;
    sawDown = false;
    t0 = Main.elapsedTime;
    timeout = 10.0;
    bootKickSent = false;
    stableCount = 0;
    stableNeeded = 5; // 5 * 0.2s = 1.0s of stable running

    // Observe the server for up to 10 seconds; if it goes down, wait until it comes back
    while({
        (Main.elapsedTime - t0) < timeout and: { stableCount < stableNeeded }
    }, {
        0.20.wait;

        if(s.serverRunning.not) {
            sawDown = true;
            stableCount = 0;

            // If it doesn't auto-boot within ~1s, kick a boot
            if((Main.elapsedTime - t0) > 1.0 and: { bootKickSent.not }) {
                "WARNING: server not running → booting server…".postln;
                s.boot;
                bootKickSent = true;
            };
        }{
            // server is running now
            stableCount = stableCount + 1;
        };
    });

    if(sawDown) {
        // If it was down during the window, make sure it's fully up
        if(s.serverRunning.not) {
            "WARNING: waiting for server to come up…".postln;
            s.boot;  // safe to call even if already booting
            s.waitForBoot;
        }{
            // give it a tiny settle and request notifications (optional but nice)
            0.20.wait;
            s.notify;
        };

        // Re-publish meter defs and audio graph after the reboot
        ensureMeterDefs.value;
        clearOldNdefs.value;
        buildAudio.value;

        // Give MPB a chance to rebuild its server tree if it does so lazily
        0.20.wait;
        if(~mpb.respondsTo(\rebuild)) { ~mpb.rebuild(\current) };
        0.20.wait;
    };
};


// 9) Baseline + robust play with retry (ensures MPB has built server groups)
baselinePlayWithRetry = {
    var attempts, ok;
    attempts = 0;
    ok = false;

    while({ (attempts < 4) and: { ok.not } }, {
        ~mpb.setSourceCurrent(\testmelody);
        ~mpb.playCurrent;
        ~mpb.enforceExclusiveCurrentOptionA(0.1);  // NEXT silenced at source (Option A)

        0.30.wait; // allow bundles to land
        ok = Ndef(\chainA).isPlaying;

        attempts = attempts + 1;
        if(ok) {
            log.("baseline set: CURRENT=\\testmelody (Option A)");
        }{
            ("[RETRY] playCurrent attempt % failed; retrying…".format(attempts)).postln;
            if(~mpb.respondsTo(\rebuild)) { ~mpb.rebuild(\current) };
            0.30.wait;
        };
    });

    if(ok.not) {
        "[WARN] playCurrent did not report Ndef(\\chainA).isPlaying=true after retries".postln;
    };
};

// 10) Meters ON (ensure defs just-in-time)
metersOn = {
    ensureMeterDefs.value; // idempotent safety
    if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(true) };
    log.("meters enabled");
};

// 11) Verify final state
verify = {
    ~mpb.printChains;
    ("[PLAY] A=% B=%"
        .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;
    checkChainChannels.value;
};

// 11b) Wait for MPB "ready" and then do meters + verify (no fixed sleeps)
waitOnMpbReady = {
    var onReady;
    onReady = {
        // meters on only when sinks are AR and CURRENT is playing
        if(~gui.respondsTo(\enableMeters)) { ~gui.enableMeters(true) };
        ~mpb.printChains;

        ("[PLAY] A=% B=%"
            .format(Ndef(\chainA).isPlaying, Ndef(\chainB).isPlaying)).postln;

        // your existing channel sanity print
        var a = Ndef(\chainA).tryPerform(\numChannels);
        var b = Ndef(\chainB).tryPerform(\numChannels);
        ("[CHECK] Ndef chain channels → A:% , B:%".format(a, b)).postln;
    };

    // use the new class helper; no sleeps here
    ~mpb.waitUntilReady(2.5, 0.05, onReady);
};



// --- Execute clean sequence in one AppClock Routine --------------------------
runSequence = {
    var waitPreGUI, waitAfterMPB;
    waitPreGUI  = 0.05; // small settle between bundles
    waitAfterMPB = 0.15; // short window for GUI-created side effects

    Routine({
        // 0) Hygiene
        closeGuiWindows.value;

        // 1) Fresh boot + clean tree
        freshBoot.value;

        // 2) Predefine meter SynthDefs post-boot (safe re-add)
        // ensureMeterDefs.value;
		MagicDisplay.setMeterChannels(numChConst);

        // 3) Start clean, then build audio graph
        clearOldNdefs.value;
        buildAudio.value;

        // 4) Create GUI + MPB (this may quit the server in its init)
        waitPreGUI.wait;
        makeGuiAndMpb.value;

        // 5) Watch for server going down and coming back; then re-publish defs/graph
        waitAfterMPB.wait;    // allow immediate /quit to show up
        waitForServerDownThenUp.value;
// 6) Baseline + robust play (kept, since it launches CURRENT deterministically)
baselinePlayWithRetry.value;
// 7–8) Wait on a real MPB condition, then meters + verify (no fixed sleeps)
waitOnMpbReady.value;

		//removes in 0.5.9
/*        // 6) Baseline + robust play
        baselinePlayWithRetry.value;

        // 7) Turn meters on
        0.25.wait;
        metersOn.value;

        // 8) Verify
        0.20.wait;
        verify.value;*/
    }).play(AppClock);
};

// Kick off the sequence
runSequence.value;
)
