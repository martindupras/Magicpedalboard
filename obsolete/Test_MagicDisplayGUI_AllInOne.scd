/*
 * Test_MagicDisplayGUI_AllInOne.scd
 * Loads your three existing test files in order, then applies a resilient
 * UI-queue immediate patch so scenarios don’t stall after [SC] init.
 *
 * Conventions respected:
 * - var-first in every block
 * - tilde interpreter vars with lowercase initial (existing names kept: ~bootGuiV4, ~scenario1v5, ~probeGuiV2)
 * - no single-letter locals
 * - no server.sync; UI work is on AppClock via .defer
 * - convenience aliases expose v6 names for the session
 */

(
// -----------------------------
// section 0: setup + utilities
// -----------------------------
var basePath, fileNames, loaded, loadOne, report,
    waitAndPatchQueueUiImmediate, applyQueueUiPatch,
    makeAliases, goRunner;

basePath = thisProcess.nowExecutingPath.asString.dirname;
fileNames = [
    "Test_MagicDisplayGUI_BootAndScenarios.scd",
    "Test_MagicDisplayGUI_Scenarios.scd",
    "Test_MagicDisplayGUI_InlineInstrument.scd"
];
loaded = IdentityDictionary.new;

report = { |messageString|
    ("[ALL-IN-ONE] " ++ messageString).postln;
};

// Try to load a file by name from the same folder as this script.
loadOne = { |nameString|
    var fullPath, didLoad;
    didLoad = false;
    fullPath = basePath +/+ nameString;
    if(PathName(fullPath).isFile) {
        report.("Loading " ++ nameString ++ " …");
        thisProcess.interpreter.executeFile(fullPath);
        didLoad = true;
        loaded[nameString] = true;
        report.("Loaded " ++ nameString);
    }{
        report.("NOT FOUND beside this script: " ++ nameString);
    };
    didLoad
};

// -----------------------------------------------
// section 1: load your three files in the order
// -----------------------------------------------
fileNames.do({ |nameString|
    var didLoadLocal, altPath;
    didLoadLocal = loadOne.(nameString);
    if(didLoadLocal.not) {
        // Try also current working directory as a fallback.
        altPath = PathName(nameString);
        if(altPath.isFile) {
            report.("Loading from current dir: " ++ nameString);
            thisProcess.interpreter.executeFile(altPath.fullPath);
            loaded[nameString] = true;
            report.("Loaded " ++ nameString);
        }{
            // Stop early with a clear message; keeps behavior explicit.
            Error(
                "[ALL-IN-ONE] Could not locate required file: " ++ nameString
                ++ "\nPlace this AllInOne file next to your three test files and re-evaluate."
            ).throw;
        };
    };
});

// --------------------------------------------------------------------
// section 2: resilient UI-queue patch helpers
// --------------------------------------------------------------------
applyQueueUiPatch = {
    var applied;
    applied = false;

    if(~magicDisplay.notNil) {
        // Preferred: dictionary-style if it's an Event/Dictionary-like object
        if(~magicDisplay.respondsTo(\atPut)) {
            ~magicDisplay[\queueUi] = { |ignoredSelf, fun| fun.defer };
            applied = true;
        }{
            // Fallback: setter method if the object has a queueUi_ slot
            if(~magicDisplay.respondsTo(\queueUi_)) {
                ~magicDisplay.queueUi = { |selfArg, fun| fun.defer };
                applied = true;
            };
        };

        if(applied) {
            report.("UI patch applied: queueUi now runs immediate on AppClock (.defer).");
            // Small proof-of-life, only if it can be called like a method:
            if(~magicDisplay.respondsTo(\queueUi)) {
                ~magicDisplay.queueUi({ "[CHECK] queueUi immediate hit".postln });
            }{
                // Or if it is dictionary-like:
                if(~magicDisplay.respondsTo(\at)) {
                    var qf;
                    qf = ~magicDisplay[\queueUi];
                    if(qf.isKindOf(Function)) { qf.value(~magicDisplay, { "[CHECK] queueUi immediate hit".postln }); };
                };
            };
        }{
            report.("UI patch: ~magicDisplay exists but exposes neither atPut nor queueUi_. Not patched.");
        };
    }{
        report.("UI patch: ~magicDisplay is nil; boot first.");
    };

    applied
};

waitAndPatchQueueUiImmediate = {
    var attempts, maxAttempts, stepSeconds, routineInstance, applied;

    attempts = 0;
    maxAttempts = 200;     // ~10 seconds total at 0.05s steps
    stepSeconds = 0.05;

    routineInstance = Routine({
        report.("UI patch: waiting for ~magicDisplay …");
        while({ attempts < maxAttempts }, {
            if(~magicDisplay.notNil) {
                applied = applyQueueUiPatch.();
                if(applied) {
                    // stop the routine cleanly
                    thisThread.stop;
                }{
                    // ~magicDisplay present but no slot yet (maybe constructor still building)
                    // wait a moment and retry
                };
            };
            attempts = attempts + 1;
            stepSeconds.wait;
        });
        report.("UI patch: ~magicDisplay did not appear in time; you can run ~md_waitAndPatchQueueUiImmediate.() again after boot.");
    }).play(AppClock);

    routineInstance
};

// --------------------------------------------------------------
// section 3: convenience aliases and an optional one-button run
// --------------------------------------------------------------
makeAliases = {
    var messages;
    messages = List.new;
    if(thisProcess.interpreter.hasVar(\bootGuiV4)) {
        ~bootGuiV6 = { ~bootGuiV4.value; };
        messages.add("~bootGuiV6 → ~bootGuiV4");
    };
    if(thisProcess.interpreter.hasVar(\scenario1v5)) {
        ~scenario1v6 = { ~scenario1v5.value; };
        messages.add("~scenario1v6 → ~scenario1v5");
    };
    if(thisProcess.interpreter.hasVar(\probeGuiV2)) {
        ~probeGuiV3 = { ~probeGuiV2.value; };
        messages.add("~probeGuiV3 → ~probeGuiV2");
    };

    if(messages.isEmpty) {
        report.("No known functions found to alias. Ensure your three files defined ~bootGuiV4, ~scenario1v5, ~probeGuiV2.");
    }{
        report.("Aliases established: " ++ messages.asArray.join(", "));
    };
};

// Optional: boots GUI, applies patch, runs probe, then scenario.
goRunner = {
    var bootTask;
    bootTask = Task({
        report.("Booting GUI (v6 aliases)…");
        if(thisProcess.interpreter.hasVar(\bootGuiV6)) {
            ~bootGuiV6.(); // your original boot runs here
        }{
            Error("[ALL-IN-ONE] ~bootGuiV6 missing; check that ~bootGuiV4 exists in your loaded files.").throw;
        };

        // Apply the patch as soon as ~magicDisplay is present
        waitAndPatchQueueUiImmediate.();

        // Give the GUI a moment to open and print "Window ready…" (non-blocking)
        0.5.wait;

        if(thisProcess.interpreter.hasVar(\probeGuiV3)) {
            report.("Running probe (~probeGuiV3)…");
            ~probeGuiV3.();
        }{
            report.("Skipping probe; ~probeGuiV3 not defined.");
        };

        // Small gap so probe logs show up clearly
        0.2.wait;

        if(thisProcess.interpreter.hasVar(\scenario1v6)) {
            report.("Running scenario (~scenario1v6)…");
            ~scenario1v6.();
        }{
            report.("Skipping scenario; ~scenario1v6 not defined.");
        };
    });

    bootTask.start;
    bootTask
};

// finalize setup for this session
makeAliases.();
~md_waitAndPatchQueueUiImmediate = waitAndPatchQueueUiImmediate; // expose utility
~md_applyQueueUiPatch = applyQueueUiPatch; // expose direct patch if you need it
~md_go = goRunner; // convenience one-button runner

report.("Ready. Typical flow:\n"++
    "  1) ~bootGuiV6.();\n"++
    "  2) ~md_waitAndPatchQueueUiImmediate.();  // applies as soon as ~magicDisplay exists\n"++
    "  3) ~probeGuiV3.();\n"++
    "  4) ~scenario1v6.();\n"++
    "Or just run: ~md_go.();"
);
)
