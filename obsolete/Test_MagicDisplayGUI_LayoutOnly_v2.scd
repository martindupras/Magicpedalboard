// Test_MagicDisplayGUI_LayoutOnly_v2.scd
// v0.3.0
// MD 20250919-08:45 BST

/*
Purpose
- Bring up MagicDisplayGUI for visual-only testing and apply a NO-RECOMPILE layout fix:
  1) Move the HUD to the top-right so it doesn't cover the columns.
  2) Hide the Ops panel and reclaim the right-hand third for A/B columns.
  3) Shrink the meters horizontally.
- Populate CURRENT/NEXT with demo data and flip the CURRENT highlight every few seconds.

Style
- var-first; lowercase; AppClock-only GUI ops; no server.sync; one window named "MagicDisplayGUI*".
*/

(
var closeMagicWindows, makeGui, populateListsOnce, cycleCurrentHighlight;
var applyVisualFix, attachResizeFix;

// -- close any existing MagicDisplayGUI* windows to be deterministic
closeMagicWindows = {
    AppClock.sched(0.0, {
        var wins, count;
        wins = Window.allWindows.select({ arg w;
            var nm; nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        count = wins.size;
        wins.do(_.close);
        ("[GUI] closed " ++ count ++ " MagicDisplayGUI windows").postln;
        nil
    });
};

// -- create GUI; explicitly disable meters (no audio today)
makeGui = {
    AppClock.sched(0.05, {
        ~gui = ~gui ?? { MagicDisplayGUI.new };
        AppClock.sched(0.0, { ~gui.enableMeters(false); nil });
        AppClock.sched(0.05, { ~gui.enableMeters(false); nil });
        "[GUI] created; meters disabled".postln;
        nil
    });
};

// -- demo visual data
populateListsOnce = {
    AppClock.sched(0.15, {
        var current, next, effC, effN, bypassA, bypassB, ops;
        current = [\chainA, \delay, \chorus, \testmelody];
        next    = [\chainB, \reverb, \testmelody];
        bypassA = [\chorus];
        bypassB = [];
        effC = current; effN = next;
        if(~gui.notNil) {
            ~gui.showChainsDetailed(current, next, bypassA, bypassB, effC, effN);
            ~gui.highlightCurrentColumn(\chainA);
            ~gui.showExpectation("Visual-only layout test. No audio. No meters.", 0);

            // Fill ops list so we can immediately hide it in the fix thereafter.
            ops = ["insert delay", "switch", "bypass delay on", "bypass delay off", "switch"];
            if(~gui.respondsTo(\setOperations)) {
                ~gui.setOperations(ops);
                ~gui.setNextAction({ arg idx; ("[ops] next index " ++ idx).postln; });
            };
        };
        "[GUI] lists populated".postln;
        nil
    });
};

// -- flip current highlight every 3s (visual only)
cycleCurrentHighlight = {
    AppClock.sched(0.30, {
        var isA, step;
        isA = true;
        step = {
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
        };
        Routine({ 8.do({ step.value; 3.0.wait; }) }).play(AppClock);
        nil
    });
};

// ---- NO-RECOMPILE VISUAL FIX ----
// Hide Ops panel, expand columns, shrink meters, park HUD top-right.
// This works by walking the window's view tree (no need to access class ivars).
applyVisualFix = {
    AppClock.sched(0.25, {
        var win, root, pad, colGap, metersH, expH, expGap, countH;
        var winRect, colW, colH, leftX, rightX;

        var compositeChildren, staticTexts, textViews, userViews, listViews, buttons, levelIndicators;

        var guessPanels, isPanelColumn, headerString, leftPanelView, rightPanelView;
        var expectationTextView, countdownLabelView, countdownBarView, metersGroupView;

        // 0) grab window
        win = Window.allWindows.detect({ arg w;
            var nm; nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        if(win.isNil) {
            "[FIX] MagicDisplayGUI window not found; skip.".postln; ^nil
        };
        root = win.view;

        // 1) classify direct children
        compositeChildren = root.children.select(_.isKindOf(CompositeView));
        staticTexts       = root.children.select(_.isKindOf(StaticText));
        textViews         = root.children.select(_.isKindOf(TextView));
        userViews         = root.children.select(_.isKindOf(UserView));
        listViews         = root.children.select(_.isKindOf(ListView));
        buttons           = root.children.select(_.isKindOf(Button));

        // 2) heuristics to identify parts
        //    - left/right panels are CompositeViews that contain a ListView (their list)
        //      and a StaticText header "CURRENT" / "NEXT"
        isPanelColumn = { arg panel;
            var hasList, hasHeader;
            hasList = panel.children.any(_.isKindOf(ListView));
            hasHeader = panel.children.any({ arg v;
                (v.isKindOf(StaticText)) and: {
                    headerString = v.tryPerform(\string);
                    headerString.notNil and: {
                        var s = headerString.asString.toUpper;
                        (s.contains("CURRENT") or: { s.contains("NEXT") })
                    }
                }
            });
            hasList and: { hasHeader }
        };
        guessPanels = compositeChildren.select(isPanelColumn);
        if(guessPanels.size >= 1) {
            // pick the two widest as left/right
            guessPanels = guessPanels.sortBy({ arg v; v.bounds.left });
            leftPanelView  = guessPanels.first;
            rightPanelView = (guessPanels.size > 1).if({ guessPanels.last }, { nil });
        };

        // expectation text = the only TextView child (class file creates one)
        expectationTextView = textViews.first;

        // countdown label = StaticText under expectation (we just move it with bounds)
        countdownLabelView = staticTexts.detect({ arg st;
            var y = st.bounds.top;
            var txt = st.tryPerform(\string);
            (txt.notNil) and: { y > ((expectationTextView.notNil).if({ expectationTextView.bounds.bottom }, { 0 })) }
        });

        // countdown bar = only UserView child (class file creates one)
        countdownBarView = userViews.first;

        // meters group = CompositeView child that contains LevelIndicator(s)
        levelIndicators = root.children.select(_.isKindOf(LevelIndicator)); // not direct parent; we need group
        metersGroupView = compositeChildren.detect({ arg cv;
            cv.children.any(_.isKindOf(LevelIndicator))
        });

        // 3) compute new geometry
        pad     = 10;
        colGap  = 40;
        metersH = 86;
        expH    = 52;
        expGap  = 6;
        countH  = 20;

        winRect = root.bounds;
        // hide the Ops list/button/status (these live directly under root)
        listViews.do(_.visible_(false));
        buttons.do(_.visible_(false));
        staticTexts.do({ arg st;
            var txt = st.tryPerform(\string);
            if(txt.notNil and: { txt.asString.beginsWith("Next:") }) { st.visible_(false) };
        });

        // recompute full-width (reclaim right third)
        colW = ((winRect.width - (2 * pad) - colGap) / 2).max(220);
        colH = (winRect.height
            - (2 * pad)   // top + bottom
            - metersH
            - expH
            - expGap
            - countH
            - 12).max(120);

        leftX  = pad;
        rightX = pad + colW + colGap;

        // 4) apply bounds if we found the views
        if(leftPanelView.notNil)  { leftPanelView.bounds  = Rect(leftX,  pad, colW, colH) };
        if(rightPanelView.notNil) { rightPanelView.bounds = Rect(rightX, pad, colW, colH) };

        if(expectationTextView.notNil) {
            expectationTextView.bounds = Rect(leftX, leftPanelView.bounds.bottom + 6, colW * 2 + colGap, expH)
        };
        if(countdownLabelView.notNil and: { expectationTextView.notNil }) {
            countdownLabelView.bounds = Rect(leftX, expectationTextView.bounds.bottom + expGap, 120, 20)
        };
        if(countdownBarView.notNil and: { expectationTextView.notNil }) {
            countdownBarView.bounds = Rect(leftX + 130, expectationTextView.bounds.bottom + expGap,
                (colW * 2 + colGap) - 140, 20)
        };

        // shrink meters width (e.g., 65% of columns span) and align left
        if(metersGroupView.notNil) {

            var groupLeft, groupTop, groupW, labelW, barW;
			var bars;
            groupLeft = pad;
            groupTop  = winRect.height - metersH - pad;
            groupW    = ((colW * 2 + colGap) * 0.65).clip(260, winRect.width - 2*pad);
            metersGroupView.bounds = Rect(groupLeft, groupTop, groupW, metersH);

            // child bars inside group (two rows)
            labelW = 60;
            barW   = groupW - labelW - 10;

            // find the two LevelIndicator children and set their bounds
            // (order is deterministic in your build: A first row, B second row)
            bars = metersGroupView.children.select(_.isKindOf(LevelIndicator));
            if(bars.size >= 1) { bars[0].bounds = Rect(labelW + 6, 4, barW, 20) };
            if(bars.size >= 2) { bars[1].bounds = Rect(labelW + 6, 42, barW, 20) };
        };

        // park HUD top-right so it doesn't cover the columns
        if(~procHud_relocate.notNil) {
            ~procHud_relocate.(\topRight);
            AppClock.sched(0.05, { if(~procHud_update.notNil) { ~procHud_update.() }; nil });
        };

        "[FIX] visual-only layout applied (ops hidden, columns expanded, meters shrunk, HUD top-right)".postln;
        nil
    });
};

// re-apply the layout fix on window resize
attachResizeFix = {
    AppClock.sched(0.28, {
        var win;
        win = Window.allWindows.detect({ arg w;
            var nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        if(win.notNil) {
            win.onResize = { applyVisualFix.value };
        };
        nil
    });
};

// ---- Run sequence ----
closeMagicWindows.value;
makeGui.value;
populateListsOnce.value;
cycleCurrentHighlight.value;

// If you already evaluated the Top-Left HUD file earlier, it will be moved to top-right.
// If not, this fix still works without HUD.
applyVisualFix.value;
attachResizeFix.value;
)
