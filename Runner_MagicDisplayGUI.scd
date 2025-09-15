(
// =========================
// Runner_MagicDisplayGUI.scd (wrapped in one block)
// =========================

/*  Final one-button runner for MagicDisplayGUI tests
    - SC 3.14 macOS
    - All GUI work on AppClock
    - No server.sync
    - Style: tilde vars, var declarations first, lowercase names, no single-letter vars
    - Token-gated, re-entrant with auto-unlock
    - Detects stale windows, coalesces duplicates, ensures exactly one window
    - Provides:
        ~md_bootProbeScenario.()
        ~md_forceCreateWindow.()
        ~md_frontWindow.()
        ~md_checkWindows.()
        ~md_runnerUnlock.()
*/

/* =========================
   basic env + guard
   ========================= */

~md_version = (
    runner: "Runner 1.0.0",
    mpb: "MagicPedalboardNew v0.3.8",
    md: "MagicDisplay v0.1.2",
    mdgui: "MagicDisplayGUI v0.2.4"
);

~md_guard = false;
~md_guard_time = nil;
~md_guard_timeout = 10.0; // seconds
~md_run_token = 0;

~md_log = { |text| text.asString.postln };
~md_now = { Main.elapsedTime };

/* =========================
   window detection + control
   ========================= */

~md_window_title_match = { |window|
    var title;
    if(window.isNil) { ^false };
    title = (window.respondsTo(\name) and: { window.name.notNil }) .if({ window.name.asString }, { "" });
    ^title.contains("MagicDisplayGUI");
};

~md_get_gui_windows = {
    var all_windows = Window.allWindows ? [];
    ^all_windows.select({ |win| ~md_window_title_match.(win) });
};

~md_window_is_alive = { |window|
    if(window.isNil) { ^false };
    ^(window.respondsTo(\visible).if({ window.visible }, { true })
        and: { window.respondsTo(\view) and: { window.view.notNil } });
};

~md_close_windows = { |windows_to_close|
    AppClock.sched(0.0, {
        windows_to_close.do({ |win_ref|
            if(~md_window_is_alive.(win_ref)) {
                "[WIN] closing window: %".format(win_ref.name).postln;
                win_ref.close;
            }{
                "[WIN] stale window reference ignored".postln;
            };
        });
        nil
    });
};

~md_close_duplicate_windows = {
    var gui_windows = ~md_get_gui_windows.();
    if(gui_windows.size > 1) {
        "[WIN] duplicates detected (%). Closing all.".format(gui_windows.size).postln;
        ~md_close_windows.(gui_windows);
    }{
        if(gui_windows.size == 1 and: { ~md_window_is_alive.(gui_windows[0]).not }) {
            "[WIN] stale window found. Closing.".postln;
            ~md_close_windows.(gui_windows);
        };
    };
};

~md_frontWindow = {
	var gui_windows, front_target;
    gui_windows = ~md_get_gui_windows.();
    if(gui_windows.size == 0) { "[WIN] no window to front".postln; ^nil };
    front_target = gui_windows.last;
    AppClock.sched(0.0, {
		var previous;
        if(~md_window_is_alive.(front_target)) {
            previous = front_target.alwaysOnTop ? false : true;
            front_target.alwaysOnTop_(true);
            front_target.front;
            AppClock.sched(0.05, { front_target.alwaysOnTop_(previous); nil });
            "[WIN] fronted window: %".format(front_target.name).postln;
        };
        nil
    });
};

/* =========================
   probe frame overlay
   ========================= */

~md_probe_view = nil;

~md_attach_probe_frame = {
    var gui_windows = ~md_get_gui_windows.();
    if(gui_windows.size == 0) { "[GUI] cannot attach PROBE FRAME".postln; ^nil };
    var target_window = gui_windows.last;
    AppClock.sched(0.0, {
        if(~md_window_is_alive.(target_window).not) { ^nil };
        var root_view = target_window.view;
        if(root_view.isNil) { ^nil };
        if(~md_probe_view.notNil) { (~md_probe_view.tryPerform(\remove) ? nil); ~md_probe_view = nil };
        var bounds_rect = Rect(8, 8, 180, 24);
        var probe_view = UserView(root_view, bounds_rect)
            .background_(Color.clear)
            .clearOnRefresh_(true);
        probe_view.drawFunc_({
            Pen.color_(Color.red);
            Pen.width = 1.5;
            Pen.addRect(Rect(0, 0, bounds_rect.width, bounds_rect.height));
            Pen.stroke;
            Pen.color_(Color.red);
            Pen.stringAtPoint("PROBE FRAME", Point(6, 6), Font("Helvetica", 12));
        });
        probe_view.visible_(true);
        ~md_probe_view = probe_view;
        "[GUI] PROBE FRAME attached".postln;
        nil
    });
};

/* =========================
   ensuring mpb + gui build
   ========================= */

~md_ensure_mpb = {
    if(~mpb.isNil) {
        "[BOOT] ~mpb missing — creating".postln;
        if(MagicPedalboardNew.respondsTo(\new)) { ~mpb = MagicPedalboardNew.new };
    }{
        "[BOOT] ~mpb already present".postln;
    };
};

~md_try_open_gui_window = {
    AppClock.sched(0.0, {
        if(MagicDisplayGUI.respondsTo(\open)) {
            "[BOOT/AC] MagicDisplayGUI.open".postln;
            MagicDisplayGUI.open;
        }{
            if(~gui.isNil or: { ~gui.isKindOf(MagicDisplayGUI).not }) {
                "[BOOT/AC] MagicDisplayGUI.new".postln;
                ~gui = MagicDisplayGUI.new; // <-- Replace with MagicDisplayGUI.new(~mpb) if needed
            };
            if(~gui.respondsTo(\open)) { ~gui.open }{ if(~gui.respondsTo(\build)) { ~gui.build } };
        };
        AppClock.sched(0.15, { "[WIN] post-open window count: %".format(~md_get_gui_windows.().size).postln; nil });
        nil
    });
};

~md_find_or_create_gui_window = { |on_ready_func, on_fail_func, expect_token|
    var attempts = 0;
    var attempt_func;
    attempt_func = {
        attempts = attempts + 1;
        ~md_close_duplicate_windows.();
        AppClock.sched(0.2, {
            var gui_windows = ~md_get_gui_windows.();
            if(gui_windows.size == 1 and: { ~md_window_is_alive.(gui_windows[0]) }) {
                "[WIN] ready (1 alive window)".postln;
                if(on_ready_func.notNil) { on_ready_func.value };
            }{
                if(gui_windows.size == 0 and: { attempts <= 3 }) {
                    "[WIN] no window — attempting create (try %/3)".format(attempts).postln;
                    ~md_try_open_gui_window.();
                    AppClock.sched(0.3, attempt_func);
                }{
                    if(attempts > 3) {
                        "[WIN] failed to create window".postln;
                        if(on_fail_func.notNil) { on_fail_func.value };
                    };
                };
            };
            nil
        });
    };
    AppClock.sched(0.0, attempt_func);
};

/* =========================
   public helpers
   ========================= */

~md_checkWindows = {
    var gui_windows = ~md_get_gui_windows.();
    "[WIN] count = %, titles = %".format(gui_windows.size, gui_windows.collect(_.name.asString)).postln;
};

~md_runnerUnlock = {
    if(~md_guard) { "[SAFE] manual unlock".postln };
    ~md_guard = false;
    ~md_guard_time = ~md_now.();
};

~md_forceCreateWindow = {
    AppClock.sched(0.0, {
        "[RUN] force-create window".postln;
        ~md_close_duplicate_windows.();
        AppClock.sched(0.2, {
            ~md_try_open_gui_window.();
            AppClock.sched(0.35, { ~md_attach_probe_frame.(); ~md_frontWindow.(); nil });
            nil
        });
        nil
    });
};

/* =========================
   boot + scenario one-button
   ========================= */

~md_bootProbeScenario = {
    var now_time = ~md_now.();
    var guard_age = now_time - (~md_guard_time ? now_time);
    if(~md_guard and: { guard_age > (~md_guard_timeout ? 10.0) }) {
        "[SAFE] auto-unlock (stale)".postln; ~md_runnerUnlock.();
    };
    if(~md_guard) { "[RUN] already running — ignoring".postln; ^nil };
    ~md_guard = true; ~md_guard_time = now_time; ~md_run_token = (~md_run_token ? 0) + 1;
    var token = ~md_run_token;
    "[RUN] start token %".format(token).postln;
    AppClock.sched((~md_guard_timeout ? 10.0), {
        if(~md_guard and: { ~md_run_token == token }) { "[SAFE] auto-unlock (timeout)".postln; ~md_runnerUnlock.() };
        nil
    });
    AppClock.sched(0.0, {
        "[AC] ensure ~mpb".postln; ~md_ensure_mpb.();
        "[AC] window build/find".postln;
        ~md_find_or_create_gui_window.({
            ~md_attach_probe_frame.();
            ~md_frontWindow.();
            if(~sc_fast_scenario1.notNil) {
                "[RUN] starting Scenario 1".postln;
                ~sc_fast_scenario1.({ "[RUN] Scenario 1 complete".postln; ~md_runnerUnlock.() });
            }{
                "[RUN] no Scenario 1; unlocking".postln; ~md_runnerUnlock.();
            };
            nil
        }, {
            "[RUN] window creation failed; unlocking".postln; ~md_runnerUnlock.();
            nil
        }, token);
        nil
    });
};

/* fallback for ~refreshGuiFromMpb */
if(~refreshGuiFromMpb.isNil) {
    ~refreshGuiFromMpb = { |tag| "[GUI] refreshGuiFromMpb (fallback) — %".format(tag ? "no-tag").postln };
    "[INFO] installed fallback ~refreshGuiFromMpb".postln;
};

"[INFO] Runner loaded. Ready.".postln;

) // end of block
