/* MagicDisplayGUI.sc v0.2.6
 CURRENT column highlighted in green; top-down list (src → procs → sink);
 expectation text + visual countdown; operations list with 3s pre-roll;
 embedded meters (A/B). UI-ready queue prevents touching nil views.
 No server.sync; server ops inside Server.default.bind.
 // MD 20250912-1738
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

	// ui-ready machinery
	var uiReadyFlag;
	var uiPendingActions;

	*initClass {
		var text;
		versionGUI = "v0.2.6";
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

		uiReadyFlag = false;
		uiPendingActions = Array.new;

		buildWindow = {
			var metersHeight, greenBg, neutralBg;
			var buildColumn, buildMeters, applyInitialHighlight;
			var columnLeftX, columnRightX;
			var columnLeftDict, columnRightDict;

			metersHeight = 86;
			greenBg = Color(0.85, 1.0, 0.85);
			neutralBg = Color(0.92, 0.92, 0.92);

			columnLeftX = pad;
			columnRightX = pad + panelWidth + 40;

			buildColumn = { arg xPos, title;
				var panel, header, listView, effectiveLabel;
				var headerRect, listRect, effRect, resultDict;

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

				resultDict = (panel: panel, header: header, list: listView, eff: effectiveLabel);
				resultDict
			};

			buildMeters = {
				var metersGroup, labelA, labelB, row1, row2, labelWidth, barWidth, rowHeight;

				labelWidth = 60;
				barWidth = windowRect.width - 2 * pad - labelWidth - 10;
				rowHeight = 30;

				metersGroup = CompositeView(window, Rect(pad, windowRect.height - metersHeight - pad, windowRect.width - 2 * pad, metersHeight));
				metersGroup.background_(Color(0.96, 0.96, 0.96));

				row1 = CompositeView(metersGroup, Rect(0, 0, metersGroup.bounds.width, rowHeight));
				labelA = StaticText(row1, Rect(0, 4, labelWidth, 20)).string_("chainA");
				meterViewA = LevelIndicator(row1, Rect(labelWidth + 6, 4, barWidth, 20));

				row2 = CompositeView(metersGroup, Rect(0, rowHeight + 8, metersGroup.bounds.width, rowHeight));
				labelB = StaticText(row2, Rect(0, 4, labelWidth, 20)).string_("chainB");
				meterViewB = LevelIndicator(row2, Rect(labelWidth + 6, 4, barWidth, 20));
			};

			applyInitialHighlight = {
				var currentBg, nextBg;
				currentBg = greenBg;
				nextBg = neutralBg;
				if(leftPanel.notNil) { leftPanel.background_(currentBg) };
				if(rightPanel.notNil) { rightPanel.background_(nextBg) };
			};

			window = Window("MagicDisplayGUI – CURRENT / NEXT", windowRect).front.alwaysOnTop_(true);

			columnLeftDict = buildColumn.value(columnLeftX, "CURRENT");
			leftPanel      = columnLeftDict[\panel];
			leftHeader     = columnLeftDict[\header];
			leftListView   = columnLeftDict[\list];
			leftEffective  = columnLeftDict[\eff];

			columnRightDict = buildColumn.value(columnRightX, "NEXT");
			rightPanel      = columnRightDict[\panel];
			rightHeader     = columnRightDict[\header];
			rightListView   = columnRightDict[\list];
			rightEffective  = columnRightDict[\eff];

			expectationText = TextView(window, Rect(pad, leftPanel.bounds.bottom + 6, 2 * panelWidth + 40, 52));
			expectationText.background_(Color(1, 1, 0.9));
			expectationText.string_("Command:");

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
				this.startCountdown(opsCountdownSeconds, "Next: " ++ nextLabel, {
					var clampedIndex;
					clampedIndex = opsIndexNext.clip(0, opsItems.size - 1);
					this.runNextOperation(clampedIndex);
				});
			});

			buildMeters.value;
			applyInitialHighlight.value;

			uiReadyFlag = true;
			this.flushUiPendingActions;
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

	// ui-ready helpers
	queueUi { arg func;
		var fn;
		fn = func;
		if(uiReadyFlag) {
			AppClock.sched(0, { fn.value; nil });
		}{
			uiPendingActions = uiPendingActions.add(fn);
		};
	}

	flushUiPendingActions {
		var actionsToRun;
		actionsToRun = uiPendingActions;
		uiPendingActions = Array.new;
		actionsToRun.do({ arg f;
			AppClock.sched(0, { f.value; nil });
		});
	}

	// visuals
	highlightCurrentColumn {
		var greenBg, neutralBg;
		greenBg = Color(0.85, 1.0, 0.85);
		neutralBg = Color(0.92, 0.92, 0.92);
		this.queueUi({
			if(leftPanel.notNil) { leftPanel.background_(greenBg) };
			if(rightPanel.notNil) { rightPanel.background_(neutralBg) };
		});
	}

	formatListTopDown { arg listRef, bypassKeys, effectiveList;
		var itemsOut, lastIndex, processorsList, indexCounter, sourceKey, sinkKey, isBypassed, badge, lineText;
		itemsOut = Array.new;
		lastIndex = listRef.size - 1;
		sinkKey = listRef[0];
		sourceKey = listRef[lastIndex];

		itemsOut = itemsOut.add("src  : " ++ sourceKey);

		if(listRef.size > 2) {
			itemsOut = itemsOut.add("procs:");
			processorsList = listRef.copyRange(1, lastIndex - 1).reverse;
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

	// expectation + countdown
	showExpectation { arg textString, seconds = 0;
		var secondsLocal, hasCountdown;
		secondsLocal = seconds ? 0;
		hasCountdown = secondsLocal > 0;

		this.queueUi({
			var labelNow;
			if(expectationText.notNil) { expectationText.string_(textString.asString) };
			if(hasCountdown) {
				this.startCountdown(secondsLocal, "Listen in…", { nil });
			}{
				labelNow = "Ready";
				if(countdownLabel.notNil) { countdownLabel.string_(labelNow) };
				if(countdownBarView.notNil) {
					countdownBarView.setProperty(\progress, 0.0);
					countdownBarView.refresh;
				};
			};
		});
	}

	startCountdown { arg seconds, labelText, onFinishedFunc;
		var secondsClamped, startTime, stopTime;
		secondsClamped = seconds.clip(0.5, 10.0);
		startTime = Main.elapsedTime;
		stopTime = startTime + secondsClamped;

		if(countdownTask.notNil) { countdownTask.stop; countdownTask = nil };

		this.queueUi({
			var finishedFlag, delaySeconds, updateAndCheckDone;

			if(countdownLabel.notNil) { countdownLabel.string_(labelText.asString ++ " (" ++ secondsClamped.asString ++ "s)") };
			if(countdownBarView.notNil) {
				countdownBarView.setProperty(\progress, 0.0);
				countdownBarView.refresh;
			};

			finishedFlag = false;
			delaySeconds = 0.05;

			updateAndCheckDone = {
				var nowTime, remainingSeconds, progressFraction;
				nowTime = Main.elapsedTime;
				remainingSeconds = (stopTime - nowTime).max(0);
				progressFraction = ((secondsClamped - remainingSeconds) / secondsClamped).clip(0.0, 1.0);

				if(countdownLabel.notNil) { countdownLabel.string_(labelText.asString ++ " (" ++ remainingSeconds.round(0.1).asString ++ "s)") };
				if(countdownBarView.notNil) {
					countdownBarView.setProperty(\progress, progressFraction);
					countdownBarView.refresh;
				};

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
				if(countdownLabel.notNil) { countdownLabel.string_("Now") };
				if(onFinishedFunc.notNil) { onFinishedFunc.value };
			}, AppClock).play;
		});
	}

	// operations
	setOperations { arg itemsArray;
		var itemsSafe, entryStrings;
		itemsSafe = itemsArray ? Array.new;
		entryStrings = itemsSafe.collect({ arg it; it.asString });

		this.queueUi({
			opsItems = entryStrings;
			if(opsListView.notNil) { opsListView.items_(opsItems) };
			opsIndexNext = 0;
			this.updateOpsHighlight;
		});
	}

	setNextAction { arg func;
		var f;
		f = func;
		opsCallback = f;
	}

	runNextOperation { arg indexToRun;
		var totalCount, nextIndexComputed;
		totalCount = opsItems.size;

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

		this.queueUi({
			if(opsListView.notNil) { opsListView.items_(entryStrings) };
			if(opsStatusText.notNil) { opsStatusText.string_(statusText) };
		});
	}

	/////////////////
	// meters
	// --- canonical enableMeters: waits until sinks are audio-rate, then attaches meters ---
// MagicDisplayGUI.sc
// canonical enableMeters: resend SynthDefs every time; wait until sinks are audio-rate
enableMeters { arg flag = true;
    var shouldEnable, aOK, bOK, busA, busB;

    // When enabling, wait until sinks are audio-rate (no control-rate bus warnings)
    if(flag) {
        busA = Ndef(\chainA).bus;
        busB = Ndef(\chainB).bus;
        aOK = busA.notNil and: { busA.rate == \audio };
        bOK = busB.notNil and: { busB.rate == \audio };
        if(aOK.not or: { bOK.not }) {
            AppClock.sched(0.20, { this.enableMeters(true); nil });
            ^this;
        };
        // Also guard against server being off
        if(Server.default.serverRunning.not) {
            AppClock.sched(0.20, { this.enableMeters(true); nil });
            ^this;
        };
    };

    shouldEnable = flag ? true;
    enableMetersFlag = shouldEnable;

    if(shouldEnable) {
        Server.default.bind({
            var busA_local, busB_local;

            // Always (re)send SynthDefs so they exist on the server now.
            SynthDef(\busMeterA, { arg inBus, rate = 15;
                var sig = In.ar(inBus, 2);
                var amp = Amplitude.ar(sig).clip(0, 1);
                SendReply.kr(Impulse.kr(rate), '/ampA', A2K.kr(amp));
            }).add;
            SynthDef(\busMeterB, { arg inBus, rate = 15;
                var sig = In.ar(inBus, 2);
                var amp = Amplitude.ar(sig).clip(0, 1);
                SendReply.kr(Impulse.kr(rate), '/ampB', A2K.kr(amp));
            }).add;

            if(meterSynthA.notNil) { meterSynthA.free };
            if(meterSynthB.notNil) { meterSynthB.free };

            busA_local = Ndef(\chainA).bus;
            busB_local = Ndef(\chainB).bus;

            meterSynthA = Synth(\busMeterA, [\inBus, busA_local.index, \rate, 24],
                target: Server.default.defaultGroup, addAction: \addToTail);
            meterSynthB = Synth(\busMeterB, [\inBus, busB_local.index, \rate, 24],
                target: Server.default.defaultGroup, addAction: \addToTail);
        });

        if(oscA.notNil) { oscA.free };
        if(oscB.notNil) { oscB.free };
        oscA = OSCdef(\ampA, { arg msg;
            var leftAmp, rightAmp, levelAvg;
            leftAmp = msg[3]; rightAmp = msg[4];
            levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
            AppClock.sched(0, { if(meterViewA.notNil) { meterViewA.value_(levelAvg) }; nil });
        }, '/ampA');
        oscB = OSCdef(\ampB, { arg msg;
            var leftAmp, rightAmp, levelAvg;
            leftAmp = msg[3]; rightAmp = msg[4];
            levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
            AppClock.sched(0, { if(meterViewB.notNil) { meterViewB.value_(levelAvg) }; nil });
        }, '/ampB');
        ^this;

    } {
        Server.default.bind({
            if(meterSynthA.notNil) { meterSynthA.free; meterSynthA = nil; };
            if(meterSynthB.notNil) { meterSynthB.free; meterSynthB = nil; };
        });
        if(oscA.notNil) { oscA.free; oscA = nil; };
        if(oscB.notNil) { oscB.free; oscB = nil; };
        AppClock.sched(0, {
            if(meterViewA.notNil) { meterViewA.value_(0.0) };
            if(meterViewB.notNil) { meterViewB.value_(0.0) };
            nil
        });
        ^this;
    };
}

/*	enableMeters { arg flag = true;
		var shouldEnable, aOK, bOK, busA, busB;

		// Only guard when enabling
		if(flag) {
			// read buses once
			busA = Ndef(\chainA).bus;
			busB = Ndef(\chainB).bus;
			// both must exist and be audio-rate
			aOK = busA.notNil and: { busA.rate == \audio };
			bOK = busB.notNil and: { busB.rate == \audio };
			if(aOK.not or: { bOK.not }) {
				// retry shortly on AppClock; do not mutate the audio tree here
				AppClock.sched(0.20, { this.enableMeters(true); nil });
				^this;
			};
		};

		shouldEnable = flag ? true;
		enableMetersFlag = shouldEnable;

		if(shouldEnable) {
			// --- enable path (unchanged except for the pre-check above) ---
			Server.default.bind({
				var hasA, hasB, busA_local, busB_local;
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
				// read buses post-guard
				busA_local = Ndef(\chainA).bus;
				busB_local = Ndef(\chainB).bus;
				meterSynthA = Synth(\busMeterA, [\inBus, busA_local.index, \rate, 24],
					target: Server.default.defaultGroup, addAction: \addToTail);
				meterSynthB = Synth(\busMeterB, [\inBus, busB_local.index, \rate, 24],
					target: Server.default.defaultGroup, addAction: \addToTail);
			});

			if(oscA.notNil) { oscA.free };
			if(oscB.notNil) { oscB.free };
			oscA = OSCdef(\ampA, { arg msg;
				var leftAmp, rightAmp, levelAvg;
				leftAmp = msg[3]; rightAmp = msg[4];
				levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
				AppClock.sched(0, { if(meterViewA.notNil) { meterViewA.value_(levelAvg) }; nil });
			}, '/ampA');
			oscB = OSCdef(\ampB, { arg msg;
				var leftAmp, rightAmp, levelAvg;
				leftAmp = msg[3]; rightAmp = msg[4];
				levelAvg = ((leftAmp + rightAmp) * 0.5).clip(0, 1);
				AppClock.sched(0, { if(meterViewB.notNil) { meterViewB.value_(levelAvg) }; nil });
			}, '/ampB');
			^this;

		} {
			// --- disable path (unchanged) ---
			Server.default.bind({
				if(meterSynthA.notNil) { meterSynthA.free; meterSynthA = nil; };
				if(meterSynthB.notNil) { meterSynthB.free; meterSynthB = nil; };
			});
			if(oscA.notNil) { oscA.free; oscA = nil; };
			if(oscB.notNil) { oscB.free; oscB = nil; };
			AppClock.sched(0, {
				if(meterViewA.notNil) { meterViewA.value_(0.0) };
				if(meterViewB.notNil) { meterViewB.value_(0.0) };
				nil
			});
			^this;
		};
	}
*/

	///////////////

	// display hooks
	showInit { arg pedalboard, versionString, current, next;
		var titleText;
		titleText = "MagicDisplayGUI – " ++ versionString;
		this.queueUi({
			if(window.notNil) { window.name_(titleText) };
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
		this.queueUi({
			// keep window title stable; show transient text in labels instead
			this.highlightCurrentColumn;
			if(opsStatusText.notNil) {
				opsStatusText.string_("Switched: " ++ oldSink ++ " → " ++ newSink);
			}{
				if(expectationText.notNil) {
					expectationText.string_("Switched: " ++ oldSink ++ " → " ++ newSink);
				};
			};
		});
		AppClock.sched(0, { infoText.postln; nil });
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

	showChainsDetailed { arg current, next, bypassAKeys, bypassBKeys, effCurrent, effNext;
		var currentItems, nextItems, effCurrentText, effNextText;
		currentItems = this.formatListTopDown(current, bypassAKeys, effCurrent);
		nextItems = this.formatListTopDown(next,   bypassBKeys, effNext);
		effCurrentText = "eff: " ++ effCurrent.join(" -> ");
		effNextText    = "eff: " ++ effNext.join(" -> ");

		this.queueUi({
			if(leftHeader.notNil)  { leftHeader.string_("CHAIN A ACTIVE") };
			if(rightHeader.notNil) { rightHeader.string_("CHAIN B NEXT") };
			if(leftListView.notNil)  { leftListView.items_(currentItems) };
			if(rightListView.notNil) { rightListView.items_(nextItems) };
			if(leftEffective.notNil)  { leftEffective.string_(effCurrentText) };
			if(rightEffective.notNil) { rightEffective.string_(effNextText) };
		});
	}

	showError { arg message;
		var text;
		text = "[MPB:error] " ++ message;
		AppClock.sched(0, { text.warn; nil });
	}
}
