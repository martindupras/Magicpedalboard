// quickpatch.scd
// Quick Patch — GUI/Audio sync + reliable GUI front
// v0.1.0
// MD 20250919-10:10 BST

(

/*
Purpose
- Keep MagicDisplayGUI columns/headers in sync with the actual CURRENT (A/B).
- Remember the NEXT effect symbol so the right column shows something useful.
- Wrap ~switchNow to refresh the GUI automatically after audio toggles.
- Bring GUI window to the front; keep the grey UserDisplay behind.

Style
- var-first; lowercase; AppClock-only; no server.sync.
*/

var installGuiSync;

installGuiSync = {
    var ensureGuiFront, refreshFromState, wrapSwitch, hookApply;

    ensureGuiFront = {
        var gwin;
        ~gui = ~gui ?? { MagicDisplayGUI_GridDemo.new };
        if(~gui.respondsTo(\window)) {
            gwin = ~gui.window;
            if(gwin.notNil) { gwin.front; gwin.alwaysOnTop_(true) };
        };
        if(~ct.notNil and: { ~ct.display.notNil and: { ~ct.display.window.notNil } }) {
            ~ct.display.window.alwaysOnTop_(false);
        };
        if(~gui.notNil) { ~gui.showExpectation("GUI ready; syncing with audio state…", 0) };
        nil
    };

    refreshFromState = {
        var current, next, effC, effN, bA, bB, effSym, nowA;
        bA = []; bB = [];
        effSym = ~nextEffectSym ? \delay;   // default if none chosen yet
        nowA = (~currentIsA ? true);

        if(~gui.isNil) { ^nil };

        if(nowA) {
            // CURRENT=A, NEXT=B
            current = [\chainA, \testmelody];
            next    = [\chainB, effSym, \testmelody];
            ~gui.highlightCurrentColumn(\chainA);
        }{
            // CURRENT=B, NEXT=A
            current = [\chainB, \testmelody];
            next    = [\chainA, effSym, \testmelody];
            ~gui.highlightCurrentColumn(\chainB);
        };
        effC = current; effN = next;

        ~gui.showChainsDetailed(current, next, bA, bB, effC, effN);
        nil
    };

    wrapSwitch = {
        // decorate ~switchNow so it always refreshes the GUI after toggling
        if(~switchNow.notNil) {
            ~switchNow_raw = ~switchNow;
            ~switchNow = {
                ~switchNow_raw.();
                AppClock.sched(0.02, { refreshFromState.value; nil });
            };
        };
        nil
    };

    hookApply = {
        // provide a helper the bridge (or you) can call that both applies FX and refreshes
        ~applyCTEffect = { arg effSym;
            ~nextEffectSym = effSym;
            if(~applyToNext.notNil) { ~applyToNext.(effSym) };
            AppClock.sched(0.02, { refreshFromState.value; nil });
        };
        nil
    };

    ensureGuiFront.value;
    wrapSwitch.value;
    hookApply.value;

    // initial fill so the columns aren’t empty
    AppClock.sched(0.01, { refreshFromState.value; nil });

    "[PATCH] GUI sync installed".postln;
    nil
};

AppClock.sched(0.0, { installGuiSync.value; nil });
)
