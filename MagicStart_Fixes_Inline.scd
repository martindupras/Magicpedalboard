// MagicStart_Prelude_SelfRun
// v0.4.9
// 2025-09-17 14:48 BST (MD)
//
// Purpose:
// - Self-running top-of-file prelude to start from a known-good state.
// - Avoid quit/boot races by reusing a healthy server + init tree + clear default group.
// - Define busMeterA / busMeterB with a COMPILE-TIME channel count to prevent In.ar errors.
// - Mix meters to mono internally to avoid language-level max comparisons on UGens.
// Style:
// - tilde vars only, var-first inside functions, no server.sync,
//   Server.default.bind for server ops, GUI-safe (AppClock), your SC coding rules respected.

(
var numChannelsConst;

// --- Decide a compile-time channel count for the meter synths ----------------
// If you already set ~defaultNumChannels elsewhere (Integer > 0), we use it; otherwise fall back to 2.
numChannelsConst = (
    ~defaultNumChannels.isKindOf(Integer) and: { ~defaultNumChannels > 0 }
).if({ ~defaultNumChannels }, { 2 });

// --- Helpers -----------------------------------------------------------------
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
    var needA, needB;
    needA = SynthDescLib.global.at(\busMeterA).isNil;
    needB = SynthDescLib.global.at(\busMeterB).isNil;

    if (needA or: { needB }) {
        ("[START] (re)defining meter synths with numChannelsConst=" ++ numChannelsConst).postln;

        // Capture numChannelsConst at SynthDef build time (literal inside the UGen graph).
        Server.default.bind({
            SynthDef(\busMeterA, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                // choose an index: \bus if >=0 else \in (control-rate comparator is fine for Select)
                useBus = Select.kr(bus >= 0, [in, bus]);
                // read exactly numChannelsConst channels (compile-time integer)
                sig    = In.ar(useBus, numChannelsConst);
                // mix to mono to avoid language-level max across arrays of UGens
                mono   = Mix(sig);
                // meters
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterA", [rms, peak]);
            }).add;

            SynthDef(\busMeterB, { |bus = -1, in = 0, rate = 15, attack = 0.01, release = 0.3|
                var useBus, sig, mono, trig, rms, peak;
                useBus = Select.kr(bus >= 0, [in, bus]);
                sig    = In.ar(useBus, numChannelsConst);
                mono   = Mix(sig);
                rms    = Amplitude.kr(mono, attack, release);
                peak   = PeakFollower.kr(mono, release);
                trig   = Impulse.kr(rate);
                SendReply.kr(trig, "/meterB", [rms, peak]);
            }).add;
        });
    };
};

// Optional: quick chain channel sanity check (posted if chains already exist)
~checkChainChannels = {
    var a, b;
    a = Ndef(\chainA).tryPerform(\numChannels);
    b = Ndef(\chainB).tryPerform(\numChannels);
    if(a.notNil or: { b.notNil }) {
        "[CHECK] Ndef chain channels → A:% , B:%".format(a, b).postln;
    };
};

// --- Execute preflight now (self-running) ------------------------------------
~closeMagicDisplayGUIWindows.value;
~ensureServerReady.value;
~ensureMeterDefs.value;
~checkChainChannels.value;   // harmless if chains don't exist yet
"[READY] MagicStart prelude complete — continue with your runner code below.".postln;
)
