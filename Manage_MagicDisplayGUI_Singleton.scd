// Manage_MagicDisplayGUI_Singleton.scd
// v0.1
// MD 20250917-1230
//
// Purpose: Close any existing MagicDisplayGUI windows and spawn one fresh GUI,
//          then (optionally) create/recreate ~mpb bound to that GUI.
// Style: tilde vars, var-first, lowercase names, AppClock for GUI ops.
//        no server.sync; server ops should happen elsewhere.

(
var closeExisting, createNew;

closeExisting = {
    AppClock.sched(0.0, {
        var wins;
        wins = Window.allWindows.select({ arg w;
            (w.name ? "").asString.beginsWith("MagicDisplayGUI")
        });
        wins.do({ arg w; w.close });
        nil
    });
};

createNew = {
    AppClock.sched(0.05, {
        ~gui = MagicDisplayGUI.new;
        ~mpb = MagicPedalboardNew.new(~gui);
        nil
    });
};

closeExisting.value;
createNew.value;
)
