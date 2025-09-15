(
// Scenarios_MagicDisplayGUI_Fast.scd
// Fast Scenario 1/2/3 — AppClock per step, no watchers
// Uses ~refreshGuiFromMpb + ~gui.showExpectation via ~gui.queueUi
// Style: tilde vars, var-first, lowercase, no single-letter locals
~md_with_queue_ui = { |ui_func|
    var runnable, has_gui, can_queue;
    runnable = ui_func ? { };
    has_gui = ~gui.notNil;
    can_queue = has_gui and: { ~gui.respondsTo(\queueUi) };
    if(can_queue) {
        ~gui.queueUi.(runnable);
    }{
        "[GUI] queueUi unavailable — skipping ui_func".postln;
    };
};

// -------- Scenario 1 (fast): visible step-by-step updates --------
~sc_fast_scenario1 = { |done_func|
    var step_interval, schedule_next;

    step_interval = 0.25;
    schedule_next = { |func_to_run|
        var next_func;
        next_func = func_to_run ? { };
        AppClock.sched(step_interval, { next_func.value; nil });
    };

    AppClock.sched(0.0, {
        ~md_with_queue_ui.({
            if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 0"); };
        });
        ~refreshGuiFromMpb.("sc1-step0");

        schedule_next.({
            ~md_with_queue_ui.({
                if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 1"); };
            });
            ~refreshGuiFromMpb.("sc1-step1");

            schedule_next.({
                ~md_with_queue_ui.({
                    if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 2"); };
                });
                ~refreshGuiFromMpb.("sc1-step2");

                schedule_next.({
                    ~md_with_queue_ui.({
                        if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 3"); };
                    });
                    ~refreshGuiFromMpb.("sc1-step3");

                    schedule_next.({
                        ~md_with_queue_ui.({
                            if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 4"); };
                        });
                        ~refreshGuiFromMpb.("sc1-step4");

                        schedule_next.({
                            ~md_with_queue_ui.({
                                if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: done"); };
                            });
                            ~refreshGuiFromMpb.("sc1-done");
                            if(done_func.notNil) { done_func.value };
                        });
                    });
                });
            });
        });
        nil
    });
};

// -------- Scenario 2 (fast): brief A/B hint without audio --------
~sc_fast_scenario2 = { |done_func|
    var step_interval;
    step_interval = 0.2;

    AppClock.sched(0.0, {
        ~md_with_queue_ui.({
            if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 2: A-chain preview"); };
        });
        ~refreshGuiFromMpb.("sc2-A");

        AppClock.sched(step_interval, {
            ~md_with_queue_ui.({
                if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 2: B-chain preview"); };
            });
            ~refreshGuiFromMpb.("sc2-B");

            AppClock.sched(step_interval, {
                ~md_with_queue_ui.({
                    if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 2: done"); };
                });
                ~refreshGuiFromMpb.("sc2-done");
                if(done_func.notNil) { done_func.value };
                nil
            });

            nil
        });

        nil
    });
};

// -------- Scenario 3 (fast): mini churn --------
~sc_fast_scenario3 = { |done_func|
    var step_interval, index, rounds;

    step_interval = 0.18;
    index = 0;
    rounds = 5;

    AppClock.sched(0.0, {
        var do_round;
        do_round = {
            if(index >= rounds) {
                ~md_with_queue_ui.({
                    if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 3: done"); };
                });
                ~refreshGuiFromMpb.("sc3-done");
                if(done_func.notNil) { done_func.value };
            }{
                ~md_with_queue_ui.({
                    if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 3: tick %".format(index)); };
                });
                ~refreshGuiFromMpb.("sc3-%".format(index));
                index = index + 1;
                AppClock.sched(step_interval, { do_round.value; nil });
            };
        };
        do_round.value;
        nil
    });
};
)
