// MagicDisplayGUI_GridDemo.sc
// v0.1.5
// MD 20250919-10:46 BST

/*
Purpose
- GridLayout-based GUI for VISUAL-ONLY demos (no audio, meters disabled).
- Row 0: CURRENT | NEXT (two equal columns).
- Rows 1..4: full-width using addSpanning (expectation, countdown, thin meters=30px, processors).
- Extra height only goes to Row 0 (chains row).

Debug
- debugGuides(true): overlays red outlines + row labels; postLayoutReport() prints rects.

Style
- var-first; lowercase; AppClock-only UI ops; no caret returns in closures; no server.sync.
*/

MagicDisplayGUI_GridDemo : MagicDisplay {
    classvar <versionGUI;
    var <window;

    // root + top-level row views (children of window.view)
    var rootLayout;
    var leftPanel, rightPanel;
    var expectationView, countdownHolder, meterStrip, bottomHudView;

    // children within panels
    var leftHeader, leftListView, leftEff;
    var rightHeader, rightListView, rightEff;
    var countdownLabel, countdownBar;
    var bottomCurText, bottomNextText;

    // debug overlay
    var debugOn = false;
    var overlayRow0, overlayRow1, overlayRow2, overlayRow3, overlayRow4;

    var metersEnabled;

    *initClass {
        var s;
        versionGUI = "v0.1.5";
        s = "MagicDisplayGUI_GridDemo " ++ versionGUI;
        s.postln;
    }

    *new { arg level = 1;
        var instance;
        instance = super.new(level);
        ^instance.initGui;
    }

    initGui {
        var reqW, reqH, sb, maxW, maxH, winW, winH, rect;
        var metersRowH, hudRowH;
        var buildLeft, buildRight, buildExpectation, buildCountdown, buildMeters, buildBottomHud;

        // window sizing (fits iPad side-screen limit)
        reqW = 1200; reqH = 760;
        sb   = Window.screenBounds ? Rect(0, 0, 1920, 1080);
        maxW = (2560).min(sb.width);
        maxH = (1666).min(sb.height);
        winW = reqW.clip(640, maxW);
        winH = reqH.clip(480, maxH);
        rect = Rect(
            sb.left + ((sb.width - winW) * 0.5),
            sb.top  + ((sb.height - winH) * 0.5),
            winW, winH
        );

        metersRowH = 30;   // thin strips
        hudRowH    = 88;

        window = Window("MagicDisplayGUI – GridDemo", rect).front.alwaysOnTop_(true);
        metersEnabled = false;

        // root GridLayout on the VIEW (not the Window)
        rootLayout = GridLayout.new;
        window.view.layout = rootLayout;

        // equal columns globally (row 0 uses them)
        rootLayout.setColumnStretch(0, 1);
        rootLayout.setColumnStretch(1, 1);

        // ---- Row 0: CURRENT / NEXT (two equal columns) ----
        buildLeft = {
            var grid;
            grid = GridLayout.new;
            leftPanel = CompositeView(window.view).background_(Color(0.92, 0.92, 0.92));
            leftPanel.layout = grid;

            leftHeader   = StaticText(leftPanel).string_("CHAIN A ACTIVE").align_(\center);
            leftListView = ListView(leftPanel).items_([]);
            leftEff      = StaticText(leftPanel).string_("eff: —").align_(\center);

            grid.add(leftHeader,   0, 0);
            grid.add(leftListView, 1, 0);
            grid.add(leftEff,      2, 0);
            grid.setRowStretch(0, 0);
            grid.setRowStretch(1, 1);
            grid.setRowStretch(2, 0);
        };

        buildRight = {
            var grid;
            grid = GridLayout.new;
            rightPanel = CompositeView(window.view).background_(Color(0.92, 0.92, 0.92));
            rightPanel.layout = grid;

            rightHeader   = StaticText(rightPanel).string_("CHAIN B NEXT").align_(\center);
            rightListView = ListView(rightPanel).items_([]);
            rightEff      = StaticText(rightPanel).string_("eff: —").align_(\center);

            grid.add(rightHeader,   0, 0);
            grid.add(rightListView, 1, 0);
            grid.add(rightEff,      2, 0);
            grid.setRowStretch(0, 0);
            grid.setRowStretch(1, 1);
            grid.setRowStretch(2, 0);
        };

        buildLeft.value;
        buildRight.value;
        rootLayout.add(leftPanel,  0, 0);
        rootLayout.add(rightPanel, 0, 1);
        rootLayout.setRowStretch(0, 1); // only row allowed to grow

        // ---- Row 1: expectation (FULL width) ----
        buildExpectation = {
            expectationView = TextView(window.view)
                .background_(Color(1, 1, 0.9))
                .string_("Command:");
        };
        buildExpectation.value;
        rootLayout.addSpanning(expectationView, 1, 0, 1, 2);
        rootLayout.setRowStretch(1, 0);
        rootLayout.setMinRowHeight(1, 36);

        // ---- Row 2: countdown (FULL width) ----
        buildCountdown = {
            var sub;
            countdownHolder = CompositeView(window.view);
            sub = GridLayout.new; countdownHolder.layout = sub;
            countdownLabel = StaticText(countdownHolder).string_("Ready");
            countdownBar   = UserView(countdownHolder);
            sub.add(countdownLabel, 0, 0);
            sub.add(countdownBar,   0, 1);
            sub.setColumnStretch(0, 0);
            sub.setColumnStretch(1, 1);
        };
        buildCountdown.value;
        rootLayout.addSpanning(countdownHolder, 2, 0, 1, 2);
        rootLayout.setRowStretch(2, 0);
        rootLayout.setMinRowHeight(2, 24);

        // ---- Row 3: meters (FULL width; 30 px) ----
        buildMeters = {
            meterStrip = UserView(window.view);
            meterStrip.background = Color(0.96, 0.96, 0.96);
            meterStrip.drawFunc = { |view|
                var b, pad, h, barH, top1, top2;
                b   = view.bounds;
                pad = 8;
                h   = b.height;
                barH = (h - (pad * 2) - 4) / 2;
                barH = barH.clip(8, 14);
                top1 = pad;
                top2 = pad + barH + 4;
                Pen.color = Color.gray(0.3);
                Pen.addRect(Rect(pad, top1, b.width - pad*2, barH)); Pen.fill;
                Pen.color = Color.gray(0.5);
                Pen.addRect(Rect(pad, top2, b.width - pad*2, barH)); Pen.fill;
                Pen.color = Color.gray(0.7);
                Pen.strokeRect(Rect(0.5, 0.5, b.width - 1, b.height - 1));
            };
        };
        buildMeters.value;
        rootLayout.addSpanning(meterStrip, 3, 0, 1, 2);
        rootLayout.setRowStretch(3, 0);
        rootLayout.setMinRowHeight(3, metersRowH);

        // ---- Row 4: processors (FULL width) ----
        buildBottomHud = {
            var grid, title, curLabel, nextLabel;
            bottomHudView = CompositeView(window.view).background_(Color(0.12, 0.12, 0.12, 0.92));
            grid = GridLayout.new; bottomHudView.layout = grid;

            title          = StaticText(bottomHudView).string_("Processors").stringColor_(Color(0.95, 0.95, 0.95));
            curLabel       = StaticText(bottomHudView).string_("CURRENT:").stringColor_(Color(0.90, 0.90, 0.90));
            bottomCurText  = StaticText(bottomHudView).string_("–").stringColor_(Color(0.90, 0.90, 0.90));
            nextLabel      = StaticText(bottomHudView).string_("NEXT:").stringColor_(Color(0.80, 0.80, 0.80));
            bottomNextText = StaticText(bottomHudView).string_("–").stringColor_(Color(0.80, 0.80, 0.80));

            grid.add(title,          0, 0, 1, 2);
            grid.add(curLabel,       1, 0);
            grid.add(bottomCurText,  1, 1);
            grid.add(nextLabel,      2, 0);
            grid.add(bottomNextText, 2, 1);
            grid.setColumnStretch(0, 0);
            grid.setColumnStretch(1, 1);
            grid.hSpacing = 10;
            grid.vSpacing = 4;
        };
        buildBottomHud.value;
        rootLayout.addSpanning(bottomHudView, 4, 0, 1, 2);
        rootLayout.setRowStretch(4, 0);
        rootLayout.setMinRowHeight(4, hudRowH);

        this.attachResizeHandler;
        ^this
    }

    // -------- Public (visual-only) --------
    showChainsDetailed { arg current, next, bypassAKeys, bypassBKeys, effCurrent, effNext;
        var fmt, effCText, effNText, aIsCurrent;

        fmt = { arg listRef, bypassKeys, effList;
            var itemsOut, lastIndex, processors, indexCounter;
            itemsOut = Array.new;
            lastIndex = listRef.size - 1;
            itemsOut = itemsOut.add("src : " ++ listRef[lastIndex]);
            if(listRef.size > 2) {
                itemsOut = itemsOut.add("procs:");
                processors = listRef.copyRange(1, lastIndex - 1).reverse;
                indexCounter = 1;
                processors.do({ arg key;
                    var byp, badge, lineText;
                    byp = bypassKeys.includes(key);
                    badge = byp.if({ "[BYP]" }, { "[ON]" });
                    lineText = " [" ++ indexCounter ++ "] " ++ key ++ " " ++ badge;
                    itemsOut = itemsOut.add(lineText);
                    indexCounter = indexCounter + 1;
                });
            }{
                itemsOut = itemsOut.add("procs: (none)");
            };
            itemsOut = itemsOut.add("sink : " ++ listRef[0]);
            itemsOut
        };

        effCText = "eff: " ++ effCurrent.join(" -> ");
        effNText = "eff: " ++ effNext.join(" -> ");

        if(leftListView.notNil)  { leftListView.items_(fmt.value(current, bypassAKeys, effCurrent)) };
        if(rightListView.notNil) { rightListView.items_(fmt.value(next,    bypassBKeys, effNext))    };
        if(leftEff.notNil)  { leftEff.string_(effCText) };
        if(rightEff.notNil) { rightEff.string_(effNText) };

        aIsCurrent = (current[0] == \chainA);
        if(leftHeader.notNil)  { leftHeader.string_((aIsCurrent).if({ "CHAIN A ACTIVE" }, { "CHAIN A NEXT" })) };
        if(rightHeader.notNil) { rightHeader.string_((aIsCurrent).if({ "CHAIN B NEXT"   }, { "CHAIN B ACTIVE" })) };

        // no .trim (SC String has no trim); keep plain join
        if(bottomCurText.notNil)  { bottomCurText.string_(" " ++ effCurrent.copyRange(1, effCurrent.size-1).join(" -> ")) };
        if(bottomNextText.notNil) { bottomNextText.string_(" " ++ effNext.copyRange(1, effNext.size-1).join(" -> ")) };

        ^this
    }

    highlightCurrentColumn { arg currentSinkSym;
        var greenBg, neutralBg, isA;
        greenBg   = Color(0.85, 1.0, 0.85);
        neutralBg = Color(0.92, 0.92, 0.92);
        isA = (currentSinkSym == \chainA);
        if(leftPanel.notNil)  { leftPanel.background_((isA).if({ greenBg }, { neutralBg })) };
        if(rightPanel.notNil) { rightPanel.background_((isA).if({ neutralBg }, { greenBg })) };
        ^this
    }

    showExpectation { arg textString, seconds = 0;
        var secs;
        secs = seconds ? 0;
        if(expectationView.notNil) { expectationView.string_(textString.asString) };
        if(countdownLabel.notNil)  { countdownLabel.string_((secs > 0).if({ "Listen in… (" ++ secs ++ "s)" }, { "Ready" })) };
        ^this
    }

    setOperations { arg itemsArray; ^this }  // visual-only

    enableMeters { arg flag = false; metersEnabled = (flag ? false); ^this }

    attachResizeHandler {
        var run;
        run = {
            var v;
            v = window.tryPerform(\view);
            if(v.notNil) {
                v.onResize = {
                    if(debugOn) { this.debugGuides(true) };
                };
            };
            nil
        };
        AppClock.sched(0.00, { run.value; nil });
        ^this
    }

    // -------- Debug overlay --------

    debugGuides { arg on = true;
        var mkOverlay, labelText;
        debugOn = (on ? true);

        mkOverlay = { arg ov;
            var out;
            out = ov;
            if(out.isNil or: { out.isClosed }) {
                out = UserView(window.view);
                out.drawFunc = { |v|
                    var b;
                    b = v.bounds;
                    Pen.color = Color(1, 0, 0, 0.35);
                    Pen.width = 2;
                    Pen.strokeRect(Rect(1, 1, b.width - 2, b.height - 2));
                };
                out.background = Color.clear;
            };
            out
        };

        AppClock.sched(0.00, {
            overlayRow0 = mkOverlay.value(overlayRow0);
            overlayRow1 = mkOverlay.value(overlayRow1);
            overlayRow2 = mkOverlay.value(overlayRow2);
            overlayRow3 = mkOverlay.value(overlayRow3);
            overlayRow4 = mkOverlay.value(overlayRow4);

            rootLayout.addSpanning(overlayRow0, 0, 0, 1, 2);
            rootLayout.addSpanning(overlayRow1, 1, 0, 1, 2);
            rootLayout.addSpanning(overlayRow2, 2, 0, 1, 2);
            rootLayout.addSpanning(overlayRow3, 3, 0, 1, 2);
            rootLayout.addSpanning(overlayRow4, 4, 0, 1, 2);

            AppClock.sched(0.02, {
                var r0, r1, r2, r3, r4;
                var mkLabel;
                mkLabel = { arg parent, text;
                    var st;
                    st = StaticText(parent).string_(text).stringColor_(Color(1, 0.2, 0.2)).align_(\left);
                    st.background = Color(1, 1, 1, 0.20);
                    st  // no caret return in closures
                };

                overlayRow0.children.do(_.remove);
                overlayRow1.children.do(_.remove);
                overlayRow2.children.do(_.remove);
                overlayRow3.children.do(_.remove);
                overlayRow4.children.do(_.remove);

                r0 = overlayRow0.bounds; r1 = overlayRow1.bounds; r2 = overlayRow2.bounds; r3 = overlayRow3.bounds; r4 = overlayRow4.bounds;
                mkLabel.value(overlayRow0, "row 0  " ++ r0.width.round(1) ++ "×" ++ r0.height.round(1));
                mkLabel.value(overlayRow1, "row 1  " ++ r1.width.round(1) ++ "×" ++ r1.height.round(1));
                mkLabel.value(overlayRow2, "row 2  " ++ r2.width.round(1) ++ "×" ++ r2.height.round(1));
                mkLabel.value(overlayRow3, "row 3  " ++ r3.width.round(1) ++ "×" ++ r3.height.round(1) ++ " (meters)");
                mkLabel.value(overlayRow4, "row 4  " ++ r4.width.round(1) ++ "×" ++ r4.height.round(1) ++ " (processors)");
                nil
            });
            nil
        });

        ^this
    }

    postLayoutReport {
        var run;
        run = {
            var r0, r1, r2, r3, r4, unionRow0;
            unionRow0 = leftPanel.bounds.union(rightPanel.bounds);
            r0 = unionRow0; r1 = expectationView.bounds; r2 = countdownHolder.bounds; r3 = meterStrip.bounds; r4 = bottomHudView.bounds;
            ("[layout] row0=" ++ r0).postln;
            ("[layout] row1=" ++ r1).postln;
            ("[layout] row2=" ++ r2).postln;
            ("[layout] row3=" ++ r3).postln;
            ("[layout] row4=" ++ r4).postln;
            nil
        };
        AppClock.sched(0.00, { run.value; nil });
        ^this
    }
}
