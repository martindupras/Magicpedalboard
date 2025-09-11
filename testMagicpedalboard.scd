// testMagicpedalboard.scd
// MD 20250911-1524

// v0.2.2 to test the MagicPedalboard class

// Clear all Ndefs first
Ndef.clear;


// Sources (stereo)
Ndef(\ts0, { Silent.ar(2) });                                // quiet source
Ndef(\ts1, { Dust.ar(2000) ! 2 });                           // noise bursts
Ndef(\ts2, { Saw.ar(200, 0.1) ! 2 });                        // saw
Ndef(\ts3, { SinOsc.ar(333, 0, 0.2) ! 2 });                  // sine
Ndef(\ts4, { Dust.ar(200) ! 2 });                            // sparser bursts
// Processors (named audio input \in)
Ndef(\p1, { var inSig; inSig = \in.ar(2) * 0.5; inSig });
Ndef(\p2, { var inSig; inSig = \in.ar(2) * 0.2; inSig });
Ndef(\p3, { var inSig; inSig = \in.ar(2);       inSig });
Ndef(\p4, { var inSig; inSig = \in.ar(2);       inSig });
Ndef(\p5, { var inSig; inSig = \in.ar(2);       inSig });
Ndef(\p6, { var inSig; inSig = \in.ar(2);       inSig });

// Sink (monitor/output stage)
Ndef(\out, { var inSig; inSig = \in.ar(2); inSig });

// Optional: test source
Ndef(\ts2).play;
Ndef(\ts2).stop;


// Create instance
~mpb = MagicPedalboard.new;

// Add processors to next chain
~mpb.add(\p1);
~mpb.add(\p2);
~mpb.addAt(\p3, 1);

// Swap two processors
~mpb.swap(1, 2);

// Remove one
~mpb.removeAt(1);

// Bypass last inserted
~mpb.bypass;

// Switch to next chain
~mpb.switchChain;

// Clear the new next chain
~mpb.clearChain;

// Rebuild using explicit .set(\in, ...)
~mpb.rebuildExplicit;

// Show help
~mpb.help;

