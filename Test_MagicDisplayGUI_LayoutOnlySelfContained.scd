// Test_MagicDisplayGUI_LayoutOnlySelfContained.scd
// v0.4.0
// MD 20250919-09:45 BST

/*
Purpose
- Visual-only GUI demonstration using GridLayout (no audio, meters disabled).
- Window ~1340x900; top row: CURRENT/NEXT columns; middle rows: expectation + countdown;
  row below: meters (narrowed, left-anchored); bottom row: dark-grey "Processors" panel.
- No user interaction required.

Style
- var-first in every closure; lowercase method names; AppClock-only GUI ops; no server.sync.
*/

(
var pad, win, root, rootLayout,
    leftPanel, leftGrid, leftHeader, leftList, leftEff,
    rightPanel, rightGrid, rightHeader, rightList, rightEff,
    expectationText, countdownHolder, countdownGrid, countdownLabel, countdownBar,
    meterGroup, meterGrid, labelA, labelB, meterA, meterB, meterSpacer,
    bottomHud, bottomGrid, bottomTitle, bottomCurLabel, bottomCurText, bottomNextLabel, bottomNextText,
    populateDemo, cycleCurrent, wins, closedCount;

AppClock.sched(0.0, {
    // Close any existing MagicDisplayGUI* windows (deterministic)
    var nm;
    wins = Window.allWindows.select({ arg w;
        nm = w.tryPerform(\name);
        nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
    });
    closedCount = wins.size;
    wins.do(_.close);
    ("[GUI] closed " ++ closedCount ++ " MagicDisplayGUI windows").postln;

    // Build main window
    pad = 10;
    win = Window("MagicDisplayGUI – GridDemo (Visual)", Rect(120, 80, 1340, 900))
        .front
        .alwaysOnTop_(true);
    root = win.view;

    // Root GridLayout
    rootLayout = GridLayout.new;
    root.layout = rootLayout;

    // === Row 0: two columns (CURRENT / NEXT) =================================
    leftPanel = CompositeView(root).background_(Color(0.92, 0.92, 0.92));
    leftGrid = GridLayout.new; leftPanel.layout = leftGrid;
    leftHeader = StaticText(leftPanel).string_("CHAIN A ACTIVE").align_(\center);
    leftList   = ListView(leftPanel).items_([]);
    leftEff    = StaticText(leftPanel).string_("eff: —").align_(\center);
    leftGrid.add(leftHeader, 0, 0);
    leftGrid.add(leftList,   1, 0);
    leftGrid.add(leftEff,    2, 0);
    leftGrid.setRowStretch(0, 0);
    leftGrid.setRowStretch(1, 1);
    leftGrid.setRowStretch(2, 0);

    rightPanel = CompositeView(root).background_(Color(0.92, 0.92, 0.92));
    rightGrid = GridLayout.new; rightPanel.layout = rightGrid;
    rightHeader = StaticText(rightPanel).string_("CHAIN B NEXT").align_(\center);
    rightList   = ListView(rightPanel).items_([]);
    rightEff    = StaticText(rightPanel).string_("eff: —").align_(\center);
    rightGrid.add(rightHeader, 0, 0);
    rightGrid.add(rightList,   1, 0);
    rightGrid.add(rightEff,    2, 0);
    rightGrid.setRowStretch(0, 0);
    rightGrid.setRowStretch(1, 1);
    rightGrid.setRowStretch(2, 0);

    rootLayout.add(leftPanel,  0, 0);
    rootLayout.add(rightPanel, 0, 1);
    rootLayout.setColumnStretch(0, 1);
    rootLayout.setColumnStretch(1, 1);
    rootLayout.setRowStretch(0, 6); // top row dominates height

    // === Row 1: expectation text (spans 2 columns) ===========================
    expectationText = TextView(root)
        .background_(Color(1, 1, 0.9))
        .string_("Command:");
    rootLayout.add(expectationText, 1, 0, 1, 2);
    rootLayout.setRowStretch(1, 0);

    // === Row 2: countdown (label + bar) spanning 2 columns ===================
    countdownHolder = CompositeView(root);
    countdownGrid   = GridLayout.new; countdownHolder.layout = countdownGrid;
    countdownLabel  = StaticText(countdownHolder).string_("Ready");
    countdownBar    = UserView(countdownHolder);
    countdownGrid.add(countdownLabel, 0, 0);
    countdownGrid.add(countdownBar,   0, 1);
    countdownGrid.setColumnStretch(0, 0);
    countdownGrid.setColumnStretch(1, 1);
    rootLayout.add(countdownHolder, 2, 0, 1, 2);
    rootLayout.setRowStretch(2, 0);

    // === Row 3: meters (left) + spacer (right) to keep meters narrow =========
    meterGroup = CompositeView(root).background_(Color(0.96, 0.96, 0.96));
    meterGrid  = GridLayout.new; meterGroup.layout = meterGrid;
    labelA = StaticText(meterGroup).string_("chainA");
    meterA = LevelIndicator(meterGroup);
    labelB = StaticText(meterGroup).string_("chainB");
    meterB = LevelIndicator(meterGroup);
    meterGrid.add(labelA, 0, 0);
    meterGrid.add(meterA, 0, 1);
    meterGrid.add(labelB, 1, 0);
    meterGrid.add(meterB, 1, 1);
    meterGrid.setColumnStretch(0, 0);
    meterGrid.setColumnStretch(1, 1);

    meterSpacer = CompositeView(root); // empty filler; absorbs right-space
    rootLayout.add(meterGroup,  3, 0);
    rootLayout.add(meterSpacer, 3, 1);
    // columns: 0 minimal (meters), 1 stretches (spacer)
    rootLayout.setColumnStretch(0, 0);
    rootLayout.setColumnStretch(1, 1);
    rootLayout.setRowStretch(3, 1);

    // === Row 4: bottom Processors panel (dark grey; spans 2 columns) ========
    bottomHud  = CompositeView(root).background_(Color(0.12, 0.12, 0.12, 0.92));
    bottomGrid = GridLayout.new; bottomHud.layout = bottomGrid;
    bottomTitle     = StaticText(bottomHud).string_("Processors").stringColor_(Color(0.95, 0.95, 0.95));
    bottomCurLabel  = StaticText(bottomHud).string_("CURRENT:").stringColor_(Color(0.90, 0.90, 0.90));
    bottomCurText   = StaticText(bottomHud).string_("–").stringColor_(Color(0.90, 0.90, 0.90));
    bottomNextLabel = StaticText(bottomHud).string_("NEXT:").stringColor_(Color(0.80, 0.80, 0.80));
    bottomNextText  = StaticText(bottomHud).string_("–").stringColor_(Color(0.80, 0.80, 0.80));

    bottomGrid.add(bottomTitle,     0, 0, 1, 2); // span 2 columns
    bottomGrid.add(bottomCurLabel,  1, 0);
    bottomGrid.add(bottomCurText,   1, 1);
    bottomGrid.add(bottomNextLabel, 2, 0);
    bottomGrid.add(bottomNextText,  2, 1);
    bottomGrid.setColumnStretch(0, 0);
    bottomGrid.setColumnStretch(1, 1);
    bottomGrid.hSpacing = 10; bottomGrid.vSpacing = 4;

    rootLayout.add(bottomHud, 4, 0, 1, 2);
    rootLayout.setRowStretch(4, 1);

    // Attach resize to the VIEW (not the Window). GridLayout handles sizing.
    root.onResize = { nil };

    // ---- Populate demo content ------------------------------------------------
    populateDemo = {
        var current, next, effC, effN, bypassA, bypassB, formatList, effCText, effNText;
        current = [\chainA, \delay, \chorus, \testmelody];
        next    = [\chainB, \reverb, \testmelody];
        bypassA = [\chorus]; bypassB = [];
        effC = current; effN = next;

        formatList = { arg listRef, bypassKeys, effList;
            var out, lastIdx, procs, idx;
            out = Array.new;
            lastIdx = listRef.size - 1;
            out = out.add("src : " ++ listRef[lastIdx]);
            if(listRef.size > 2) {
                out = out.add("procs:");
                procs = listRef.copyRange(1, lastIdx - 1).reverse;
                idx = 1;
                procs.do({ arg key;
                    var byp, badge, line;
                    byp = bypassKeys.includes(key);
                    badge = byp.if({ "[BYP]" }, { "[ON]" });
                    line = " [" ++ idx ++ "] " ++ key ++ " " ++ badge;
                    out = out.add(line);
                    idx = idx + 1;
                });
            }{
                out = out.add("procs: (none)");
            };
            out = out.add("sink : " ++ listRef[0]);
            out
        };

        leftList.items_(formatList.value(current, bypassA, effC));
        rightList.items_(formatList.value(next,    bypassB, effN));

        effCText = "eff: " ++ effC.join(" -> ");
        effNText = "eff: " ++ effN.join(" -> ");
        leftEff.string_(effCText);
        rightEff.string_(effNText);

        // headers + highlight
        leftHeader.string_("CHAIN A ACTIVE");
        rightHeader.string_("CHAIN B NEXT");
        leftPanel.background_(Color(0.85, 1.0, 0.85));
        rightPanel.background_(Color(0.92, 0.92, 0.92));

        // bottom HUD strings
        bottomCurText.string_((" " ++ effC.copyRange(1, effC.size - 1).join(" -> ")).trim);
        bottomNextText.string_((" " ++ effN.copyRange(1, effN.size - 1).join(" -> ")).trim);

        expectationText.string_("Visual-only: GridLayout; bottom Processors panel; meters narrowed (left).");
        countdownLabel.string_("Ready");
        nil
    };
    populateDemo.value;

    // ---- Flip CURRENT highlight every ~3s (visual only) ----------------------
    cycleCurrent = {
        var isA;
        isA = false;
        Routine({
            8.do({
                if(isA) {
                    leftPanel.background_(Color(0.85, 1.0, 0.85));
                    rightPanel.background_(Color(0.92, 0.92, 0.92));
                    leftHeader.string_("CHAIN A ACTIVE");
                    rightHeader.string_("CHAIN B NEXT");
                    expectationText.string_("CURRENT: A (visual highlight only)");
                }{
                    leftPanel.background_(Color(0.92, 0.92, 0.92));
                    rightPanel.background_(Color(0.85, 1.0, 0.85));
                    leftHeader.string_("CHAIN A NEXT");
                    rightHeader.string_("CHAIN B ACTIVE");
                    expectationText.string_("CURRENT: B (visual highlight only)");
                };
                isA = isA.not;
                3.0.wait;
            });
        }).play(AppClock);
        nil
    };
    cycleCurrent.value;

    nil
});
)
