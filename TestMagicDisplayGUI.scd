(
// TestMagicDisplayGUI.scd v0.2.4 — visual test harness (no server required)
// Follows Martin's SC style: tilde vars, var-first, lowercase method names, no server.sync.

~mdgReset = {
    var keys;
    keys = [\mdgTask, \mdgState, \applyCmd, \mdgShow, \runSequence,
        \startScenario1, \startScenario2, \startScenario3, \stopScenarios];
    keys.do { |key| thisEnvironment.removeAt(key) };
};

~mdgInit = {
    var state;

    // --- state model (A/B chains with active/edit roles)
    state = (
        chainA: [\guitar, \destination],
        chainB: [\guitar, \destination],
        active: \chainA,     // which chain is currently "active" (shown as ACTIVE)
        edit: \chainB        // which chain is currently being edited (NEXT)
    );
    ~mdgState = state;

    // --- one unified 'show' that uses GUI if present, else console
    ~mdgShow = { |sourceName, commandArr, chainArr|
        var classObj, gui;
        classObj = \MagicDisplayGUI.asClass;  // safe: resolves to nil if class not compiled
        if(classObj.notNil) {
            gui = classObj.instance;
            if(gui.notNil and: { gui.respondsTo(\showMutation) }) {
                gui.showMutation(sourceName, commandArr, chainArr);
            }{
                ("MagicDisplayGUI found but showMutation is missing → " ++
                    [sourceName, commandArr, chainArr]).postln;
            };
        }{
            ("[Console only] " ++ sourceName ++ " → " ++
                commandArr.asString ++ " | chain: " ++ chainArr.asString).postln;
        };
    };

    // --- simple chain simulator for GUI-driving (no audio, just lists)
    ~applyCmd = { |commandArr|
        var first, arg1, arg2;
        var st, activeSym, editSym, editChain;

        st = ~mdgState;
        first = commandArr[0];
        arg1 = commandArr[1];
        arg2 = commandArr[2];

        activeSym = st[\active];
        editSym   = st[\edit];
        editChain = st[editSym];

        if(first == \switchChain) {
            st[\active] = editSym;
            st[\edit]   = activeSym;
        }{
            if(first == \addProc) {
                st[editSym] = editChain ++ [arg1];
            }{
                if(first == \removeProc) {
                    st[editSym] = editChain.reject { |procSym| procSym == arg1 };
                }{
                    if(first == \resetChain) {
                        st[editSym] = [\guitar, \destination];
                    }{
                        // bypassProc or unknown: no structural change, still show mutation
                        nil;
                    };
                };
            };
        };

        // Return the *currently active* chain for display after this mutation
        st[ st[\active] ];
    };

    // --- runs a sequence of commands against the simulator and the GUI
    ~runSequence = { |sourceName, commands, stepSeconds=0.8|
        var routine;
        routine = Routine {
            var chainAfter, cmdIndex, cmd;
            cmdIndex = 0;
            commands.do { |commandItem|
                cmdIndex = cmdIndex + 1;
                cmd = commandItem;
                chainAfter = ~applyCmd.(cmd);
                ~mdgShow.(sourceName, cmd, chainAfter);
                stepSeconds.wait;
            };
        };
        ~mdgTask.notNil.if { ~mdgTask.stop };
        ~mdgTask = Task(routine, AppClock).play;
    };

    // --- Scenario 1: basic happy path (A/B edit + switch + reset)
    ~startScenario1 = {
        var commands;
        commands = [
            [\switchChain, \chainB],
            [\addProc, \flanger],
            [\bypassProc, \flanger, true],
            [\addProc, \delay],
            [\switchChain, \chainA],
            [\resetChain]
        ];

        ~mdgState[\chainA] = [\guitar, \destination];
        ~mdgState[\chainB] = [\guitar, \destination];
        ~mdgState[\active] = \chainA;
        ~mdgState[\edit]   = \chainB;

        ~runSequence.("test", commands, 0.8);
    };

    // --- Scenario 2: rapid updates / longer chain stress
    ~startScenario2 = {
        var commands;
        commands = [
            [\switchChain, \chainB],
            [\addProc, \chorus],
            [\addProc, \reverb],
            [\addProc, \tremolo],
            [\removeProc, \chorus],
            [\addProc, \phaser],
            [\switchChain, \chainA],
            [\resetChain]
        ];

        ~mdgState[\chainA] = [\guitar, \destination];
        ~mdgState[\chainB] = [\guitar, \destination];
        ~mdgState[\active] = \chainA;
        ~mdgState[\edit]   = \chainB;

        ~runSequence.("stress", commands, 0.2);
    };

    // --- Scenario 3: edge cases (unknown command, no-op remove, empty cmd)
    ~startScenario3 = {
        var commands;
        commands = [
            [\switchChain, \chainB],
            [\unknownCommand, \foo],
            [\addProc, \bitcrusher],
            [\bypassProc, \bitcrusher, false],
            [\removeProc, \nonexistent],
            [\switchChain, \chainA],
            [\resetChain],
            []
        ];

        ~mdgState[\chainA] = [\guitar, \destination];
        ~mdgState[\chainB] = [\guitar, \destination];
        ~mdgState[\active] = \chainA;
        ~mdgState[\edit]   = \chainB;

        ~runSequence.("edge", commands, 0.6);
    };

    // --- stop/cleanup (also tries to close the GUI if it supports .close)
    ~stopScenarios = {
        var classObj, gui;
        ~mdgTask.notNil.if { ~mdgTask.stop; ~mdgTask = nil; };
        classObj = \MagicDisplayGUI.asClass;
        if(classObj.notNil) {
            gui = classObj.instance;
            if(gui.notNil and: { gui.respondsTo(\close) }) {
                gui.close;
            };
        };
        "Stopped scenarios and attempted to close MagicDisplayGUI (if present).".postln;
    };

    "MagicDisplayGUI test harness ready. Try ~startScenario1.(), ~startScenario2.(), or ~startScenario3.().".postln;
};

// Initialize cleanly
~mdgReset.();
~mdgInit.();
)
