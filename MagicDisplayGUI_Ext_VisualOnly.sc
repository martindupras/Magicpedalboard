// MagicDisplayGUI_Ext_VisualOnly.sc
// v0.1.1 (fixed: no ivar; uses window property bag instead)
// MD 20250919-08:05 BST

/*
Purpose
- Add "visual-only" layout controls to MagicDisplayGUI without modifying the class file.
- setVisualOnly(true): hides Ops area; recomputes A/B panel heights so they stop above
  the expectation/countdown block; meters group remains at the bottom.
- relayoutVisualOnly: recompute bounds; attachResize wires window.onResize -> relayout.

Style
- AppClock for UI; no server.sync; methods live in a class extension.
- Uses window.setProperty/getProperty(\visualOnlyFlag) instead of new ivars.
*/

+ MagicDisplayGUI {

    // -- helpers to read/write the visual-only flag using the window as property bag
    getVisualOnlyFlag {
        var v;
        v = false;
        if(window.notNil) {
            v = window.getProperty(\visualOnlyFlag) ? false;
        };
        ^v
    }

    setVisualOnly { arg flag = true;
        var on;
        on = flag ? true;
        this.queueUi({
            if(window.notNil) { window.setProperty(\visualOnlyFlag, on) };

            // Hide or show ops widgets
            if(opsListView.notNil)   { opsListView.visible_(on.not) };
            if(opsNextButton.notNil) { opsNextButton.visible_(on.not) };
            if(opsStatusText.notNil) { opsStatusText.visible_(on.not) };

            this.relayoutVisualOnly;  // recompute layout now
        });
        ^this
    }

    relayoutVisualOnly {
        var pad, metersH, expH, expGap, countH, winRect, colGap;
        var visualOnly, rightW, usableW, colW, colH, leftX, rightX;
        var groupLeft, groupTop, groupW, labelW, barW;

        // Geometry constants (aligned to your class)
        pad     = 10;
        metersH = 86;   // meters block height in your class
        expH    = 52;   // expectation text height
        expGap  = 6;    // spacing between expectation and countdown bar row
        countH  = 20;   // countdown row height
        colGap  = 40;   // gap between columns

        visualOnly = this.getVisualOnlyFlag;

        // Window rect fallback if not created yet
        winRect = (window.notNil).if({ window.view.bounds }, { Rect(0, 0, 980, 520) });

        // If visual-only, reclaim the ops panel width
        rightW  = (visualOnly ? 0 : 320);

        // Compute column widths
        usableW = winRect.width - (2 * pad) - rightW - colGap;
        colW    = (usableW / 2).max(220);

        // Compute column heights so panels stop ABOVE the expectation + countdown region
        colH = winRect.height
            - (2 * pad)   // top + bottom padding
            - metersH     // meters area at bottom
            - expH        // expectation text
            - expGap      // spacing
            - countH      // countdown row
            - 12;         // small margin

        colH = colH.max(120);

        leftX  = pad;
        rightX = pad + colW + colGap;

        this.queueUi({
            // Left/right column panels
            if(leftPanel.notNil)  { leftPanel.bounds  = Rect(leftX,  pad, colW, colH) };
            if(rightPanel.notNil) { rightPanel.bounds = Rect(rightX, pad, colW, colH) };

            // Expectation + countdown spans both columns
            if(expectationText.notNil) {
                expectationText.bounds = Rect(leftX, leftPanel.bounds.bottom + 6, colW*2 + colGap, expH)
            };
            if(countdownLabel.notNil)   {
                countdownLabel.bounds    = Rect(leftX, expectationText.bounds.bottom + expGap, 120, 20)
            };
            if(countdownBarView.notNil) {
                countdownBarView.bounds  = Rect(leftX + 130, expectationText.bounds.bottom + expGap,
                                                (colW*2 + colGap) - 140, 20)
            };

            // Ops area only when not visual-only
            if(visualOnly.not and: { opsListView.notNil }) {
                opsListView.bounds = Rect(expectationText.bounds.right + pad, pad,
                                          rightW - pad, winRect.height - 2 * pad);
                if(opsStatusText.notNil) {
                    opsStatusText.bounds = Rect(opsListView.bounds.left,
                                                opsListView.bounds.bottom - 52,
                                                opsListView.bounds.width - 110, 20)
                };
                if(opsNextButton.notNil) {
                    opsNextButton.bounds = Rect(opsListView.bounds.right - 100,
                                                opsListView.bounds.bottom - 56, 100, 28)
                };
            };

            // Meters group: reuse the parent of meterViewA/B
            if(meterViewA.notNil and: { meterViewB.notNil } and: { meterViewA.parent.notNil }) {
                groupLeft = pad;
                groupTop  = winRect.height - metersH - pad;
                groupW    = winRect.width  - 2*pad;
                meterViewA.parent.bounds = Rect(groupLeft, groupTop, groupW, metersH);

                // child bars
                labelW = 60;
                barW   = groupW - labelW - 10;
                meterViewA.bounds = Rect(labelW + 6, 4, barW, 20);
                meterViewB.bounds = Rect(labelW + 6, 4 + 38, barW, 20);
            };
        });

        ^this
    }

    attachResize {
        this.queueUi({
            if(window.notNil) {
                window.onResize = { this.relayoutVisualOnly };
            };
        });
        ^this
    }
}
