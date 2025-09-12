// Test_MPB_Sanity_NoGUI_v0_13.scd
// MD 20250911-1320

(
// Run everything only after the server is up.
s.waitForBoot({
    var say, countdown, show, sanityPreflight, setCurrent, setNext;
    var m;

    say = { |txt| txt.asString.postln };
    countdown = { |n = 3|
        n.do { |i| ((n - i).asString ++ "...").postln; 1.wait }; "Now.".postln;
    };
    show = {
        "— Chains —".postln;
        m.printChains;
        "".postln;
    };

    // ---- Safe preflight (no s.freeAll), clear any old JITLib state ----
    sanityPreflight = {
        "== Preflight ==".postln;

        // stop + clear any Ndefs lingering from older sessions
        Ndef.all.keysValuesDo { |k, p|
            if(p.isPlaying) { ("[CLEAN] stop " ++ k).postln; p.stop };
            p.clear;
        };

        // clear all ProxySpaces we can see
        if(ProxySpace.respondsTo(\all)) {
            ProxySpace.all.keysValuesDo { |srv, ps|
                if(ps.notNil) { ("[CLEAN] ProxySpace on " ++ srv).postln; ps.clear };
            };
        };

        // ensure server tree is sane
        s.initTree;
        s.defaultGroup.freeAll;

        "== Preflight done ==".postln;
    };

    setCurrent = { |key|
        if(m.respondsTo(\setSourceCurrent)) { m.setSourceCurrent(key) }
        { "ERROR: setSourceCurrent missing".warn };
    };
    setNext = { |key|
        if(m.respondsTo(\setSource)) { m.setSource(key) }
        { "ERROR: setSource missing".warn };
    };

    // ---- Go ----
    sanityPreflight.();

    // Minimal source + processor Ndefs
    Ndef(\ts0,   { Silent.ar(2) });
    Ndef(\tsDust,{ Dust.ar(2000) ! 2 });
    Ndef(\tsSaw, { Saw.ar(200, 0.15) ! 2 });
    Ndef(\tremolo, { |rate = 4, depth = 0.9|
        var x = \in.ar(2); x * SinOsc.kr(rate).range(1 - depth, 1)
    });

    // Pedalboard
    m = MagicPedalboardNew.new;
    m.reset;

    // Hard silent baseline
    setCurrent.(\ts0);
    setNext.(\ts0);
    m.clearChain;         // clear NEXT
    m.switchChain;
    m.clearChain;         // clear previous CURRENT (now NEXT)
    m.switchChain;
    Ndef(\chainA).play(numChannels: 2);
    Ndef(\chainB).stop;

    // ---- Narrative, no pauses, explicit progress logs ----
    say.("A1 begin");
    say.("Starting silent. Starting in"); countdown.(3);
    show.(); say.("A1 end (should be silent)"); 2.wait;

    say.("B1 begin");
    say.("Switch CURRENT to Dust. Starting in"); countdown.(3);
    setCurrent.(\tsDust);
    show.(); say.("B1 end (should hear irregular bursts)"); 2.wait;

    say.("C1 begin");
    say.("Prepare NEXT: Saw + Tremolo. Starting in"); countdown.(2);
    setNext.(\tsSaw);
    m.add(\tremolo);
    show.();
    say.("Switching to NEXT in"); countdown.(3);
    m.switchChain; show.();
    say.("C1 end (should hear saw with tremolo)"); 2.wait;

    say.("D1 begin");
    say.("Bypass tremolo. Starting in"); countdown.(2);
    m.bypassCurrent(\tremolo, true); show.();
    say.("D1 end (plain saw)"); 1.wait;

    say.("D2 begin");
    say.("Un-bypass tremolo. Starting in"); countdown.(2);
    m.bypassCurrent(\tremolo, false); show.();
    say.("D2 end (tremolo returns)"); 2.wait;

    say.("E1 begin");
    say.("Prepare NEXT: add atten@1, lofi@2, swap. Starting in"); countdown.(2);
    m.addAt(\atten, 1); m.addAt(\lofi, 2); m.swap(1, 2); show.();
    say.("Switch to NEXT in"); countdown.(3);
    m.switchChain; show.();
    say.("E1 end (quiet + crushed)"); 2.wait;

    say.("F1 begin");
    say.("On NEXT, removeAt(1), then clear in"); countdown.(2);
    m.removeAt(1); show.(); m.clearChain; show.();
    say.("F1 end"); 1.wait;

    say.("G1 begin");
    say.("Set NEXT to \\ts0 (back to silence) and switch. Starting in"); countdown.(3);
    setNext.(\ts0); m.switchChain; show.();
    say.("G1 end (silent again)"); 2.wait;

    say.("Done. Stopping."); m.stopCurrent;
});
)
