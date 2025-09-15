/* Test_MagicDisplayGUI_InlineInstrument.scd v0.2
   Goal: verify that MagicDisplayGUI executes UI updates on AppClock and
         that a single forced frame appears in the lists and "Command:" area.
*/

(
~probeGuiV2 = {
    var hasGui, hasWin, current, next, bypassA, bypassB, effA, effB;

    hasGui = ~gui.notNil;
    if(hasGui.not) { "No ~gui. Run ~bootGuiV4.() first.".warn; ^nil };

    hasWin = ~gui.tryPerform(\window).notNil;

    ["[PROBE] gui exists:", hasGui, "window exists:", hasWin].postln;

    // very distinctive frame so you can spot it instantly
    current = [\chainA, \AAA_debug_one, \BBB_debug_two, \ts0];
    next    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];
    bypassA = [\BBB_debug_two];
    bypassB = [];
    effA    = [\chainA, \AAA_debug_one, \ts0];
    effB    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];

    // make the "Command:" box change as well (immediate visible cue)
    ~gui.showExpectation("Command: PROBE FRAME", 0);

    // schedule list redraw on AppClock (same thread your GUI uses internally)
    AppClock.sched(0, {
        "[PROBE] Calling showChainsDetailed on AppClock…".postln;
        ~gui.showChainsDetailed(current, next, bypassA, bypassB, effA, effB);
        "[PROBE] showChainsDetailed returned.".postln;
        nil
    });

    "Probe queued. Expect 'PROBE FRAME' in the Command area and AAA/BBB/CCC/DDD items in the lists."
    .postln;
};
)
