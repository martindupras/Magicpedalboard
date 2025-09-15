/* Utils_MagicDisplayGUI_Checks.scd
   Tiny helpers for quick inspection during testing.
   Style as per project conventions.
*/

(
// Count & list windows (runs on AppClock safely)
~md_checkWindows = {
    AppClock.sched(0, {
        var wins;
        wins = Window.allWindows ? [];
        ("[CHECK] window count = " ++ wins.size).postln;
        wins.do({ |w, idx| ("[CHECK] w" ++ idx ++ " title=" ++ w.name.asString).postln });
        nil
    });
};

// Confirm we have GUI + pedalboard
~md_checkEnv = {
    var hasGui, hasMpb;
    hasGui = ~gui.notNil; hasMpb = ~mpb.notNil;
    ("[CHECK] has ~gui = " ++ hasGui.asString ++ ", has ~mpb = " ++ hasMpb.asString).postln;
    if(hasGui and: { ~gui.respondsTo(\window) }) {
        ("[CHECK] window exists = " ++ (~gui.window.notNil).asString).postln;
    };
};
)
