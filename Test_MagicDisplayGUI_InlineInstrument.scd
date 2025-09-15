/* Test_MagicDisplayGUI_InlineInstrument.scd v0.1
   Goal: prove that MagicDisplayGUI executes UI updates on AppClock.
   It uses only *existing* public methods: showChainsDetailed and showExpectation.
*/

(
~probeGui = {
    var hasGui, hasWin;
	var current, next, bypassA, bypassB, effA, effB;

    hasGui = ~gui.notNil;
    if(hasGui.not) { "No ~gui. Run ~bootGuiV4.() first.".warn; ^nil };

    hasWin = ~gui.tryPerform(\window).notNil;

    // 1) console proof
    ["[PROBE] gui exists:", hasGui, "window exists:", hasWin].postln;

    // 2) push a very distinctive frame into the lists (no MPB involved)
    //    (You should see these exact strings appear in both columns.)
    current = [\chainA, \AAA_debug_one, \BBB_debug_two, \ts0];
	next    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];
    bypassA = [\BBB_debug_two];
    bypassB = [];
    effA    = [\chainA, \AAA_debug_one, \ts0];
    effB    = [\chainB, \CCC_debug_three, \DDD_debug_four, \ts0];

    // 3) also update the "Command:" box so something *must* change visually
    ~gui.showExpectation("Command: PROBE FRAME", 0);

    // 4) schedule the actual list redraw on AppClock (same thread your GUI uses)
    AppClock.sched(0, {
        "[PROBE] Calling showChainsDetailed on AppClock…".postln;
        ~gui.showChainsDetailed(current, next, bypassA, bypassB, effA, effB);
        "[PROBE] showChainsDetailed returned.".postln;
        nil
    });

    "Probe queued. You should see the 'PROBE FRAME' command text and the lists with AAA/BBB/CCC/DDD.".postln;
};
)
