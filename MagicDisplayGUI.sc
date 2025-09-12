/* MagicDisplayGUI.sc v0.2.1
 GUI display adaptor for MagicPedalboardNew.

 - CURRENT column highlighted in green.
 - Top-down chain: source (top) → processors → sink (bottom).
 - "What you should hear" text field + visual countdown (numeric + bar).
 - Operations panel: upcoming ops list, highlights NEXT; "Next" button triggers 3s countdown then runs.
 - Embedded level meters for \chainA and \chainB (no server.sync; Server.default.bind only).
 // MD 20250912-1640
*/
MagicDisplayGUI : MagicDisplay {
    classvar <versionGUI;
    var <window;

    // layout elements
    var leftPanel, rightPanel;
    var leftHeader, rightHeader;
    var leftListView, rightListView;
    var leftEffective, rightEffective;

    // expectation + countdown
    var expectationText;
    var countdownLabel, countdownBarView, countdownTask, countdownSecondsDefault;

    // operations panel
    var opsListView, opsNextButton, opsStatusText;
    var opsItems, opsIndexNext, opsCallback, opsCountdownSeconds;

    // meters
    var meterViewA, meterViewB;
    var meterSynthA, meterSynthB, oscA, oscB;
    var enableMetersFlag;

    *initClass {
        var text;
        versionGUI = "v0.2.1";
        text = "MagicDisplayGUI " ++ versionGUI;
        text.postln;
    }

    *new { arg level = 1;
        var instance;
        instance = super.new(level);
        ^instance.initGui;
    }

    initGui {
        var windowRect, panelWidth, listHeight, headerHeight, footerHeight, pad;
        var opsWidth, opsRect;
        var selfRef;
        var buildWindow;

        windowRect = Rect(100, 100, 980, 520);
        panelWidth = 300;
        listHeight = 300;
        headerHeight = 28;
        footerHeight = 22;
        pad = 10;

        opsWidth = 320;
        opsRect = Rect(2 * pad + 2 * panelWidth + 40, pad, opsWidth, windowRect.height - 2 * pad);

        countdownSecondsDefault = 3.0;
        opsCountdownSeconds = 3.0;
        enableMetersFlag = true;

        selfRef = this;

        buildWindow = {
            var metersHeight, greenBg, neutralBg;
            var buildColumn, buildMeters, applyInitialHighlight;
            var columnLeftX, columnRightX;

            metersHeight = 86;
            greenBg = Color(0.85, 1.0, 0.85);
            neutralBg = Color(0.92, 0.92, 0.92);

            columnLeftX = pad;
            columnRightX = pad + panelWidth + 40;

            buildColumn = { arg xPos, title;
                var panel, header, listView, effectiveLabel;
                var headerRect, listRect, effRect;

                panel = CompositeView(window, Rect(xPos, pad, panelWidth, windowRect.height - 2 * pad - metersHeight));
                panel.background_(neutralBg);

                headerRect = Rect(0, 0, panelWidth, headerHeight);
                header = StaticText(panel, headerRect).string_(title);
                header.align_(\center);

                listRect = Rect(0, headerHeight + 6, panelWidth, listHeight);
                listView = ListView(panel, listRect).items_([]);

                effRect = Rect(0, headerHeight + 6 + listHeight + 6, panelWidth, footerHeight);
                effectiveLabel = StaticText(panel, effRect).string_("eff: —");
                effectiveLabel.align_(\center);

                ^(panel: panel, header: header, list: listView, eff: effectiveLabel)
            };

            buildMeters = {
                var metersGroup, labelA, labelB, row1, row2, labelWidth, barWidth, rowHeight;

                labelWidth = 60;
                barWidth = windowRect.width - 2 * pad - labelWidth - 10;
                rowHeight = 30;

                metersGroup = CompositeView(window, Rect(pad, windowRect.height - metersHeight - pad, windowRect.width - 2 * pad, metersHeight));
                metersGroup.background_(Color(0.96, 0.96, 0.96));

                // Chain A
                row1 = CompositeView(metersGroup, Rect(0, 0, metersGroup.bounds.width, rowHeight));
                labelA = StaticText(row1, Rect(0, 4, labelWidth, 20)).string_("chainA");
                meterViewA = LevelIndicator(row1, Rect(labelWidth + 6, 4, barWidth, 20));

                // Chain B
                row2 = CompositeView(metersGroup, Rect(0, rowHeight + 8, metersGroup.bounds.width, rowHeight));
                labelB = StaticText(row2, Rect(0, 4, labelWidth, 20)).string_("chainB");
                meterViewB = LevelIndicator(row2, Rect(labelWidth + 6, 4, barWidth, 20));
            };

            applyInitialHighlight = {
                var currentBg, nextBg;
                currentBg = greenBg;
                nextBg = neutralBg;
                if(leftPanel.notNil) { leftPanel[\panel].background_(currentBg) };
                if(rightPanel.notNil) { rightPanel[\panel].background_(nextBg) };
            };

            window = Window("MagicDisplayGUI – CURRENT / NEXT", windowRect).front.alwaysOnTop_(true);

            leftPanel = buildColumn.value(columnLeftX, "CURRENT");
            rightPanel = buildColumn.value(columnRightX, "NEXT");

            expectationText = TextView(window, Rect(pad, leftPanel[\panel].bounds.bottom + 6, 2 * panelWidth + 40, 52));
            expectationText.background_(Color(1, 1, 0.9));
            expectationText.string_("What you should hear will appear here…");

            countdownLabel = StaticText(window, Rect(pad, expectationText.bounds.bottom + 6, 120, 20)).string_("Ready");

            countdownBarView = UserView(window, Rect(pad + 130, expectationText.bounds.bottom + 6, panelWidth - 10, 20));
            countdownBarView.background_(Color(0.9, 0.9, 0.9));
            countdownBarView.drawFunc_({ arg view;
                var barWidthNow, fullWidth, progressFraction, colorFill, progressStored;
                progressStored = view.getProperty(\progress) ? 0.0;
                progressFraction = progressStored.clip(0, 1);
                fullWidth = view.bounds.width;
                barWidthNow = fullWidth * progressFraction;
                colorFill = Color(0.3, 0.8, 0.3);
                Pen.fillColor = colorFill;
                Pen.addRect(Rect(0, 0, barWidthNow, view.bounds.height));
                Pen.fill;
            });
            countdownBarView.setProperty(\progress, 0.0);

            // Operations list + button
            opsItems = Array.new;
            opsIndexNext = 0;
            opsCallback = nil;

            opsListView = ListView(window, opsRect).items_([]);
            opsStatusText = StaticText(window, Rect(opsRect.left, opsRect.bottom - 52, opsRect.width - 110, 20)).string_("Next: —");
            opsNextButton = Button(window, Rect(opsRect.right - 100, opsRect.bottom - 56, 100, 28))
                .states_([["Next (3s)", Color.white, Color(0, 0.5, 0)]])
                .action_({
                    var nextIndexLocal, totalCountLocal, nextLabel;
                    nextIndexLocal = opsIndexNext;
                    totalCountLocal = opsItems.size;
                    if(nextIndexLocal >= totalCountLocal) { "No more operations.".postln; ^nil };
                    nextLabel = opsItems[nextIndexLocal];
                    selfRef.startCountdown(opsCountdownSeconds, "Next: " ++ nextLabel, {
                        var clampedIndex;
                        clampedIndex = opsIndexNext.clip(0, opsItems.size - 1);
                        selfRef.runNextOperation(clampedIndex);
                    });
                });

            buildMeters.value;
            applyInitialHighlight.value;
        };

        AppClock.sched(0, {
            var enableNow;
            buildWindow.value;
            enableNow = enableMetersFlag;
            if(enableNow) { this.enableMeters(true) };
            nil
        });

        ^this
    }

    // ─── highlight CURRENT column ─────────────────────────────────
    highlightCurrentColumn {
        var greenBg, neutralBg;
        greenBg = Color(0.85, 1.0, 0.85);
        neutralBg = Color(0.92, 0.92, 0.92);
        if(leftPanel.notNil) { leftPanel[\panel].background_(greenBg) };
        if(rightPanel.notNil) { rightPanel[\panel].background_(neutralBg) };
    }

    // ─── format src → procs → sink ────────────────────────────────
    formatListTopDown { arg listRef, bypassKeys, effectiveList;
        var itemsOut, lastIndex, processorsList, indexCounter, sourceKey, sinkKey, isBypassed, badge, lineText;
        itemsOut = Array.new;
        lastIndex = listRef.size - 1;
        sinkKey = listRef[0];
        sourceKey = listRef[lastIndex];

        itemsOut = itemsOut.add("src  : " ++ sourceKey);

        if(listRef.size > 2) {
            itemsOut = itemsOut.add("procs:");
            processorsList = listRef.copyRange(1, lastIndex - 1).reverse; // top→down from src to sink
            indexCounter = 1;
            processorsList.do({ arg procKey;
                isBypassed = bypassKeys.includes(procKey);
                badge = if(isBypassed) { "[BYP]" } { "[ON]" };
                lineText = "  [" ++ indexCounter ++ "] " ++ procKey ++ " " ++ badge;
                itemsOut = itemsOut.add(lineText);
                indexCounter = indexCounter + 1;
            });
        }{
            itemsOut = itemsOut.add("procs: (none)");
        };

        itemsOut = itemsOut.add("sink : " ++ sinkKey);
        itemsOut = itemsOut.add("eff  : " ++ effectiveList.join(" -> "));
        ^itemsOut
    }

    // ─── expectation + countdown ──────────────────────────────────
    showExpectation { arg textString, seconds = 0;
        var secondsLocal, hasCountdown;
        secondsLocal = seconds ? 0;
        hasCountdown = secondsLocal > 0;

        AppClock.sched(0, {
            var labelNow;
            expectationText.string_(textString.asString);
            if(hasCountdown) {
                this.startCountdown(secondsLocal, "Listen in…", { nil });
            }{
                labelNow = "Ready";
                countdownLabel.string_(labelNow);
                countdownBarView.setProperty(\progress, 0.0);
                countdownBarView.refresh;
            };
            nil
        });
    }

    startCountdown { arg seconds, labelText, onFinishedFunc;
        var secondsClamped, startTime, stopTime, selfRef;
        secondsClamped = seconds.clip(0.5, 10.0);
        startTime = Main.elapsedTime;
        stopTime = startTime + secondsClamped;
        selfRef = this;

        if(countdownTask.notNil) { countdownTask.stop; countdownTask = nil };

        AppClock.sched(0, {
            var finishedFlag, delaySeconds;
            var updateAndCheckDone;

            countdownLabel.string_(labelText.asString ++ " (" ++ secondsClamped.asString ++ "s)");
            countdownBarView.setProperty(\progress, 0.0);
            countdownBarView.refresh;

            finishedFlag = false;
            delaySeconds = 0.05;

            updateAndCheckDone = {
                var nowTime, remainingSeconds, progressFraction;
                nowTime = Main.elapsedTime;
                remainingSeconds = (stopTime - nowTime).max(0);
                progressFraction = ((secondsClamped - remainingSeconds) / secondsClamped).clip(0.0, 1.0);

                countdownLabel.string_(labelText.asString ++ " (" ++ remainingSeconds.round(0.1).asString ++ "s)");
                countdownBarView.setProperty(\progress, progressFraction);
                countdownBarView.refresh;

                if(remainingSeconds <= 0) { finishedFlag = true };
            };

            countdownTask = Task({
                var localFinished;
                localFinished = false;
                while({ localFinished.not }, {
                    updateAndCheckDone.value;
                    localFinished = finishedFlag;
                    delaySeconds.wait;
                });
                countdownLabel.string_("Now");
                if(onFinishedFunc.notNil) { onFinishedFunc.value };
            }, AppClock).play;

            nil
        });
    }

    // ─── operations panel ─────────────────────────────────────────
    setOperations { arg itemsArray;
        var itemsSafe, entryStrings;
        itemsSafe = itemsArray ? Array.new;
        entryStrings = itemsSafe;

        AppClock.sched(0, {
            opsItems = entryStrings.collect({ arg it; it.asString });
            opsListView.items_(opsItems);
            opsIndexNext = 0;
            this.updateOpsHighlight;
            nil
        });
    }

    setNextAction { arg func;
        var f;
        f = func;
        opsCallback = f;
    }

    runNextOperation { arg indexToRun;
        var totalCount, labelText, nextIndexComputed;
        totalCount = opsItems.size;
        labelText = if(indexToRun < totalCount) { opsItems[indexToRun] } { "—" };

        if(opsCallback.notNil) {
            opsCallback.value(indexToRun);
        }{
            ("[ops] No callback for index " ++ indexToRun).warn;
        };

        nextIndexComputed = (indexToRun + 1).clip(0, totalCount);
        opsIndexNext = nextIndexComputed;
        this.updateOpsHighlight;
    }

    updateOpsHighlight {
        var totalCount, entryStrings, nextIndexLocal, statusText;
        totalCount = opsItems.size;
        nextIndexLocal = opsIndexNext.min(totalCount);

        entryStrings = opsItems.collect({ arg item, idx;
            var marker;
            marker = if(idx == opsIndexNext) { "→ " } { "   " };
            marker ++ item
        });

        statusText = if(opsIndexNext < totalCount) {
            "Next: " ++ opsItems[opsIndexNext]
        }{
            "Done."
        };

        AppClock.sched(0, {
            opsListView.items_(entryStrings);
            opsStatusText.string_(statusText);
            nil
        });
    }

    // ─── meters ───────────────────────────────────────────────────
    enableMeters { arg flag = true;
        var shouldEnable;
        shouldEnable = flag ? true;
        enableMetersFlag = shouldEnable;

        if(shouldEnable.not) { ^this };

        Server.default.bind({
            var hasA, hasB;
            hasA = SynthDescLib.global.at(\busMeterA).notNil;
            hasB = SynthDescLib.global.at(\busMeterB).notNil;

            if(hasA.not) {
                SynthDef(\busMeterA, { arg inBus, rate = 15;
                    var sig, amp;
                    sig = In.ar(inBus, 2);
                    amp = Amplitude.ar(sig).clip(0, 1);
                    SendReply.kr(Impulse.kr(rate), '/ampA', A2K.kr(amp));
                }).add;
            };

            if(hasB.not) {
                SynthDef(\busMeterB, { arg inBus, rate = 15;
                    var sig, amp;
                    sig = In.ar(inBus, 2);
                    amp = Amplitude.ar(sig).clip(0, 1);
                    SendReply.kr(Impulse.kr(rate), '/ampB', A2K.kr(amp));
                }).add;
            };

            if(meterSynthA.notNil) { meterSynthA.free };
            if(meterSynthB.notNil) { meterSynthB.free };

            {
                var busA, busB;
                busA = Ndef(\chainA).bus;
                busB = Ndef(\chainB).bus;
                meterSynthA = Synth(\busMeterA, [\inBus, busA.index, \rate, 24], target: Server.default.defaultGroup, addAction: \addToTail);
                meterSynthB = Synth(\busMeterB, [\inBus, busB.index, \rate, 24], target: Server.default.defaultGroup, addAction: \addToTail);
            }.value;
        });

        if(oscA.notNil) { oscA.free };
        if(oscB.notNil) { oscB.free };

        oscA = OSCdef(\ampA, { arg msg;
            var leftAmp, rightAmp, levelAvg;
            leftAmp = msg[3];
            rightAmp = msg[4];
            levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
            AppClock.sched(0, {
                var viewExists;
                viewExists = meterViewA.notNil;
                if(viewExists) { meterViewA.value_(levelAvg) };
                nil
            });
        }, '/ampA');

        oscB = OSCdef(\ampB, { arg msg;
            var leftAmp, rightAmp, levelAvg;
            leftAmp = msg[3];
            rightAmp = msg[4];
            levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
            AppClock.sched(0, {
                var viewExists;
                viewExists = meterViewB.notNil;
                if(viewExists) { meterViewB.value_(levelAvg) };
                nil
            });
        }, '/ampB');
    }

    // ─── display hooks from MagicPedalboardNew ────────────────────
    showInit { arg pedalboard, versionString, current, next;
        var titleText;
        titleText = "MagicDisplayGUI – " ++ versionString;
        AppClock.sched(0, {
            if(window.notNil) { window.name_(titleText) };
            nil
        });
    }

    showRebuild { arg which, fullChain, effective;
        var infoText;
        infoText = "[MPB:rebuild:" ++ which ++ "] full=" ++ fullChain ++ " effective=" ++ effective;
        AppClock.sched(0, { infoText.postln; nil });
    }

    showPlay { arg sinkKey;
        var text;
        text = "[MPB:play] sink=" ++ sinkKey;
        AppClock.sched(0, { text.postln; nil });
    }

    showStop { arg sinkKey;
        var text;
        text = "[MPB:stop] sink=" ++ sinkKey;
        AppClock.sched(0, { text.postln; nil });
    }

    showSwitch { arg oldSink, newSink, current, next;
        var infoText;
        infoText = "[MPB:switch] " ++ oldSink ++ " → " ++ newSink;
        AppClock.sched(0, {
            if(window.notNil) { window.name_("MagicDisplayGUI – switched: " ++ oldSink ++ " → " ++ newSink) };
            this.highlightCurrentColumn;
            nil
        });
    }

    showMutation { arg action, args, nextChain;
        var text;
        text = "[MPB:mutate] " ++ action ++ " " ++ args ++ " next=" ++ nextChain;
        AppClock.sched(0, { text.postln; nil });
    }

    showBypass { arg which, key, state, chain, bypassKeys;
        var text;
        text = "[MPB:bypass:" ++ which ++ "] " ++ key ++ " -> " ++ state ++ " active=" ++ bypassKeys;
        AppClock.sched(0, { text.postln; nil });
    }

    showReset { arg current, next;
        var text;
        text = "[MPB:reset] current=" ++ current ++ " next=" ++ next;
        AppClock.sched(0, { text.postln; nil });
    }

    // main detailed view updater
    showChainsDetailed { arg current, next, bypassAKeys, bypassBKeys, effCurrent, effNext;
        var currentItems, nextItems, effCurrentText, effNextText;
        currentItems = this.formatListTopDown(current, bypassAKeys, effCurrent);
        nextItems = this.formatListTopDown(next,   bypassBKeys, effNext);
        effCurrentText = "eff: " ++ effCurrent.join(" -> ");
        effNextText    = "eff: " ++ effNext.join(" -> ");

        AppClock.sched(0, {
            if(leftHeader.notNil)  { leftHeader.string_("CURRENT (sink=" ++ current[0] ++ ")") };
            if(rightHeader.notNil) { rightHeader.string_("NEXT (sink=" ++ next[0] ++ ")") };
            if(leftListView.notNil)  { leftListView.items_(currentItems) };
            if(rightListView.notNil) { rightListView.items_(nextItems) };
            if(leftEffective.notNil)  { leftEffective.string_(effCurrentText) };
            if(rightEffective.notNil) { rightEffective.string_(effNextText) };
            nil
        });
    }

    showError { arg message;
        var text;
        text = "[MPB:error] " ++ message;
        AppClock.sched(0, { text.warn; nil });
    }
}
