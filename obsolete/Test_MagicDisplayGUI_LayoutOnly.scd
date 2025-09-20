// Test_MagicDisplayGUI_LayoutOnly.scd
// v0.3.9
// MD 20250919-10:46 BST

/*
Purpose
- Visual-only demo for MagicDisplayGUI_GridDemo with debug guides & row rects.

Style
- var-first; AppClock-only; no server.sync.
*/

(
var closeWindows, makeGui, populate, flipCurrent, showDebug, wins, count;

closeWindows = {
    var run;
    run = {
        var nm;
        wins = Window.allWindows.select({ arg w;
            nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        count = wins.size;
        wins.do(_.close);
        ("[GUI] closed " ++ count ++ " MagicDisplayGUI windows").postln;
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

makeGui = {
    var run;
    run = {
        ~gui = MagicDisplayGUI_GridDemo.new;
        ~gui.enableMeters(false);
        "[GUI] created (GridDemo); meters disabled".postln;
        nil
    };
    AppClock.sched(0.05, { run.value; nil });
};

populate = {
    var run;
    run = {
        var current, next, effC, effN, bypassA, bypassB;
        current = [\chainA, \delay, \chorus, \testmelody];
        next    = [\chainB, \reverb, \testmelody];
        bypassA = [\chorus]; bypassB = [];
        effC = current; effN = next;

        ~gui.showChainsDetailed(current, next, bypassA, bypassB, effC, effN);
        ~gui.highlightCurrentColumn(\chainA);
        ~gui.showExpectation("Row0 two columns; rows 1–4 full-width (addSpanning); meters fixed to 30 px.", 0);
        "[GUI] lists populated".postln;
        nil
    };
    AppClock.sched(0.12, { run.value; nil });
};

showDebug = {
    var run;
    run = {
        ~gui.debugGuides(true);
        AppClock.sched(0.05, { ~gui.postLayoutReport; nil });
        nil
    };
    AppClock.sched(0.20, { run.value; nil });
};

flipCurrent = {
    var run;
    run = {
        var isA;
        isA = false;
        Routine({
            6.do({
                if(isA) {
                    ~gui.highlightCurrentColumn(\chainA);
                    ~gui.showExpectation("CURRENT: A (visual highlight only)", 0);
                }{
                    ~gui.highlightCurrentColumn(\chainB);
                    ~gui.showExpectation("CURRENT: B (visual highlight only)", 0);
                };
                isA = isA.not;
                3.0.wait;
            });
        }).play(AppClock);
        nil
    };
    AppClock.sched(0.25, { run.value; nil });
};

closeWindows.value;
makeGui.value;
populate.value;
// showDebug.value; // turn on/off red debug outlines
flipCurrent.value;
)
