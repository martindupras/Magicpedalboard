// Test_MagicPedalboardNew_v0_2.scd
// MD 20250911-1639

//  Minimal smoke tests for MagicPedalboardNew (v0.1.2).

(
// 1) Toy sources and processors (stereo; processors have named \in)
Ndef(\ts0, { Silent.ar(2) });                    // silent (default)
Ndef(\ts1, { Dust.ar(2000) ! 2 });               // noisy bursts
Ndef(\ts2, { Saw.ar(200, 0.1) ! 2 });            // saw
Ndef(\ts3, { SinOsc.ar(333, 0, 0.2) ! 2 });      // sine

Ndef(\p1, { var inputSignal; inputSignal = \in.ar(2) * 0.5; inputSignal });
Ndef(\p2, { var inputSignal; inputSignal = \in.ar(2) * 0.2; inputSignal });
Ndef(\p3, { var inputSignal; inputSignal = \in.ar(2); inputSignal });

// 2) Instantiate and play current (A)
m = MagicPedalboardNew.new;

// Make sources audible for both chains
m.setSourceCurrent(\ts2); // current chain (A) plays \ts2
m.setSource(\ts3);        // next chain (B) staged with \ts3

m.printChains.postln;
)

// 3) Build up NEXT chain (B): add processors, bypass, then switch
(
m.add(\p1);                 // insert before source
m.addAt(\p2, 1);            // nearer the sink (index 1)
m.addAt(\p3, 2);

m.printChains;

// Preview bypass on NEXT chain
m.bypassAt(1, true);        // bypass whatever sits at index 1 (in B)
m.printChains;

// Switch to make B current and play it
m.switchChain;
)

// 4) Current-chain bypass tweaks and inspection
(
m.bypassAtCurrent(1, false); // un-bypass that slot on current
m.printChains;
)

// 5) Work on NEXT chain again (now A), swap and clear
(
m.swap(1, 2);
m.printChains;

m.clearChain;
m.printChains;
)

// 6) Stop and re‑play current as a final smoke test
(
m.stopCurrent;
m.playCurrent;
)
