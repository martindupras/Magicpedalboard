(
// =========================
// Runner_MagicDisplayGUI.scd  (single block)
// =========================

/* Goals:
   - Exactly 1 MagicDisplayGUI window (close dupes; rebuild cleanly)
   - Visible PROBE FRAME overlay
   - Run Scenario 1 (fast) step-by-step
   - Re-entrant guard with auto-unlock; repeatable after closing the window
   - AppClock-only GUI operations; no server.sync; no watchers; no queueUi override
   - Style: tilde vars, var-first, lowercase names, no single-letter locals
*/

~md_version = (~md_version ? (
    runner: "Runner 1.0.3",
    mpb: "MagicPedalboardNew v0.3.8",
    md: "MagicDisplay v0.1.2",
    mdgui: "MagicDisplayGUI v0.2.4"
));

~md_guard = ~md_guard ? false;
~md_guard_time = ~md_guard_time ? nil;
~md_guard_timeout = ~md_guard_timeout ? 10.0;
~md_run_token = ~md_run_token ? 0;

/* ---------- preflight ---------- */

~md_preflightGui = {
    var did_set;
    did_set = false;
    GUI.qt;  // safe to call repeatedly; warning is cosmetic
    AppClock.sched(0.0, { "[AC] preflight ping".postln; nil });
    did_set = true;
    did_set
};

/* ---------- window helpers ---------- */

~md_title_is_mdg = { |window_ref|
    var ok, title_text, lower;
    ok = false;
    title_text = "";
    lower = "";
    if(window_ref.notNil) {
        if(window_ref.respondsTo(\name) and: { window_ref.name.notNil }) {
            title_text = window_ref.name.asString;
            lower = title_text.toLower;
            ok = (
                lower.contains("magicdisplaygui")
                or: { lower.contains("current / next") }
                or: { lower.contains("magic display") }
            );
        };
    };
    ok
};

~md_all_windows = {
    var wins;
    wins = Window.allWindows;
    if(wins.isNil) { wins = [] };
    wins
};

~md_get_gui_windows = {
    var wins, mdg;
    wins = ~md_all_windows.();
    mdg = wins.select({ |w| ~md_title_is_mdg.(w) });
    mdg
};

~md_checkWindows = {
    var wins, titles;
    wins = ~md_all_windows.();
    titles = wins.collect({ |w| w.name.asString });
    "[WIN] ALL count = %, titles = %".format(wins.size, titles).postln;
};

~md_close_matching_windows = {
    var wins;
    wins = ~md_all_windows.();
    AppClock.sched(0.0, {
        var to_close, count_closed;
        to_close = wins.select({ |w| ~md_title_is_mdg.(w) });
        count_closed = 0;
        to_close.do({ |w|
            if(w.notNil) {
                w.close;
                count_closed = count_closed + 1;
            };
        });
        "[WIN] closed % MagicDisplayGUI window(s)".format(count_closed).postln;
        nil
    });
};

~md_frontWindow = {
    var wins, target, prev_flag, has_top;
    wins = ~md_all_windows.();
    if(wins.size == 0) {
        "[WIN] nothing to front".postln;
    }{
        target = wins.last;
        AppClock.sched(0.0, {
            has_top = target.respondsTo(\alwaysOnTop);
            if(has_top) {
                prev_flag = target.alwaysOnTop;
                target.alwaysOnTop_(true);
            };
            target.front;
            if(has_top) {
                AppClock.sched(0.05, { target.alwaysOnTop_(prev_flag); nil });
            };
            "[WIN] fronted: %".format(target.name).postln;
            nil
        });
    };
};

/* ---------- PROBE FRAME overlay ---------- */

~md_probe_view = ~md_probe_view ? nil;

~md_attach_probe_frame = {
    var wins, target, root, bounds_rect, view_local, font_obj;
    wins = ~md_all_windows.();
    if(wins.size == 0) {
        "[GUI] PROBE skipped (no windows)".postln;
    }{
        target = wins.last;
        AppClock.sched(0.0, {
            if(target.view.isNil) {
                "[GUI] PROBE skipped (no root view)".postln;
            }{
                if(~md_probe_view.notNil) {
                    (~md_probe_view.tryPerform(\remove) ? nil);
                    ~md_probe_view = nil;
                };
                root = target.view;
                bounds_rect = Rect(8, 8, 180, 24);
                font_obj = Font("Helvetica", 12);
                view_local = UserView(root, bounds_rect).background_(Color.clear).clearOnRefresh_(true);
                view_local.drawFunc_({
                    Pen.color_(Color.red); Pen.width = 1.5;
                    Pen.addRect(Rect(0, 0, bounds_rect.width, bounds_rect.height)); Pen.stroke;
                    Pen.stringAtPoint("PROBE FRAME", Point(6, 6), font_obj);
                });
                view_local.visible_(true);
                ~md_probe_view = view_local;
                "[GUI] PROBE FRAME attached".postln;
            };
            nil
        });
    };
};

/* ---------- ensure ~mpb exists (best-effort; no server.sync) ---------- */

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

/* ---------- public API ---------- */

~md_runnerUnlock = {
    var now_time;
    now_time = Main.elapsedTime;
    if(~md_guard) { "[SAFE] manual unlock".postln };
    ~md_guard = false;
    ~md_guard_time = now_time;
};

/* Emergency fresh-create + front + probe (deterministic) */
~md_forceCreateWindow = {
    AppClock.sched(0.0, {
        "[RUN] force-create window".postln;
        ~md_preflightGui.();
        ~md_close_matching_windows.();
        AppClock.sched(0.20, {
            // Correct constructor for your GUI: no args; builds on AppClock inside initGui
            "[BOOT] calling MagicDisplayGUI.new()".postln;
            ~gui = MagicDisplayGUI.new();
            AppClock.sched(0.45, {
                ~md_attach_probe_frame.();
                ~md_frontWindow.();
                ~md_checkWindows.();
                nil
            });
            nil
        });
        nil
    });
};

~md_bootProbeScenario = {
    var now_time, guard_age, timeout_seconds, token_local, scenario_func;

    ~md_preflightGui.();

    now_time = Main.elapsedTime;
    guard_age = now_time - (~md_guard_time ? now_time);
    timeout_seconds = ~md_guard_timeout ? 10.0;

    if(~md_guard and: { guard_age > timeout_seconds }) {
        "[SAFE] auto-unlock (stale)".postln;
        ~md_runnerUnlock.();
    };

    if(~md_guard) {
        "[RUN] already running — ignoring".postln;
    }{
        ~md_guard = true;
        ~md_guard_time = now_time;
        ~md_run_token = (~md_run_token ? 0) + 1;
        token_local = ~md_run_token;

        "[RUN] start token % | % / % / %".format(
            token_local, ~md_version[\mpb], ~md_version[\md], ~md_version[\mdgui]
        ).postln;

        // failsafe auto-unlock
        AppClock.sched(timeout_seconds, {
            var still_active;
            still_active = ~md_guard and: { ~md_run_token == token_local };
            if(still_active) {
                "[SAFE] auto-unlock (timeout)".postln;
                ~md_runnerUnlock.();
            };
            nil
        });

        // ensure env + window, then run Scenario 1 (fast)
        ~md_ensure_mpb.();
        ~md_forceCreateWindow.();
        AppClock.sched(0.90, {
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
    };
};

/* ---------- safe fallback for refresh (non-invasive) ---------- */

if(~refreshGuiFromMpb.isNil) {
    ~refreshGuiFromMpb = { |tag_text|
        var safe_tag;
        safe_tag = tag_text ? "no-tag";
        "[GUI] refreshGuiFromMpb (fallback) — %".format(safe_tag).postln;
    };
    "[INFO] installed fallback ~refreshGuiFromMpb (non-invasive)".postln;
};

"[INFO] % loaded. Ready.".format(~md_version[\runner]).postln;

) // end block
