// Test_MagicPedalboardRunner.scd
// v0.2.2
// MD 20250919

/*
Purpose:
- Instantiate MagicPedalboardTestRunner and run full bring-up and acceptance test.
- Ensures ~gui and ~mpb are created if nil.
*/

(
// Ensure GUI and pedalboard exist
~gui = ~gui ?? { MagicDisplayGUI.new };
~mpb = ~mpb ?? { MagicPedalboardNew.new(~gui) };

// Instantiate and run the test
~runner = MagicPedalboardTestRunner.new(~mpb, ~gui);
~runner.bringUp;
~runner.audioReset;
~runner.syncGui;
~runner.runAcceptanceTest;
~runner.verifyAudioState;
~runner.help;
)
