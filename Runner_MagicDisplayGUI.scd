(
// =========================
// Runner_MagicDisplayGUI.scd (single block, var-first everywhere)
// =========================

/*  Final one-button runner for MagicDisplayGUI tests
    - SC 3.14 macOS
    - All GUI work on AppClock
    - No server.sync
    - Style: tilde vars, var declarations first, lowercase names, no single-letter locals
    - Token-gated, re-entrant with auto-unlock
    - Detects stale windows, coalesces duplicates, ensures exactly one window
    - Provides:
        ~md_bootProbeScenario.()
        ~md_forceCreateWindow.()
        ~md_frontWindow.()
        ~md_checkWindows.()
        ~md_runnerUnlock.()
    - Light instrumentation tags: [RUN], [AC], [BOOT/AC], [WIN], [GUI], [SAFE]
*/

/* =========================
   basic env + guard
   ========================= */

~md_version = (
    runner: "Runner 1.0.1",
    mpb: "MagicPedalboardNew v0.3.8",
    md: "MagicDisplay v0.1.2",
    mdgui: "MagicDisplayGUI v0.2.4"
);

~md_guard = false;
~md_guard_time = nil;
~md_guard_timeout = 10.0; // seconds
~md_run_token = 0;

~md_log = { |text|
    var message;
    message = text.asString;
    message.postln;
};

~md_now = { Main.elapsedTime };

/* =========================
   window detection + control
   ========================= */

~md_window_title_match = { |window|
    var title;
    if(window.isNil) { ^false };
    if(window.respondsTo(\name) and: { window.name.notNil }) {
        title = window.name.asString;
    }{
        title = "";
    };
    ^title.contains("MagicDisplayGUI");
};

~md_get_gui_windows = {
    var all_windows, gui_windows;
    all_windows = Window.allWindows;
    if(all_windows.isNil) { all_windows = [] };
    gui_windows = all_windows.select({ |win_ref|
        ~md_window_title_match.(win_ref)
    });
    ^gui_windows;
};

~md_window_is_alive = { |window|
    var alive_flag, has_view;
    if(window.isNil) { ^false };
    alive_flag = true;
    if(window.respondsTo(\visible)) {
        alive_flag = alive_flag and: { window.visible };
    };
    has_view = window.respondsTo(\view) and: { window.view.notNil };
    alive_flag = alive_flag and: { has_view };
    ^alive_flag;
};

~md_close_windows = { |windows_to_close|
    var windows_list, count_closed;
    windows_list = windows_to_close ? [];
    count_closed = 0;
    AppClock.sched(0.0, {
        windows_list.do({ |win_ref|
            var alive_flag;
            alive_flag = ~md_window_is_alive.(win_ref);
            if(alive_flag) {
                "[WIN] closing window: %".format(win_ref.name).postln;
                win_ref.close;
                count_closed = count_closed + 1;
            }{
                "[WIN] stale window reference ignored".postln;
            };
        });
        "[WIN] closed % window(s)".format(count_closed).postln;
        nil
    });
};

~md_close_duplicate_windows = {
    var gui_windows, count, alive_flag;
    gui_windows = ~md_get_gui_windows.();
    count = gui_windows.size;

    if(count > 1) {
        "[WIN] duplicates detected (%). Closing all to rebuild cleanly.".format(count).postln;
        ~md_close_windows.(gui_windows);
    }{
        if(count == 1) {
            alive_flag = ~md_window_is_alive.(gui_windows[0]);
            if(alive_flag.not) {
                "[WIN] found stale/dead window. Closing to rebuild.".postln;
                ~md_close_windows.(gui_windows);
            }{
                "[WIN] one alive window found — eligible for reuse.".postln;
            };
        }{
            "[WIN] no existing MagicDisplayGUI windows found.".postln;
        };
    };
};

~md_frontWindow = {
    var gui_windows, front_target, previous_flag;
    gui_windows = ~md_get_gui_windows.();
    if(gui_windows.size == 0) { "[WIN] no MagicDisplayGUI window to front".postln; ^nil };
    front_target = gui_windows.last;

    AppClock.sched(0.0, {
        if(~md_window_is_alive.(front_target)) {
            previous_flag = front_target.alwaysOnTop;
            front_target.alwaysOnTop_(true);
            front_target.front;
            AppClock.sched(0.05, {
                front_target.alwaysOnTop_(previous_flag);
                nil
            });
            "[WIN] fronted window: %".format(front_target.name).postln;
        }{
            "[WIN] cannot front; target window not alive".postln;
        };
        nil
    });
};

/* =========================
   probe frame overlay (simple visible marker)
   ========================= */

~md_probe_view = nil;

~md_attach_probe_frame = {
    var gui_windows, target_window, root_view, bounds_rect, probe_view;
    gui_windows = ~md_get_gui_windows.();
    if(gui_windows.size == 0) { "[GUI] cannot attach PROBE FRAME (no window)".postln; ^nil };
    target_window = gui_windows.last;

    AppClock.sched(0.0, {
        if(~md_window_is_alive.(target_window).not) { "[GUI] window not alive; skipping PROBE FRAME".postln; ^nil };
        root_view = target_window.view;
        if(root_view.isNil) { "[GUI] root view missing; skipping PROBE FRAME".postln; ^nil };

        if(~md_probe_view.notNil) {
            (~md_probe_view.tryPerform(\remove) ? nil);
            ~md_probe_view = nil;
        };

        bounds_rect = Rect(8, 8, 180, 24);
        probe_view = UserView(root_view, bounds_rect)
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
    var created_flag;
    created_flag = false;
    if(~mpb.isNil) {
        "[BOOT] ~mpb missing — creating".postln;
        if(MagicPedalboardNew.respondsTo(\new)) {
            ~mpb = MagicPedalboardNew.new;
            created_flag = true;
        }{
            "[BOOT] MagicPedalboardNew.new not available".postln;
        };
    }{
        "[BOOT] ~mpb already present".postln;
    };
    if(created_flag) { "[BOOT] created ~mpb".postln; };
};

~md_try_open_gui_window = {
    var used_class_open, built_instance;
    used_class_open = false;
    built_instance = false;

    AppClock.sched(0.0, {
        if(MagicDisplayGUI.respondsTo(\open)) {
            "[BOOT/AC] MagicDisplayGUI.open".postln;
            MagicDisplayGUI.open;
            used_class_open = true;
        }{
            if(~gui.isNil or: { ~gui.isKindOf(MagicDisplayGUI).not }) {
                "[BOOT/AC] MagicDisplayGUI.new".postln;

                /* -----------------------------------------
                   If your GUI requires arguments, replace this with:
                       ~gui = MagicDisplayGUI.new(~mpb);
                ----------------------------------------- */
                ~gui = MagicDisplayGUI.new;

                built_instance = true;
            }{
                "[BOOT/AC] reusing ~gui".postln;
            };

            if(~gui.notNil) {
                if(~gui.respondsTo(\open)) {
                    "[BOOT/AC] ~gui.open".postln; ~gui.open;
                }{
                    if(~gui.respondsTo(\build)) {
                        "[BOOT/AC] ~gui.build".postln; ~gui.build;
                    }{
                        if(~gui.respondsTo(\front)) {
                            "[BOOT/AC] ~gui.front".postln; ~gui.front;
                        }{
                            "[BOOT/AC] relying on Window discovery".postln;
                        };
                    };
                };
            };
        };

        AppClock.sched(0.15, {
            var count;
            count = ~md_get_gui_windows.().size;
            "[WIN] post-open window count: %".format(count).postln;
            nil
        });

        nil
    });
};

~md_find_or_create_gui_window = { |on_ready_func, on_fail_func, expect_token|
    var attempts, attempt_func;
    attempts = 0;

    attempt_func = {
        var gui_windows, target_window, alive_flag;
        attempts = attempts + 1;

        ~md_close_duplicate_windows.();

        AppClock.sched(0.2, {
            gui_windows = ~md_get_gui_windows.();
            if(gui_windows.size == 1) {
                target_window = gui_windows[0];
                alive_flag = ~md_window_is_alive.(target_window);
                if(alive_flag) {
                    "[WIN] ready (1 alive window)".postln;
                    if(on_ready_func.notNil) { on_ready_func.value };
                }{
                    "[WIN] single window found but stale — closing and rebuilding".postln;
                    ~md_close_windows.([target_window]);
                    AppClock.sched(0.2, {
                        ~md_try_open_gui_window.();
                        AppClock.sched(0.3, attempt_func);
                        nil
                    });
                };
            }{
                if(gui_windows.size == 0) {
                    if(attempts <= 3) {
                        "[WIN] no window — attempting create (try %/3)".format(attempts).postln;
                        ~md_try_open_gui_window.();
                        AppClock.sched(0.3, attempt_func);
                    }{
                        "[WIN] failed to create window after retries".postln;
                        if(on_fail_func.notNil) { on_fail_func.value };
                    };
                }{
                    if(attempts <= 3) {
                        "[WIN] duplicates persisted — retrying coalesce (try %/3)".format(attempts).postln;
                        AppClock.sched(0.2, attempt_func);
                    }{
                        "[WIN] gave up coalescing duplicates".postln;
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
    var gui_windows, titles;
    gui_windows = ~md_get_gui_windows.();
    titles = gui_windows.collect({ |win_ref| win_ref.name.asString });
    "[WIN] count = %, titles = %".format(gui_windows.size, titles).postln;
};

~md_runnerUnlock = {
    var now_time;
    now_time = ~md_now.();
    if(~md_guard) { "[SAFE] manual unlock".postln };
    ~md_guard = false;
    ~md_guard_time = now_time;
};

~md_forceCreateWindow = {
    AppClock.sched(0.0, {
        "[RUN] force-create window".postln;
        ~md_close_duplicate_windows.();
        AppClock.sched(0.2, {
            ~md_try_open_gui_window.();
            AppClock.sched(0.35, {
                ~md_attach_probe_frame.();
                ~md_frontWindow.();
                nil
            });
            nil
        });
        nil
    });
};

/* =========================
   boot + scenario one-button
   ========================= */

~md_bootProbeScenario = {
    var now_time, guard_age, token, timeout_seconds, scenario_func;

    now_time = ~md_now.();
    guard_age = now_time - (~md_guard_time ? now_time);
    timeout_seconds = ~md_guard_timeout ? 10.0;

    if(~md_guard and: { guard_age > timeout_seconds }) {
        "[SAFE] auto-unlock due to stale guard (age: % s)".format(guard_age.round(0.01)).postln;
        ~md_runnerUnlock.();
    };

    if(~md_guard) {
        "[RUN] already running — ignoring new request".postln;
        ^nil;
    };

    ~md_guard = true;
    ~md_guard_time = now_time;
    ~md_run_token = (~md_run_token ? 0) + 1;
    token = ~md_run_token;

    "[RUN] start token % | % / % / %".format(token, ~md_version[\mpb], ~md_version[\md], ~md_version[\mdgui]).postln;

    AppClock.sched(timeout_seconds, {
        var still_active;
        still_active = ~md_guard and: { ~md_run_token == token };
        if(still_active) {
            "[SAFE] auto-unlock (timeout) token %".format(token).postln;
            ~md_runnerUnlock.();
        };
        nil
    });

    AppClock.sched(0.0, {
        "[AC] ensure ~mpb".postln;
        ~md_ensure_mpb.();

        "[AC] window build/find".postln;
        ~md_find_or_create_gui_window.({
            AppClock.sched(0.0, {
                ~md_attach_probe_frame.();
                ~md_frontWindow.();

                scenario_func = ~sc_fast_scenario1;
                if(scenario_func.notNil) {
                    "[RUN] starting Scenario 1 (fast)".postln;
                    scenario_func.({
                        "[RUN] Scenario 1 complete".postln;
                        ~md_runnerUnlock.();
                    });
                }{
                    "[RUN] Scenario 1 function (~sc_fast_scenario1) not found; unlocking".postln;
                    ~md_runnerUnlock.();
                };
                nil
            });
            nil
        }, {
            "[RUN] window creation failed; unlocking".postln;
            ~md_runnerUnlock.();
            nil
        }, token);

        nil
    });
};

/* =========================
   fallback shims (non-invasive)
   ========================= */

if(~refreshGuiFromMpb.isNil) {
    ~refreshGuiFromMpb = { |tag_text|
        var safe_tag;
        safe_tag = tag_text ? "no-tag";
        "[GUI] refreshGuiFromMpb (fallback) — %".format(safe_tag).postln;
    };
    "[INFO] installed fallback ~refreshGuiFromMpb (non-invasive)".postln;
};

/* =========================
   ready
   ========================= */
"[INFO] % loaded. Ready.".format(~md_version[\runner]).postln;

) // end block
