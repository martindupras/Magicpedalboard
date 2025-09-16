(
// =========================
// Scenarios_MagicDisplayGUI_Fast.scd  (single block)
// =========================
// AppClock-only; uses ~gui.queueUi if present; updates via ~refreshGuiFromMpb + showExpectation

~md_with_queue_ui = { |ui_func|
    var runnable_func, has_queue;
    runnable_func = ui_func ? { };
    has_queue = (~gui.notNil) and: { ~gui.respondsTo(\queueUi) };
    if(has_queue) { ~gui.queueUi.(runnable_func) }{ "[GUI] queueUi unavailable — skipping ui_func".postln };
};

// -------- Scenario 1 (fast) --------
~sc_fast_scenario1 = { |done_func|
    var step_interval, carry_on;
    step_interval = 0.25;
    carry_on = { |next_func| AppClock.sched(step_interval, { next_func.value; nil }) };

    AppClock.sched(0.0, {
        ~md_with_queue_ui.({
            if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 0") };
        });
        ~refreshGuiFromMpb.("sc1-step0");
        nil
    });

    carry_on.({
        ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 1") } });
        ~refreshGuiFromMpb.("sc1-step1");

        carry_on.({
            ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 2") } });
            ~refreshGuiFromMpb.("sc1-step2");

            carry_on.({
                ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 3") } });
                ~refreshGuiFromMpb.("sc1-step3");

                carry_on.({
                    ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: step 4") } });
                    ~refreshGuiFromMpb.("sc1-step4");

                    carry_on.({
                        ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 1: done") } });
                        ~refreshGuiFromMpb.("sc1-done");
                        if(done_func.notNil) { done_func.value };
                    });
                });
            });
        });
    });
};

// -------- Scenario 2 (fast) --------
~sc_fast_scenario2 = { |done_func|
    var step_interval;
    step_interval = 0.2;

    AppClock.sched(0.0, {
        ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 2: A-chain preview") } });
        ~refreshGuiFromMpb.("sc2-A");

        AppClock.sched(step_interval, {
            ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 2: B-chain preview") } });
            ~refreshGuiFromMpb.("sc2-B");

            AppClock.sched(step_interval, {
                ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 2: done") } });
                ~refreshGuiFromMpb.("sc2-done");
                if(done_func.notNil) { done_func.value };
                nil
            });
            nil
        });
        nil
    });
};

// -------- Scenario 3 (fast) --------
~sc_fast_scenario3 = { |done_func|
    var step_interval, index_counter, rounds_total, do_round;
    step_interval = 0.18;
    index_counter = 0;
    rounds_total = 5;

    AppClock.sched(0.0, {
        do_round = {
            if(index_counter >= rounds_total) {
                ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 3: done") } });
                ~refreshGuiFromMpb.("sc3-done");
                if(done_func.notNil) { done_func.value };
            }{
                ~md_with_queue_ui.({ if(~gui.respondsTo(\showExpectation)) { ~gui.showExpectation.("Scenario 3: tick %".format(index_counter)) } });
                ~refreshGuiFromMpb.("sc3-%".format(index_counter));
                index_counter = index_counter + 1;
                AppClock.sched(step_interval, { do_round.value; nil });
            };
            nil
        };
        do_round.value;
        nil
    });
};

) // end block
