// testAfterFix.scd
// v0.1
// MD 20250916

// PRE-RUN REQUIRED:
// 1. Recompile class library after editing MagicPedalboardNew.sc
// 2. Run MagicPedalboardNew.scd (if you have a setup/init script)
// 3. Run MagicDisplayGUI.scd to launch GUI
// 4. Run adapter_commandtree_to_magicpedalboard.scd v0.3

(
// Test sequence: add → switch → bypass → switch
~adapter.applyQueue([
    ["commands/add", "delay"],
    ["commands/switch", "chainB"],
    ["commands/bypass", "delay", true],
    ["commands/bypass", "delay", false],
    ["commands/switch", "chainA"]
]);

// Confirm:
// - Audio is audible at each step
// - GUI columns match chain state
// - chainB is stopped unless switching
)
