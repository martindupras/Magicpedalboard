/* MagicDisplayGUI.sc v0.2.0
 GUI display adaptor for MagicPedalboardNew.

 - CURRENT column is highlighted in green.
 - Top-down chain presentation: source (top) → processors (middle) → sink (bottom).
 - "What you should hear" text field + visual countdown bar and numeric label.
 - Operations panel: upcoming ops list, "Next" button starts a 3s countdown then runs the callback.
 - Integrated level meters for \chainA and \chainB (no server.sync; safe Server.default.bind).
 // MD 20250912-1556
*/
MagicDisplayGUI : MagicDisplay {
    classvar <versionGUI;
    var <window;

    // Layout elements
    var leftPanel, rightPanel;
    var leftHeader, rightHeader;
    var leftListView, rightListView;
    var leftEffective, rightEffective;

    // Expectation + countdown
    var expectationText;
    var countdownLabel, countdownBarView, countdownTask, countdownSecondsDefault;

    // Operations panel
    var opsListView, opsNextButton, opsStatusText;
    var opsItems, opsIndexNext, opsCallback, opsCountdownSeconds;

    // Meters
    var meterViewA, meterViewB, meterWinEmbedded;
    var meterSynthA, meterSynthB, oscA, oscB;
    var enableMetersFlag;

    *initClass {
        var text;
        versionGUI = "v0.2.0";
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
        var buildWindow;
        var greenBg, neutralBg;

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

        greenBg = Color(0.85, 1.0, 0.85);
        neutralBg = Color(0.92, 0.92, 0.92);

        buildWindow = {
            var metersHeight, colLabelStyle;

            var buildColumn;
            var buildMeters;

            metersHeight = 86; // two rows
            colLabelStyle = { arg textString, at;
                var label;
                label = StaticText(window, at).string_(textString);
                label.align_(\center);
                ^label
            };

            buildColumn = { arg xPos, title;
                var panel, header, listView, effLabel, effRect, headerRect, listRect;

                panel = CompositeView(window, Rect(xPos, pad, panelWidth, windowRect.height - 2 * pad - metersHeight));
                panel.background_(neutralBg);

                headerRect = Rect(0, 0, panelWidth, headerHeight);
                header = StaticText(panel, headerRect).string_(title);
                header.align_(\center);

                listRect = Rect(0, headerHeight + 6, panelWidth, listHeight);
                listView = ListView(panel, listRect).items_([]);

                effRect = Rect(0, headerHeight + 6 + listHeight + 6, panelWidth, footerHeight);
                effLabel = StaticText(panel, effRect).string_("eff: —");
                effLabel.align_(\center);

                ^(panel: panel, header: header, list: listView, eff: effLabel)
            };

            buildMeters = {
                var metersGroup, labelA, labelB, row1, row2;
                var labelWidth, barWidth, rowHeight;

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

            window = Window("MagicDisplayGUI – CURRENT / NEXT", windowRect).front.alwaysOnTop_(true);

            // Columns
            leftPanel = buildColumn.(pad, "CURRENT");
            rightPanel = buildColumn.(pad + panelWidth + 40, "NEXT");

            // Expectation + countdown controls along the top, across columns
            expectationText = TextView(window, Rect(pad, leftPanel[\panel].bounds.bottom + 6, 2 * panelWidth + 40, 52));
            expectationText.background_(Color(1, 1, 0.9));
            expectationText.string_("What you should hear will appear here…");

            countdownLabel = StaticText(window, Rect(pad, expectationText.bounds.bottom + 6, 120, 20)).string_("Ready");
            countdownBarView = UserView(window, Rect(pad + 130, expectationText.bounds.bottom + 6, panelWidth - 10, 20));
            countdownBarView.background_(Color(0.9, 0.9, 0.9));
            countdownBarView.drawFunc_({ arg view;
                var barWidthNow, fullWidth, fraction, colorFill;
                var haveTask, progressData;
                // var-first inside block
                haveTask = countdownTask.notNil;
                progressData = view.getProperty(\progress) ? 0.0;
                fraction = progressData.clip(0, 1);
                fullWidth = view.bounds.width;
                barWidthNow = fullWidth * fraction;
                colorFill = Color(0.3, 0.8, 0.3);
                Pen.fillColor = colorFill;
                Pen.addRect(Rect(0, 0, barWidthNow, view.bounds.height));
                Pen.fill;
            });
            countdownBarView.setProperty(\progress, 0.0);

            // Operations panel
            opsItems = Array.new;
            opsIndexNext = 0;
            opsCallback = nil;

            opsListView = ListView(window, opsRect).items_([]);
            opsStatusText = StaticText(window, Rect(opsRect.left, opsRect.bottom - 52, opsRect.width - 110, 20)).string_("Next: —");
            opsNextButton = Button(window, Rect(opsRect.right - 100, opsRect.bottom - 56, 100, 28))
                .states_([["Next (3s)", Color.white, Color(0, 0.5, 0)]])
                .action_({
                    var nextIndex, totalCount, nextItem;
                    // var-first in block
                    nextIndex = opsIndexNext;
                    totalCount = opsItems.size;
                    if(nextIndex >= totalCount) { "No more operations.".postln; ^this };
                    nextItem = opsItems[nextIndex];
                    this.startCountdown(opsCountdownSeconds, "Next: " ++ nextItem, {
                        var clampedIndex;
                        clampedIndex = opsIndexNext.min(opsItems.size - 1).max(0);
                        this.runNextOperation(clampedIndex);
                    });
                });

            // Meters at bottom
            buildMeters.();

            // Apply initial highlight: CURRENT green
            this.highlightCurrentColumn;
        };

        AppClock.sched(0, {
            buildWindow.value;
            if(enableMetersFlag) { this.enableMeters(true) };
            nil
        });

        ^this
    }

    // ─── Utility: highlight CURRENT column ─────────────────────────
    highlightCurrentColumn {
        var greenBg, neutralBg;
        greenBg = Color(0.85, 1.0, 0.85);
        neutralBg = Color(0.92, 0.92, 0.92);
        if(leftPanel.notNil) { leftPanel[\panel].background = greenBg };
        if(rightPanel.notNil) { rightPanel[\panel].background = neutralBg };
    }

    // ─── Top-to-bottom formatting (src → procs → sink) ────────────
    formatListTopDown { arg listRef, bypassKeys, effectiveList;
        var itemsOut, lastIndex, processorsList, indexCounter, sourceKey, sinkKey;
        itemsOut = Array.new;
        lastIndex = listRef.size - 1;
        sinkKey = listRef[0];
        sourceKey = listRef[lastIndex];

        itemsOut = itemsOut.add("src  : " ++ sourceKey);

        if(listRef.size > 2) {
            itemsOut = itemsOut.add("procs:");
            processorsList = listRef.copyRange(1, lastIndex - 1);
            processorsList = processorsList; // keep chain order nearest sink first, still listed top-down
            indexCounter = 1;
            processorsList.reverse.do { arg procKey; // visually top→down from source toward sink
                var isBypassed, badge, lineText;
                isBypassed = bypassKeys.includes(procKey);
                badge = if(isBypassed) { "[BYP]" } { "[ON]" };
                lineText = ("  [" ++ indexCounter ++ "] " ++ procKey ++ " " ++ badge);
                itemsOut = itemsOut.add(lineText);
                indexCounter = indexCounter + 1;
            };
        }{
            itemsOut = itemsOut.add("procs: (none)");
        };

        itemsOut = itemsOut.add("sink : " ++ sinkKey);
        itemsOut = itemsOut.add("eff  : " ++ effectiveList.join(" -> "));
        ^itemsOut
    }

    // ─── Expectation + countdown API ──────────────────────────────
    showExpectation { arg textString, seconds = 0;
        var secondsLocal;
        secondsLocal = seconds ? 0;
        AppClock.sched(0, {
            var hasCountdown;
            expectationText.string = textString.asString;
            hasCountdown = secondsLocal > 0;
            if(hasCountdown) {
                this.startCountdown(secondsLocal, "Listen in…", { /* no-op here */ });
            }{
                countdownLabel.string = "Ready";
                countdownBarView.setProperty(\progress, 0.0);
                countdownBarView.refresh;
            };
            nil
        });
    }

    startCountdown { arg seconds, labelText, onFinishedFunc;
        var secondsClamped, startTime, stopTime, taskFunc;
        secondsClamped = seconds.clip(0.5, 10.0);
        startTime = Main.elapsedTime;
        stopTime = startTime + secondsClamped;

        if(countdownTask.notNil) { countdownTask.stop; countdownTask = nil };

        AppClock.sched(0, {
            var updateFunc;
            countdownLabel.string = labelText.asString ++ " (" ++ secondsClamped.asString ++ "s)";
            countdownBarView.setProperty(\progress, 0.0);
            countdownBarView.refresh;

            updateFunc = {
                var nowTime, remaining, fraction;
                nowTime = Main.elapsedTime;
                remaining = (stopTime - nowTime).max(0);
                fraction = ((secondsClamped - remaining) / secondsClamped).clip(0.0, 1.0);
                countdownLabel.string = labelText.asString ++ " (" ++ remaining.round(0.1).asString ++ "s)";
                countdownBarView.setProperty(\progress, fraction);
                countdownBarView.refresh;
                if(remaining <= 0) {
                    countdownTask.stop;
                    countdownTask = nil;
                    countdownLabel.string = "Now";
                    if(onFinishedFunc.notNil) { onFinishedFunc.value };
                    ^nil;
                }{
                    ^0.05;
                };
            };

            countdownTask = Task({
                var delay;
                delay = 0.05;
                while({ true }, {
                    var schedResult;
                    schedResult = updateFunc.value;
                    if(schedResult.isNil) { ^this };
                    delay.wait;
                });
            }, AppClock).play;
            nil
        });
    }

    // ─── Operations panel API ─────────────────────────────────────
    setOperations { arg itemsArray;
        var itemsSafe;
        itemsSafe = itemsArray ? Array.new;
        AppClock.sched(0, {
            var displayArray;
            opsItems = itemsSafe.collect({ arg it; it.asString });
            displayArray = opsItems;
            opsListView.items = displayArray;
            opsIndexNext = 0;
            this.updateOpsHighlight;
            nil
        });
    }

    setNextAction { arg func;
        opsCallback = func;
    }

    runNextOperation { arg indexToRun;
        var labelText, totalCount;
        labelText = if(indexToRun < opsItems.size) { opsItems[indexToRun] } { "—" };
        totalCount = opsItems.size;

        if(opsCallback.notNil) {
            opsCallback.value(indexToRun);
        }{
            ("[ops] No callback for index " ++ indexToRun).warn;
        };

        opsIndexNext = (indexToRun + 1).clip(0, totalCount);
        this.updateOpsHighlight;
    }

    updateOpsHighlight {
        var totalCount, entryStrings, nextIndexLocal;
        totalCount = opsItems.size;
        nextIndexLocal = opsIndexNext.min(totalCount);

        entryStrings = opsItems.collect({ arg item, idx;
            var marker;
            marker = if(idx == opsIndexNext) { "→ " } { "   " };
            marker ++ item
        });

        AppClock.sched(0, {
            var statusText;
            opsListView.items = entryStrings;
            statusText = if(opsIndexNext < totalCount) {
                "Next: " ++ opsItems[opsIndexNext]
            }{
                "Done."
            };
            opsStatusText.string = statusText;
            nil
        });
    }

    // ─── Meter support ────────────────────────────────────────────
    enableMeters { arg flag = true;
        var shouldEnable;
        shouldEnable = flag ? true;
        enableMetersFlag = shouldEnable;

        if(shouldEnable.not) { ^this };

        // Ensure SynthDefs once
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

            // Free old meter synths if any
            if(meterSynthA.notNil) { meterSynthA.free };
            if(meterSynthB.notNil) { meterSynthB.free };

            // Attach to current chain buses
            {
                var busA, busB;
                busA = Ndef(\chainA).bus;
                busB = Ndef(\chainB).bus;
                meterSynthA = Synth(\busMeterA, [\inBus, busA.index, \rate, 24], target: Server.default.defaultGroup, addAction: \addToTail);
                meterSynthB = Synth(\busMeterB, [\inBus, busB.index, \rate, 24], target: Server.default.defaultGroup, addAction: \addToTail);
            }.value;
        });

        // OSC update hooks
        if(oscA.notNil) { oscA.free };
        if(oscB.notNil) { oscB.free };

        oscA = OSCdef(\ampA, { arg msg;
            var leftAmp, rightAmp, levelAvg;
            leftAmp = msg[3];
            rightAmp = msg[4];
            levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
            AppClock.sched(0, {
                meterViewA.value = levelAvg;
                nil
            });
        }, '/ampA');

        oscB = OSCdef(\ampB, { arg msg;
            var leftAmp, rightAmp, levelAvg;
            leftAmp = msg[3];
            rightAmp = msg[4];
            levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
            AppClock.sched(0, {
                meterViewB.value = levelAvg;
                nil
            });
        }, '/ampB');
    }

    // ─── Display hooks from MagicPedalboardNew ────────────────────
    showInit { arg pedalboard, versionString, current, next;
        var titleText;
        titleText = "MagicDisplayGUI – " ++ versionString;
        AppClock.sched(0, {
            if(window.notNil) { window.name = titleText };
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
            window.name = "MagicDisplayGUI – switched: " ++ oldSink ++ " → " ++ newSink;
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

    // Main detailed view updater
    showChainsDetailed { arg current, next, bypassAKeys, bypassBKeys, effCurrent, effNext;
        var currentItems, nextItems, effCurrentText, effNextText;
        currentItems = this.formatListTopDown(current, bypassAKeys, effCurrent);
        nextItems = this.formatListTopDown(next,   bypassBKeys, effNext);
        effCurrentText = "eff: " ++ effCurrent.join(" -> ");
        effNextText    = "eff: " ++ effNext.join(" -> ");

        AppClock.sched(0, {
            leftHeader.string  = "CURRENT (sink=" ++ current[0] ++ ")";
            rightHeader.string = "NEXT (sink=" ++ next[0] ++ ")";
            leftListView.items = currentItems;
            rightListView.items = nextItems;
            leftEffective.string  = effCurrentText;
            rightEffective.string = effNextText;
            nil
        });
    }

    showError { arg message;
        var text;
        text = "[MPB:error] " ++ message;
        AppClock.sched(0, { text.warn; nil });
    }
}
