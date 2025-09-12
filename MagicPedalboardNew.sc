/*  MagicPedalboardNew.sc  v0.3
    A/B pedalboard chain manager built on Ndefs.
    - Chains are Arrays of Symbols ordered [sink, …, source].
    - Uses JITLib embedding: Ndef(left) <<> Ndef(right).
    - Creates two sinks: \chainA and \chainB, and plays the current chain on init.
    - Most mutators act on the next chain; explicit current-chain bypass helpers are provided.
*/

MagicPedalboardNew : Object {

	// ───────────────────────────────────────────────────────────────
	// class metadata
	// ───────────────────────────────────────────────────────────────
	classvar < version = "v0.3.1";

	// ───────────────────────────────────────────────────────────────
	// instance state
	// ───────────────────────────────────────────────────────────────
	var < currentChain;   // points to either chainAList or chainBList
	var < nextChain;      // points to the other list
	var chainAList;       // [\chainA, ...processors..., source]
	var chainBList;       // [\chainB, ...processors..., source]

	var bypassA;          // IdentityDictionary: key(Symbol) -> Bool (true = bypassed)
	var bypassB;          // IdentityDictionary: key(Symbol) -> Bool (true = bypassed)

	var defaultNumChannels;
	var defaultSource;

	var bypassAKeys, bypassBKeys;

	var < display; // will hold a MagicDisplay

	// ───────────────────────────────────────────────────────────────
	// class init
	// ───────────────────────────────────────────────────────────────
	*initClass {
		("MagicPedalboardNew " ++ version).postln;
	}

	*new {
		|disp = nil|  ^super.new.init(disp)  // optional display
	}

	// ───────────────────────────────────────────────────────────────
	// init & sinks
	// ───────────────────────────────────────────────────────────────
	init { |disp|
		var sinkFunc;
		display = disp;

		defaultNumChannels = 2;
		defaultSource = \ts0; // silent by default; tests set audible sources

		sinkFunc = {
			var inputSignal;
			inputSignal = \in.ar(defaultNumChannels);
			inputSignal
		};

		Ndef(\chainA, sinkFunc);
		Ndef(\chainB, sinkFunc);

		chainAList = [\chainA, defaultSource];
		chainBList = [\chainB, defaultSource];

		bypassA = IdentityDictionary.new;
		bypassB = IdentityDictionary.new;

		currentChain = chainAList;
		nextChain = chainBList;

		this.rebuild(currentChain);
		this.rebuild(nextChain);
		Ndef(\chainA).play(numChannels: defaultNumChannels);


		if(display.notNil) {
			display.showInit(this, version, currentChain, nextChain);
		};

		^this
	}

	// ───────────────────────────────────────────────────────────────
	// public API
	// ───────────────────────────────────────────────────────────────
	help {
		var helpText;
		helpText = String.new;
		helpText = helpText
		++ "MagicPedalboardNew " ++ version ++ "\n"
		++ "Chains are Arrays of Symbols ordered [sink, …, source].\n"
		++ "On init, creates \\chainA and \\chainB and plays current.\n\n"
		++ "Core methods (mostly operate on the *next* chain):\n"
		++ "  printChains\n"
		++ "  playCurrent, stopCurrent, switchChain\n"
		++ "  add(key), addAt(key, index)\n"
		++ "  removeAt(index), swap(indexA, indexB)\n"
		++ "  bypass(key, state=true), bypassAt(index, state=true)\n"
		++ "  clearChain\n"
		++ "Current-chain bypass helpers:\n"
		++ "  bypassCurrent(key, state=true), bypassAtCurrent(index, state=true)\n"
		++ "Diagnostics helpers:\n"
		++ "  effectiveCurrent, effectiveNext, bypassKeysCurrent, bypassKeysNext, reset\n";
		helpText.postln;
	}

	printChains {
		var annotateCurrent, annotateNext;
		var bypassAKeys, bypassBKeys;

		annotateCurrent = { |listRef| if(listRef === currentChain) { "  (current)" } { "" } };
		annotateNext = { |listRef| if(listRef === nextChain) { "  (next)" } { "" } };

		bypassAKeys = this.bypassKeysForListInternal(chainAList);
		bypassBKeys = this.bypassKeysForListInternal(chainBList);

		if(display.notNil) {
			display.showChains(chainAList, chainBList, bypassAKeys, bypassBKeys);
		}{
			"MagicPedalboardNew.printChains:".postln;

			("A: " ++ chainAList ++ annotateCurrent.(chainAList) ++ annotateNext.(chainAList)).postln;
			("   bypassA: " ++ this.bypassKeysForListInternal(chainAList)).postln;

			("B: " ++ chainBList ++ annotateCurrent.(chainBList) ++ annotateNext.(chainBList)).postln;
			("   bypassB: " ++ this.bypassKeysForListInternal(chainBList)).postln;
		}
	}

	playCurrent {
		var sinkKey;
		sinkKey = currentChain[0];
		this.rebuild(currentChain);
		Ndef(sinkKey).play(numChannels: defaultNumChannels);
		if(display.notNil) { display.showPlay(sinkKey) };
	}

	stopCurrent {
		var sinkKey;
		sinkKey = currentChain[0];
		Ndef(sinkKey).stop;
		if(display.notNil) { display.showStop(sinkKey) };
	}

	switchChain {
		var tempChainRef, oldSinkKey, newSinkKey;

		oldSinkKey = currentChain[0];
		Ndef(oldSinkKey).stop;

		tempChainRef = currentChain;
		currentChain = nextChain;
		nextChain = tempChainRef;

		this.rebuild(nextChain);
		this.rebuild(currentChain);

		newSinkKey = currentChain[0];
		Ndef(newSinkKey).play(numChannels: defaultNumChannels);

		if(display.notNil) { display.showSwitch(oldSinkKey, newSinkKey, currentChain, nextChain) };

	}

	// ---- next-chain mutations ------------------------------------------------

	add { | key |
		var insertIndex;
		insertIndex = nextChain.size - 1; // just before source
		this.addAt(key, insertIndex);
		if(display.notNil) { display.showMutation(\add, [key], nextChain) };

	}

	addAt { | key, index |
		var indexClamped, newList;
		indexClamped = index.clip(1, nextChain.size - 1); // never before sink
		newList = nextChain.insert(indexClamped, key);    // returns a new Array
		this.setNextListInternal(newList);
		this.rebuild(nextChain);

		if(display.notNil) { display.showMutation(\addAt, [key, indexClamped], nextChain) };

	}

	removeAt { | index |
		var sizeNow, lastIndex, newList, removedKey;

		sizeNow = nextChain.size;
		lastIndex = sizeNow - 1;

		if(sizeNow <= 2) {
			"refuse to remove: need at least [sink, source]".postln;
		}{
			if((index == 0) or: { index == lastIndex }) {
				"refuse to remove sink or source".postln;
			}{
				removedKey = nextChain[index];
				newList = nextChain.copy;
				newList.removeAt(index);

				this.setNextListInternal(newList);
				this.bypassDictForListInternal(nextChain).removeAt(removedKey);

				this.rebuild(nextChain);
				("removed: " ++ removedKey).postln;

				if(display.notNil) { display.showMutation(\removeAt, [index, removedKey], nextChain) }; // removeAt

			}
		}
	}

	swap { | indexAParam, indexBParam |
		var lastIndex, indexA, indexB, newList, tempKey;

		lastIndex = nextChain.size - 1;

		indexA = indexAParam.clip(1, lastIndex - 1);
		indexB = indexBParam.clip(1, lastIndex - 1);

		if(indexA == indexB) {
			// nothing to do
		}{
			newList = nextChain.copy;
			tempKey = newList[indexA];
			newList[indexA] = newList[indexB];
			newList[indexB] = tempKey;

			this.setNextListInternal(newList);
			this.rebuild(nextChain);

			if(display.notNil) { display.showMutation(\swap, [indexA, indexB], nextChain) }; // swap

		}
	}

	clearChain {
		var sinkKey, sourceKey, newList;

		if(nextChain.size < 2) { ^this };

		sinkKey = nextChain[0];
		sourceKey = nextChain[nextChain.size - 1];

		newList = [sinkKey, sourceKey];
		this.setNextListInternal(newList);

		this.bypassDictForListInternal(nextChain).clear;
		this.rebuild(nextChain);

		if(display.notNil) { display.showMutation(\clearChain, [], nextChain) };        // clearChain

	}

	bypass { | key, state = true |
		var dict;
		dict = this.bypassDictForListInternal(nextChain);
		dict[key] = state;
		this.rebuild(nextChain);

		if(display.notNil) {
			display.showBypass(\next, key, state, nextChain, this.bypassKeysForListInternal(nextChain));
		};
	}

	bypassAt { | index, state = true |
		var lastIndex, clampedIndex, keyAtIndex;
		lastIndex = nextChain.size - 1;
		clampedIndex = index.clip(1, lastIndex - 1);
		keyAtIndex = nextChain[clampedIndex];
		this.bypass(keyAtIndex, state);
	}

	// ---- current-chain bypass ------------------------------------------------

	bypassCurrent { | key, state = true |
		var dict;
		dict = this.bypassDictForListInternal(currentChain);
		dict[key] = state;
		this.rebuild(currentChain);

		if(display.notNil) {
			display.showBypass(\current, key, state, currentChain, this.bypassKeysForListInternal(currentChain));
		};

	}

	bypassAtCurrent { | index, state = true |
		var lastIndex, clampedIndex, keyAtIndex;
		lastIndex = currentChain.size - 1;
		clampedIndex = index.clip(1, lastIndex - 1);
		keyAtIndex = currentChain[clampedIndex];
		this.bypassCurrent(keyAtIndex, state);


	}

	// ---- diagnostics helpers -------------------------------------------------

	effectiveCurrent { ^this.effectiveListForInternal(currentChain) }
	effectiveNext    { ^this.effectiveListForInternal(nextChain) }
	bypassKeysCurrent { ^this.bypassKeysForListInternal(currentChain) }
	bypassKeysNext    { ^this.bypassKeysForListInternal(nextChain) }

	reset {
		var sinkAKey, sinkBKey;
		sinkAKey = \chainA;
		sinkBKey = \chainB;

		chainAList = [sinkAKey, defaultSource];
		chainBList = [sinkBKey, defaultSource];

		bypassA.clear;
		bypassB.clear;

		currentChain = chainAList;
		nextChain = chainBList;

		this.rebuild(nextChain);
		this.rebuild(currentChain);

		Ndef(sinkBKey).stop;
		Ndef(sinkAKey).play(numChannels: defaultNumChannels);


		if(display.notNil) { display.showReset(currentChain, nextChain) };

	}

	// ───────────────────────────────────────────────────────────────
	// internal helpers (lowercase, no leading underscore)
	// ───────────────────────────────────────────────────────────────

	setNextListInternal { | newList |
		if(nextChain === chainAList) { chainAList = newList; nextChain = chainAList; }
		{ chainBList = newList; nextChain = chainBList; }
	}

	bypassDictForListInternal { | listRef |
		^if(listRef === chainAList) { bypassA } { bypassB }
	}

	bypassKeysForListInternal { | listRef |
		var dict, keysBypassed;
		dict = this.bypassDictForListInternal(listRef);
		keysBypassed = Array.new;
		dict.keysValuesDo { |key, state| if(state == true) { keysBypassed = keysBypassed.add(key) } };
		^keysBypassed
	}





	ensureStereoInternal { | key |
		var proxyBus;
		proxyBus = Ndef(key).bus;
		if(proxyBus.isNil or: { proxyBus.rate != \audio } or: { proxyBus.numChannels != defaultNumChannels }) {
			Ndef(key).ar(defaultNumChannels);  // pre-arm bus as audio/stereo
		};
	}

	effectiveListForInternal { | listRef |
		var dict, resultList, lastIndex;

		dict = this.bypassDictForListInternal(listRef);
		resultList = Array.new;
		lastIndex = listRef.size - 1;

		listRef.do { |key, index|
			var isProcessor, isBypassed;
			isProcessor = (index > 0) and: (index < lastIndex);
			isBypassed = isProcessor and: { dict[key] == true };
			if((index == 0) or: { index == lastIndex }) {
				resultList = resultList.add(key);            // keep sink & source
			}{
				if(isBypassed.not) { resultList = resultList.add(key) };
			};
		};

		^resultList
	}

	rebuild { | listRef |
		var effective, index, leftKey, rightKey, sinkKey;
		var which;

		if(listRef.size < 2) { ^this };

		effective = this.effectiveListForInternal(listRef);
		effective.do { |key| this.ensureStereoInternal(key) };

		index = 0;
		while { index < (effective.size - 1) } {
			leftKey = effective[index];
			rightKey = effective[index + 1];
			Ndef(leftKey) <<> Ndef(rightKey);
			index = index + 1;
		};

		sinkKey = effective[0];
		if(listRef === currentChain) { Ndef(sinkKey).play(numChannels: defaultNumChannels) }
		{ Ndef(sinkKey).stop };

		which = (listRef === currentChain).if(\current, \next);

		if(display.notNil) { display.showRebuild(which, listRef, effective) };

	}

	// --- source setters (public) ---

	setSource { | key |
		var newList, lastIndex;
		lastIndex = nextChain.size - 1;
		newList = nextChain.copy;
		newList[lastIndex] = key;
		this.setNextListInternal(newList);
		this.rebuild(nextChain);

		if(display.notNil) { display.showMutation(\setSource, [key], nextChain) };           // setSource

	}

	setSourceCurrent { | key |
		var newList, lastIndex;
		lastIndex = currentChain.size - 1;
		newList = currentChain.copy;
		newList[lastIndex] = key;
		if(currentChain === chainAList) {
			chainAList = newList; currentChain = chainAList;
		}{
			chainBList = newList; currentChain = chainBList;
		};
		this.rebuild(currentChain);

		if(display.notNil) { display.showMutation(\setSourceCurrent, [key], currentChain) }; // setSourceCurrent
	}
}
