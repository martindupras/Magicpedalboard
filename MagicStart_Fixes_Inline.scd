// MagicStart_Fixes_Inline v0.4.8 — Stable boot + predefine meter SynthDefs (session helper)
// 2025-09-17 14:35 BST (MD)
//
// Purpose:
// - Start from a known-good state without quitting a healthy server (avoids races).
// - Predefine busMeterA / busMeterB with a COMPILE-TIME channel count (fixes Select/In error).
// - Provide a quick channel-count check for Ndef chains.
// Style: tilde-vars (session scope), var-first inside functions, no server.sync, Server.default.bind, AppClock-safe.

(
~closeMagicDisplayGUIWindows = {
    var windows;
    windows = Window.allWindows.select { |w|
        var name;
        name = w.tryPerform(\name);
        name.notNil and: { name.asString.beginsWith("MagicDisplayGUI") }
    };
    windows.do { |w| w.close };
    "[START] closed any existing MagicDisplayGUI windows".postln;
};

~ensureServerReady = {
    var s;
    s = Server.default;

    if (s.serverRunning) {
        "[START] server already running → reusing".postln;
    } {
        if (s.booting) {
            "[START] server already booting → waiting…".postln;
        } {
            "[START] booting server…".postln;
            s.boot;
        };
        s.waitForBoot;
    };

    Server.default.bind({
        s.initTree;
        s.defaultGroup.freeAll;
    });
    "[START] tree inited + default group cleared".postln;
};

~ensureMeterDefs = {
    var needA, needB, numChannelsConst;
    // Decide a compile-time channel count for the meter synths.
    // If you already set ~defaultNumChannels in your config, we take it; otherwise fall back to 2.
    if (~defaultNumChannels.isKindOf(Integer) and: { ~defaultNumChannels > 0 }) {
        numChannelsConst = ~defaultNumChannels;
    } {
        numChannelsConst = 2;
    };

    needA = SynthDescLib.global.at(\busMeterA).isNil;
    needB = SynthDescLib.global.at(\busMeterB).isNil;

    if (needA or: { needB }) {
        ("[START] (re)defining meter synths with numChannelsConst=" ++ numChannelsConst).postln;

        Server.default.bind({
            SynthDef(\busMeterA, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, trig, rms, peak;
                // Note: numChannelsConst is captured from the outer scope at compile time (integer literal).
                useBus = Select.kr(bus >= 0, [in, bus]); // prefer \bus if set; fallback to \in
                sig    = In.ar(useBus, numChannelsConst);
                rms    = Amplitude.kr(sig, attack, release).maxItem;
                peak   = PeakFollower.kr(sig, release).maxItem;
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterA", [rms, peak]);
            }).add;

            SynthDef(\busMeterB, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, trig, rms, peak;
                useBus = Select.kr(bus >= 0, [in, bus]);
                sig    = In.ar(useBus, numChannelsConst);
                rms    = Amplitude.kr(sig, attack, release).maxItem;
                peak   = PeakFollower.kr(sig, release).maxItem;
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterB", [rms, peak]);
            }).add;
        });
    };
};

~checkChainChannels = {
    var a, b;
    a = Ndef(\chainA).tryPerform(\numChannels);
    b = Ndef(\chainB).tryPerform(\numChannels);
    "[CHECK] Ndef chain channels → A:% , B:%".format(a, b).postln;
};
)

// Run these three in order now:
~closeMagicDisplayGUIWindows.value; // Clean any old GUI windows
~ensureServerReady.value;           // Boot/reuse server + init tree/clear default group
~ensureMeterDefs.value;             // Predefine meter SynthDefs with a compile-time channel count
