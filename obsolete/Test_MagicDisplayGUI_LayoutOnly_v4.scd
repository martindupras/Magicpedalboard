// Test_MagicDisplayGUI_LayoutOnly_v4.scd
// v0.4.0
// MD 20250919-09:25 BST

/*
Purpose
- Visual-only formatting test for MagicDisplayGUI with a bottom-docked "Processors" panel.
- Resizes the main window to ~1340 px width (and taller), disables meters, and uses GridLayout
  to render CURRENT/NEXT processor strings at the bottom (no overlap with columns).
- Narrows meters group width to avoid wasting the right third.

Style
- var-first in every function/closure; lowercase names; AppClock-only GUI ops; no server.sync.
- One window whose name begins with "MagicDisplayGUI".
*/

(
var closeMagicWindows, makeGui, waitForWindow, bringToFront,
    populateLists, buildBottomHud, refreshBottomHud, shrinkMeters, attachResize,
    winWantedW, winWantedH, hudH;

// ---- configuration ----
winWantedW = 1340;   // your requested width
winWantedH = 900;    // a bit taller to make room for the bottom panel
hudH       = 88;     // bottom panel height (dark grey)

closeMagicWindows = {
    var run;
    run = {
        var wins, count;
        wins = Window.allWindows.select({ arg w;
            var nm; nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        count = wins.size;
        wins.do({ arg w; w.close });
        ("[GUI] closed " ++ count ++ " MagicDisplayGUI windows").postln;
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

makeGui = {
    var run;
    run = {
        ~gui = ~gui ?? { MagicDisplayGUI.new };
        // Visual-only = meters off
        ~gui.enableMeters(false);
        "[GUI] created; meters disabled".postln;
        nil
    };
    AppClock.sched(0.05, { run.value; nil });
};

waitForWindow = { arg timeoutSec = 3.0, pollSec = 0.05, onReadyFunc = nil;
    var startTime, poll;
    startTime = Main.elapsedTime;
    poll = {
        var win, have;
        win = Window.allWindows.detect({ arg w;
            var nm; nm = w.tryPerform(\name);
            nm.notNil and: { nm.asString.beginsWith("MagicDisplayGUI") }
        });
        have = win.notNil;
        if(have) {
            if(onReadyFunc.notNil) { onReadyFunc.value(win) };
            nil
        }{
            if((Main.elapsedTime - startTime) > timeoutSec) {
                "[WAIT] MagicDisplayGUI window not found (timeout)".warn; nil
            }{
                AppClock.sched(pollSec, poll)
            }
        }
    };
    AppClock.sched(0.00, { poll.value; nil });
    ^this
};

bringToFront = { arg win;
    var run;
    run = {
        var x, y;
        if(win.notNil) {
            // Set to requested size; keep top-left where it is
            x = win.bounds.left; y = win.bounds.top;
            win.bounds = Rect(x, y, winWantedW, winWantedH);
            win.front; win.alwaysOnTop_(true);
        };
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// Populate column lists with visual-only demo text
populateLists = {
    var run;
    run = {
        var current, next, effC, effN, bypassA, bypassB;
        current  = [\chainA, \delay, \chorus, \testmelody];
        next     = [\chainB, \reverb, \testmelody];
        bypassA  = [\chorus];
        bypassB  = [];
        effC = current; effN = next;
        if(~gui.notNil) {
            ~gui.showChainsDetailed(current, next, bypassA, bypassB, effC, effN);
            ~gui.highlightCurrentColumn(\chainA);
            ~gui.showExpectation("Visual-only: bottom Processors panel (GridLayout), meters disabled.", 0);
        };
        "[GUI] lists populated".postln;
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// Build bottom-docked Processors panel using GridLayout
// Exposes ~bottomHud and ~bottomHud_update
buildBottomHud = { arg win;
    var run;
    run = {
        var root, pad, panelRect, hud, grid, title, curLabel, curText, nextLabel, nextText;
        var boundsNow;
        if(win.isNil) { ^nil };
        root = win.view;
        pad  = 10;
        boundsNow = root.bounds;

        panelRect = Rect(
            pad,
            boundsNow.height - hudH - pad,   // dock at bottom
            boundsNow.width  - (2 * pad),
            hudH
        );

        // Create once; reuse if present
        if(~bottomHud.notNil and: { ~bottomHud.isClosed.not }) {
            ~bottomHud.bounds = panelRect;
        }{
            hud = CompositeView(root, panelRect)
                .background_(Color(0.12, 0.12, 0.12, 0.92));
            // Use GridLayout for clean alignment and stretching:
            // We'll make 2 columns: [label][content], 3 rows: title (span 2 cols), current, next.
            grid = GridLayout.new;
            hud.layout = grid;

            title     = StaticText(hud).string_("Processors").stringColor_(Color(0.95, 0.95, 0.95));
            curLabel  = StaticText(hud).string_("CURRENT:").stringColor_(Color(0.90, 0.90, 0.90));
            curText   = StaticText(hud).string_("–").stringColor_(Color(0.90, 0.90, 0.90));
            nextLabel = StaticText(hud).string_("NEXT:").stringColor_(Color(0.80, 0.80, 0.80));
            nextText  = StaticText(hud).string_("–").stringColor_(Color(0.80, 0.80, 0.80));

            // Place items (row, col, rows, cols); stretch right column
            grid.add(title,     0, 0, 1, 2);  // span 2 columns
            grid.add(curLabel,  1, 0);
            grid.add(curText,   1, 1);
            grid.add(nextLabel, 2, 0);
            grid.add(nextText,  2, 1);
            grid.setColumnStretch(1, 1);  // right column grows
            grid.setRowStretch(0, 0);     // title fixed
            grid.setRowStretch(1, 1);     // rows get space if needed
            grid.setRowStretch(2, 1);
            grid.hSpacing = 10; grid.vSpacing = 4;

            // remember components for future updates
            ~bottomHud = IdentityDictionary[
                \view     -> hud,
                \curText  -> curText,
                \nextText -> nextText
            ];
            "[HUD] bottom (GridLayout) installed".postln;
        };

        // Provide updater function
        ~bottomHud_update = {
            var getTail, summarize, curArr, nxtArr, curTail, nxtTail, curStr, nxtStr;
            getTail = { arg arr; if(arr.isNil or: { arr.size < 2 }) { [] } { arr.copyRange(1, arr.size-1) } };
            summarize = { arg syms;
                var names, joined;
                names = syms.collect(_.asString);
                joined = names.join("  ->  ");
                if(joined.size > 96) { joined.copyRange(0, 93) ++ "…" } { joined }
            };
            if(~mpb.notNil) {
                curArr = ~mpb.effectiveCurrent;
                nxtArr = ~mpb.effectiveNext;
                curTail = getTail.value(curArr);
                nxtTail = getTail.value(nxtArr);
                curStr = summarize.value(curTail);
                nxtStr = summarize.value(nxtTail);
            }{
                // Visual demo fallback
                curStr = "delay  ->  chorus  ->  testmelody";
                nxtStr = "reverb ->  testmelody";
            };
            if(~bottomHud.notNil) {
                (~bottomHud[\curText]).string = curStr;
                (~bottomHud[\nextText]).string = nxtStr;
            };
        };

        // first fill
        AppClock.sched(0.00, { ~bottomHud_update.value; nil });
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// Narrow the meters group width so it doesn’t force a wide layout
shrinkMeters = { arg win;
    var run;
    run = {
        var root, pad, metersH, winRect, compositeChildren, metersGroupView, groupLeft, groupTop, groupW, labelW, barW, bars;
        if(win.isNil) { ^nil };
        root     = win.view;
        pad      = 10;
        metersH  = 86;
        winRect  = root.bounds;
        compositeChildren = root.children.select({ arg v; v.isKindOf(CompositeView) });
        // meters group: CompositeView child that contains LevelIndicators
        metersGroupView = compositeChildren.detect({ arg cv; cv.children.any({ arg c; c.isKindOf(LevelIndicator) }) });
        if(metersGroupView.notNil) {
            groupLeft = pad;
            groupTop  = winRect.height - metersH - pad;
            groupW    = (winRect.width * 0.55).clip(240, winRect.width - 2*pad); // ~55% width
            metersGroupView.bounds = Rect(groupLeft, groupTop, groupW, metersH);

            labelW = 60;
            barW   = groupW - labelW - 10;
            bars   = metersGroupView.children.select({ arg v; v.isKindOf(LevelIndicator) });
            if(bars.size >= 1) { bars[0].bounds = Rect(labelW + 6, 4,  barW, 20) };
            if(bars.size >= 2) { bars[1].bounds = Rect(labelW + 6, 42, barW, 20) };
            "[METERS] narrowed".postln;
        }{
            "[METERS] group not found (ok on some builds)".postln;
        };
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// Re-apply on resize (keeps HUD docked at bottom & meters narrow)
attachResize = { arg win;
    var run;
    run = {
        if(win.notNil) {
            win.onResize = {
                var x, y, w, h, root, pad, hud;
                // keep width near your requested target if you resize huge
                root = win.view; pad = 10;
                w = win.bounds.width; h = win.bounds.height;
                // reposition HUD
                if(~bottomHud.notNil) {
                    hud = ~bottomHud[\view];
                    if(hud.notNil and: { hud.isClosed.not }) {
                        hud.bounds = Rect(pad, root.bounds.height - hudH - pad, root.bounds.width - (2*pad), hudH);
                    };
                };
                // keep meters narrow
                shrinkMeters.value(win);
                // refresh strings (if ~mpb present)
                if(~bottomHud_update.notNil) {
                    AppClock.sched(0.00, { ~bottomHud_update.value; nil });
                };
            };
        };
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

// ---- run sequence ----
closeMagicWindows.value;
makeGui.value;

waitForWindow.value(
    3.0, 0.05,
    { arg win;
        bringToFront.value(win);
        populateLists.value;
        buildBottomHud.value(win);
        shrinkMeters.value(win);
        attachResize.value(win);
    }
);
)
