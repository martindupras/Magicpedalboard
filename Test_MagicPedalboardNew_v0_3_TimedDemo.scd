// Test_MagicPedalboardNew_v0_3_TimedDemo.scd
// MD 20250911-1647

/* Test_MagicPedalboardNew_v0_3_TimedDemo.scd
   Comprehensive, narrated demo with countdowns for MagicPedalboardNew v0.1.3.
   It describes what will happen, counts down, performs the action, and prints
   the expected audible result.
*/

(
// ─────────────────────────────────────────────────────────────────
// 0) Simple sources and processors (stereo; processors read \in)
// ─────────────────────────────────────────────────────────────────
Ndef(\ts0, { Silent.ar(2) });                    // silent (baseline)
Ndef(\tsDust, { Dust.ar(2000) ! 2 });            // noisy bursts
Ndef(\tsSaw, { Saw.ar(200, 0.12) ! 2 });         // bright saw
Ndef(\tsSine, { SinOsc.ar(333, 0, 0.2) ! 2 });   // steady sine
// processors
Ndef(\tremolo, { |rate = 4, depth = 0.6|
    var inputSignal, mod;
    inputSignal = \in.ar(2);
    mod = SinOsc.kr(rate).range(1 - depth, 1);
    inputSignal * mod
});

Ndef(\lofi, { |bits = 6, rate = 6000|
    var inputSignal;
    inputSignal = \in.ar(2);
    // crude bitcrush + SRR
    Decimator.ar(inputSignal, rate, bits)
});

Ndef(\atten, { |gain = 0.6|
    var inputSignal;
    inputSignal = \in.ar(2) * gain;
    inputSignal
});

// ─────────────────────────────────────────────────────────────────
// 1) Instantiate pedalboard
// ─────────────────────────────────────────────────────────────────
m = MagicPedalboardNew.new;

// Utilities for narration
~say = { |text|
    var msg;
    msg = text.asString;
    msg.postln;
};

~countdown = { |seconds = 3|
    var remaining;
    remaining = seconds;
    while { remaining > 0 } {
        (remaining.asString ++ "...").postln;
        1.wait;
        remaining = remaining - 1;
    };
    "Now.".postln;
};

// Helper to display chains compactly
~show = {
    "— Chains —".postln;
    m.printChains;
    "".postln;
};
)

// ─────────────────────────────────────────────────────────────────
// 2) Narrated sequence (Routine)
//    Feel free to tweak the waits if you want faster/slower pacing.
// ─────────────────────────────────────────────────────────────────
(
Routine({
    var waitShort, waitMed;
    waitShort = 2.0;
    waitMed = 6.0;

    // A) Start silent on current (A)
    ~say.("Starting with a silent chain on current: [\\chainA, \\ts0]. Starting in");
    ~countdown.(3);
    m.setSourceCurrent(\ts0);            // ensure silent on current chain
    m.playCurrent;
    ~show.();
    ~say.("You should hear nothing.");
    waitMed.wait;

    // B) Swap source to Dust on current
    ~say.("Change current source to Dust(2000). Starting in");
    ~countdown.(3);
    m.setSourceCurrent(\tsDust);
    ~show.();
    ~say.("You should hear irregular noise bursts in stereo.");
    waitMed.wait;

    // C) Prepare NEXT chain (B) with Saw, add tremolo near source, and switch
    ~say.("Prepare NEXT: source = Saw, add a tremolo (\\tremolo) before the source, then switch.");
    ~say.("Setting NEXT source to Saw in");
    ~countdown.(2);
    m.setSource(\tsSaw);

    ~say.("Adding tremolo on NEXT just before the source in");
    ~countdown.(2);
    m.add(\tremolo);     // inserts just before source
    ~show.();

    ~say.("Switch to NEXT (so tremolo+Saw becomes current). Starting in");
    ~countdown.(3);
    m.switchChain;
    ~show.();
    ~say.("You should hear a saw tone with amplitude modulation (tremolo).");
    waitMed.wait;

    // D) Bypass tremolo on CURRENT, then un-bypass
    ~say.("Bypass the tremolo on CURRENT in");
    ~countdown.(2);
    // tremolo is likely at index 1 (after sink), but we use name to be explicit:
    m.bypassCurrent(\tremolo, true);
    ~show.();
    ~say.("You should hear plain Saw (no tremolo).");
    waitShort.wait;

    ~say.("Un-bypass tremolo on CURRENT in");
    ~countdown.(2);
    m.bypassCurrent(\tremolo, false);
    ~show.();
    ~say.("Tremolo should be back.");
    waitMed.wait;

    // E) Prepare NEXT: add lofi and atten near sink, then swap positions
    ~say.("Prepare NEXT: add \\lofi near the sink (index 1) and \\atten after it, then swap them.");
    ~say.("Adding \\lofi at index 1 in");
    ~countdown.(2);
    m.addAt(\lofi, 1);
    ~show.();
    waitShort.wait;

    ~say.("Adding \\atten at index 2 in");
    ~countdown.(2);
    m.addAt(\atten, 2);
    ~show.();
    waitShort.wait;

    ~say.("Swap NEXT indices 1 and 2 in");
    ~countdown.(2);
    m.swap(1, 2);
    ~show.();
    ~say.("NEXT is staged with [sink, atten, lofi, source].");
    waitMed.wait;

    // F) Switch to NEXT (A becomes next)
    ~say.("Switch to NEXT so atten+lofi+Saw becomes CURRENT. Starting in");
    ~countdown.(3);
    m.switchChain;
    ~show.();
    ~say.("You should hear Saw going through attenuation and a bitcrush/decimate.");
    waitMed.wait;

    // G) Remove a processor on NEXT and clear
    ~say.("On NEXT, remove the processor at index 1 (nearest the sink), then clear the chain.");
    ~say.("Removing at index 1 on NEXT in");
    ~countdown.(2);
    m.removeAt(1);
    ~show.();
    waitShort.wait;

    ~say.("Clear NEXT back to [sink, source] in");
    ~countdown.(2);
    m.clearChain;
    ~show.();
    waitShort.wait;

    // H) Change NEXT source to Sine and switch
    ~say.("Set NEXT source to Sine and then switch. Starting in");
    ~countdown.(3);
    m.setSource(\tsSine);
    m.switchChain;
    ~show.();
    ~say.("You should now hear a steady sine tone.");
    waitMed.wait;

    // I) Demonstrate bypassAt on CURRENT (no-op if only [sink, source])
    ~say.("Demonstrate bypassAt on CURRENT (if there are no processors, this does nothing). In");
    ~countdown.(2);
    m.bypassAtCurrent(1, true);  // will clamp but have no effect if only [sink, source]
    ~show.();
    waitShort.wait;

    // J) Wrap up
    ~say.("Demo complete. Stopping current chain in");
    ~countdown.(3);
    m.stopCurrent;
    ~say.("All done.");
}).play;
)
