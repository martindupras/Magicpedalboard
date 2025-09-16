(
// =========================
// Utils_MagicDisplayGUI_Checks.scd  (single block)
// =========================

~md_checkEnv = {
    var gui_present, queue_ok, setter_ok, atput_ok, win_count, win_titles;
    gui_present = ~gui.notNil;
    queue_ok = gui_present and: { ~gui.respondsTo(\queueUi) };
    setter_ok = gui_present and: { ~gui.respondsTo(\queueUi_) };
    atput_ok = gui_present and: { ~gui.respondsTo(\atPut) };
    win_count = (~md_get_gui_windows.notNil).if({ ~md_get_gui_windows.().size }, { 0 });
    win_titles = (win_count > 0).if({ ~md_get_gui_windows.().collect({ |w| w.name.asString }) }, { [] });
    "[ENV] mpb:% gui:% queueUi:% queueUi_:% atPut:% windows:% titles:%"
        .format(~mpb.notNil, gui_present, queue_ok, setter_ok, atput_ok, win_count, win_titles)
        .postln;
};

~md_appclock_ping = {
    AppClock.sched(0.0, { "[AC] ping ok @ % s".format(Main.elapsedTime.round(0.001)).postln; nil });
};

) // end block
