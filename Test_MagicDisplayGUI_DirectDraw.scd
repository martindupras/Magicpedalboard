/* Test_MagicDisplayGUI_DirectDraw.scd v0.3
   Purpose: Prove the GUI window and list widgets update without MPB.
*/

(
var gui, maxPollCount, pollDelaySeconds, routine;

gui = MagicDisplayGUI.new;
gui.enableMeters(false);

maxPollCount = 200;      // up to ~10 seconds
pollDelaySeconds = 0.05;

routine = Routine {
    var pollCount;
    pollCount = 0;
    while({ gui.window.isNil and: { pollCount < maxPollCount } }, {
        pollCount = pollCount + 1;
        pollDelaySeconds.wait;
    });

    defer({
        var current, next, bypassA, bypassB, effA, effB;
        if(gui.window.notNil) { gui.window.front };

        current = [\chainA, \flanger, \delay, \ts0];  // [sink, …, source]
        next    = [\chainB, \chorus,  \reverb, \ts0];

        bypassA = [\delay];
        bypassB = [];
        effA    = [\chainA, \flanger, \ts0];
        effB    = [\chainB, \chorus, \reverb, \ts0];

        gui.showChainsDetailed(current, next, bypassA, bypassB, effA, effB);
    });
};

Task(routine, AppClock).play;
)
