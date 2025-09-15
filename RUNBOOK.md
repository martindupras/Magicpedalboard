After reboot (3 steps)
Evaluate these files (in order):

Runner_MagicDisplayGUI.scd
Scenarios_MagicDisplayGUI_Fast.scd
(Optional: Utils_MagicDisplayGUI_Checks.scd)
Run the one-button command:




SuperCollider
~md_bootProbeScenario.();

Expect success:

Exactly 1 window titled with MagicDisplayGUI…
A red PROBE FRAME rectangle at top-left
Scenario 1 (fast) updates step-by-step
Handy checks



SuperCollider
~md_checkWindows.();   // should print 1 window + its title
~md_checkEnv.();       // optional environment snapshot

Troubleshooting (minimal)



SuperCollider
// If runner says "already running" or seems stuck
~md_runnerUnlock.();
~md_forceCreateWindow.();
~md_bootProbeScenario.();

// If no window appears
~md_checkWindows.();
~md_appclock_ping.(); // optional
~md_forceCreateWindow.();
~md_bootProbeScenario.();
