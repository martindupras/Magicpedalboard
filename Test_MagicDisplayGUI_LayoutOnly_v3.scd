// Test_MagicDisplayGUI_LayoutOnly_v3.scd
// v0.3.3
// MD 20250919-09:05 BST

/*
Purpose
- Visual-only formatting test for MagicDisplayGUI (no audio, no meters).
- Robustly wait for the window to be created (AppClock poll) before any layout tweaks.
- Fixes you asked for:
  1) Move HUD to top-right (so it doesn't cover columns).
  2) Reclaim right-hand empty area by hiding ops panel if present.
  3) Shrink meters horizontally.

Style
- var-first in every function/closure; lowercase method names; AppClock-only for GUI; no server.sync.
- One window whose name begins with "MagicDisplayGUI".
*/

(
var closeMagicWindows, makeGui, waitForGuiWindow, bringToFront,
    populateListsOnce, cycleCurrentHighlight, applyVisualFix, attachResizeFix;

// ---- A) Close pre-existing windows (deterministic start) ----
closeMagicWindows = {
    var run;
    run = {
        var wins, count;
        wins = Window.allWindows.select({ arg w;
            var nm;
            nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        count = wins.size;
        wins.do({ arg w; w.close });
        ("[GUI] closed " ++ count ++ " MagicDisplayGUI windows").postln;
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// ---- B) Create GUI and keep meters disabled (visual-only) ----
makeGui = {
    var run;
    run = {
        ~gui = ~gui ?? { MagicDisplayGUI.new };
        // keep meters off (no audio)
        ~gui.enableMeters(false);
        ("[GUI] created; meters disabled").postln;
        nil
    };
    AppClock.sched(0.05, { run.value; nil });
};

// ---- C) Wait until the MagicDisplayGUI window exists (AppClock poll) ----
waitForGuiWindow = { arg timeoutSec = 2.0, pollSec = 0.05, onReadyFunc = nil;
    var startTime, poll;
    startTime = Main.elapsedTime;
    poll = {
        var win, have;
        win = Window.allWindows.detect({ arg w;
            var nm;
            nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        have = win.notNil;
        if(have) {
            if(onReadyFunc.notNil) { onReadyFunc.value(win) };
            nil
        }{
            if((Main.elapsedTime - startTime) > timeoutSec) {
                "[WAIT] MagicDisplayGUI window not found (timeout)".warn;
                nil
            }{
                AppClock.sched(pollSec, poll)
            }
        }
    };
    AppClock.sched(0.00, { poll.value; nil });
    ^this
};

// ---- D) Bring the window to the front (belt-and-braces) ----
bringToFront = { arg win;
    var run;
    run = {
        if(win.notNil) {
            win.front;
            win.alwaysOnTop_(true);
        };
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// ---- E) Populate CURRENT/NEXT lists visually (no audio) ----
populateListsOnce = {
    var run;
    run = {
        var current, next, effC, effN, bypassA, bypassB, ops;
        current  = [\chainA, \delay, \chorus, \testmelody];
        next     = [\chainB, \reverb, \testmelody];
        bypassA  = [\chorus];
        bypassB  = [];
        effC     = current;
        effN     = next;
        if(~gui.notNil) {
            ~gui.showChainsDetailed(current, next, bypassA, bypassB, effC, effN);
            ~gui.highlightCurrentColumn(\chainA);
            ~gui.showExpectation("Visual-only layout test. No audio. No meters.", 0);
            // Provide text for the ops list (non-interactive); may not exist on your build
            ops = ["insert delay", "switch", "bypass delay on", "bypass delay off", "switch"];
            if(~gui.respondsTo(\setOperations)) {
                ~gui.setOperations(ops);
                ~gui.setNextAction({ arg idx; ("[ops] next index " ++ idx).postln; });
            };
        };
        ("[GUI] lists populated").postln;
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// ---- F) Flip CURRENT highlight every ~3 seconds (visual only) ----
cycleCurrentHighlight = {
    var run;
    run = {
        var isA;
        isA = true;
        Routine({
            8.do({
                if(~gui.notNil) {
                    if(isA) {
                        ~gui.highlightCurrentColumn(\chainA);
                        ~gui.showExpectation("CURRENT: A (visual highlight only)", 0);
                    }{
                        ~gui.highlightCurrentColumn(\chainB);
                        ~gui.showExpectation("CURRENT: B (visual highlight only)", 0);
                    };
                };
                isA = isA.not;
                3.0.wait;
            });
        }).play(AppClock);
        nil
    };
    AppClock.sched(0.25, { run.value; nil });
};

// ---- G) Visual fix: reclaim right space, shrink meters, move HUD top-right ----
applyVisualFix = { arg win;
    var run;
    run = {
        var root, pad, colGap, metersH, expH, expGap, countH;
        var winRect, colW, colH, leftX, rightX;
        var compositeChildren, staticTexts, textViews, userViews, listViews, buttons, levelIndicators;
        var guessPanels, isPanelColumn, headerString, leftPanelView, rightPanelView;
        var expectationTextView, countdownLabelView, countdownBarView, metersGroupView;

        // guard
        if(win.isNil) { ^nil };

        root  = win.view;
        pad   = 10;
        colGap= 40;
        metersH = 86;
        expH    = 52;
        expGap  = 6;
        countH  = 20;

        winRect = root.bounds;

        // classify children (direct)
        compositeChildren = root.children.select({ arg v; v.isKindOf(CompositeView) });
        staticTexts       = root.children.select({ arg v; v.isKindOf(StaticText) });
        textViews         = root.children.select({ arg v; v.isKindOf(TextView) });
        userViews         = root.children.select({ arg v; v.isKindOf(UserView) });
        listViews         = root.children.select({ arg v; v.isKindOf(ListView) });
        buttons           = root.children.select({ arg v; v.isKindOf(Button) });
        levelIndicators   = root.children.select({ arg v; v.isKindOf(LevelIndicator) }); // probably empty; bars live under meters group

        // locate left/right column panels via heuristics
        isPanelColumn = { arg panel;
            var hasList, hasHeader;
            hasList   = panel.children.any({ arg c; c.isKindOf(ListView) });
            hasHeader = panel.children.any({ arg c;
                var t;
                t = (c.isKindOf(StaticText)).if({ c.tryPerform(\string) }, { nil });
                t.notNil and: {
                    var s;
                    s = t.asString.toUpper;
                    s.contains("CURRENT") or: { s.contains("NEXT") }
                }
            });
            hasList and: { hasHeader }
        };
        guessPanels = compositeChildren.select(isPanelColumn).sortBy({ arg v; v.bounds.left });
        leftPanelView  = (guessPanels.size >= 1).if({ guessPanels[0] }, { nil });
        rightPanelView = (guessPanels.size >= 2).if({ guessPanels[1] }, { nil });

        expectationTextView = textViews.first;         // created in class
        countdownBarView    = userViews.first;         // created in class
        countdownLabelView  = staticTexts.detect({ arg st;
            var lbok, txt, y, expBottom;
            txt = st.tryPerform(\string);
            y   = st.bounds.top;
            expBottom = (expectationTextView.notNil).if({ expectationTextView.bounds.bottom }, { 0 });
            lbok = txt.notNil and: { y > expBottom };
            lbok
        });

        // hide ops area if present
        listViews.do({ arg lv; lv.visible_(false) });
        buttons.do({ arg b; b.visible_(false) });
        staticTexts.do({ arg st;
            var txt;
            txt = st.tryPerform(\string);
            if(txt.notNil and: { txt.asString.beginsWith("Next:") }) { st.visible_(false) };
        });

        // recompute two column geometry across full width
        colW = ((winRect.width - (2 * pad) - colGap) / 2).max(220);
        colH = (winRect.height - (2 * pad) - metersH - expH - expGap - countH - 12).max(120);
        leftX  = pad;
        rightX = pad + colW + colGap;

        if(leftPanelView.notNil)  { leftPanelView.bounds  = Rect(leftX,  pad, colW, colH) };
        if(rightPanelView.notNil) { rightPanelView.bounds = Rect(rightX, pad, colW, colH) };

        if(expectationTextView.notNil and: { leftPanelView.notNil }) {
            expectationTextView.bounds = Rect(leftX, leftPanelView.bounds.bottom + 6, colW * 2 + colGap, expH)
        };
        if(countdownLabelView.notNil and: { expectationTextView.notNil }) {
            countdownLabelView.bounds = Rect(leftX, expectationTextView.bounds.bottom + expGap, 120, 20)
        };
        if(countdownBarView.notNil and: { expectationTextView.notNil }) {
            countdownBarView.bounds = Rect(leftX + 130, expectationTextView.bounds.bottom + expGap,
                (colW * 2 + colGap) - 140, 20)
        };

        // locate meters group: CompositeView child that contains LevelIndicators
        metersGroupView = compositeChildren.detect({ arg cv;
            cv.children.any({ arg c; c.isKindOf(LevelIndicator) })
        });

        // shrink meters width to 60% of columns span and align left
        if(metersGroupView.notNil) {
            var groupLeft, groupTop, groupW, labelW, barW, bars;
            groupLeft = pad;
            groupTop  = winRect.height - metersH - pad;
            groupW    = ((colW * 2 + colGap) * 0.60).clip(240, winRect.width - 2*pad);
            metersGroupView.bounds = Rect(groupLeft, groupTop, groupW, metersH);

            // child indicators (two rows: A/B)
            labelW = 60;
            barW   = groupW - labelW - 10;
            bars   = metersGroupView.children.select({ arg v; v.isKindOf(LevelIndicator) });
            if(bars.size >= 1) { bars[0].bounds = Rect(labelW + 6, 4,  barW, 20) };
            if(bars.size >= 2) { bars[1].bounds = Rect(labelW + 6, 42, barW, 20) };
        };

        // move HUD to top-right (if the helpers exist)
        if(~procHud_relocate.notNil) {
            ~procHud_relocate.(\topRight);
            AppClock.sched(0.05, { if(~procHud_update.notNil) { ~procHud_update.() }; nil });
        };

        "[FIX] visual-only layout applied (ops hidden if present, columns expanded, meters shrunk, HUD top-right)".postln;
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// ---- H) Reapply fix on window resize ----
attachResizeFix = { arg win;
    var run;
    run = {
        if(win.notNil) {
            win.onResize = { applyVisualFix.value(win) };
        };
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// ---- Sequence ----
closeMagicWindows.value;
makeGui.value;

waitForGuiWindow.value(
    3.0, 0.05,
    { arg win;
        bringToFront.value(win);
        populateListsOnce.value;
        cycleCurrentHighlight.value;
        applyVisualFix.value(win);
        attachResizeFix.value(win);
    }
);
)
