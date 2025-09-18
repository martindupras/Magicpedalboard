/* MagicDisplay.sc  v0.1.3
   Console display adaptor for MagicPedalboardNew.
   Prints structured messages now; later you can subclass with a real GUI.
   // MD 20250912-1345
*/

MagicDisplay : Object {

	classvar < version, < metersReady, < meterChannels;

	var < logLevel;  // 0 = silent, 1 = normal, 2 = verbose


	*initClass {
		version = "v0.1.3";
		("MagicDisplay " ++ version).postln;

		// default compile-time meter channel count
		meterChannels = 2;
		metersReady = false;

		// define (or re-define) the meter SynthDefs now
		this.ensureMeterDefs(meterChannels);
	}


	*new { |level = 1|
		^super.new.init(level)
	}

	init { |level|
		var initialLevel;
		initialLevel = level ? 1;
		logLevel = initialLevel;
		^this
	}

	help {
		var text;
		text = "MagicDisplay " ++ version
		++ "\nMethods:\n"
		++ "  showInit(pedalboard, versionString, current, next)\n"
		++ "  showRebuild(which, fullChain, effective)\n"
		++ "  showPlay(sink), showStop(sink), showSwitch(oldSink, newSink, current, next)\n"
		++ "  showMutation(action, args, nextChain)\n"
		++ "  showBypass(which, key, state, chain, bypassKeys)\n"
		++ "  showReset(current, next), showChains(current, next, bypassA, bypassB)\n"
		++ "  showChainsDetailed(current, next, bypassA, bypassB, effCurrent, effNext)\n"
		++ "  showError(message)\n";
		text.postln;
	}

	showInit { |pedalboard, versionString, current, next|
		if(logLevel > 0) { ("[MPB:init] " ++ versionString ++ "  current=" ++ current ++ "  next=" ++ next).postln };
	}

	showRebuild { |which, fullChain, effective|
		if(logLevel > 0) { ("[MPB:rebuild:" ++ which ++ "] full=" ++ fullChain ++ "  effective=" ++ effective).postln };
	}

	showPlay { |sinkKey|
		if(logLevel > 0) { ("[MPB:play] sink=" ++ sinkKey).postln };
	}

	showStop { |sinkKey|
		if(logLevel > 0) { ("[MPB:stop] sink=" ++ sinkKey).postln };
	}

	showSwitch { |oldSink, newSink, current, next|
		if(logLevel > 0) {
			("[MPB:switch] " ++ oldSink ++ " → " ++ newSink
				++ "  current=" ++ current ++ "  next=" ++ next).postln;
		};
	}

	showMutation { |action, args, nextChain|
		if(logLevel > 0) { ("[MPB:mutate] " ++ action ++ " " ++ args ++ "  next=" ++ nextChain).postln };
	}

	showBypass { |which, key, state, chain, bypassKeys|
		if(logLevel > 0) {
			("[MPB:bypass:" ++ which ++ "] " ++ key ++ " -> " ++ state
				++ "  chain=" ++ chain ++ "  activeBypass=" ++ bypassKeys).postln;
		};
	}

	showReset { |current, next|
		if(logLevel > 0) { ("[MPB:reset] current=" ++ current ++ "  next=" ++ next).postln };
	}

	showChains { |current, next, bypassAKeys, bypassBKeys|
		if(logLevel > 0) {
			"MagicPedalboardNew.printChains:".postln;
			("A: " ++ current ++ "   bypassA: " ++ bypassAKeys).postln;
			("B: " ++ next    ++ "   bypassB: " ++ bypassBKeys).postln;
		};
	}

	showChainsDetailed { |current, next, bypassAKeys, bypassBKeys, effCurrent, effNext|
		var header, formatOne;

		if(logLevel <= 0) { ^this };

		header = { |titleString| ("==== " ++ titleString ++ " ====").postln };

		formatOne = { |titleString, listRef, bypassKeys, effective|
			var sinkKey, sourceKey, lastIndex, indexCounter, lineText;

			lastIndex = listRef.size - 1;
			sinkKey = listRef[0];
			sourceKey = listRef[lastIndex];

			header.(titleString);
			("sink : " ++ sinkKey).postln;

			indexCounter = 1;
			if(listRef.size > 2) {
				"procs:".postln;
				listRef.copyRange(1, lastIndex - 1).do { |procKey|
					var isBypassed, mark;
					isBypassed = bypassKeys.includes(procKey);
					mark = if(isBypassed) { "BYP" } { "ON " };
					lineText = ("  [" ++ indexCounter ++ "] " ++ procKey ++ "  (" ++ mark ++ ")");
					lineText.postln;
					indexCounter = indexCounter + 1;
				};
			}{
				"procs: (none)".postln;
			};

			("src  : " ++ sourceKey).postln;
			("eff  : " ++ effective.join("  ->  ")).postln;
			"".postln;
		};

		formatOne.("CURRENT", current, bypassAKeys, effCurrent);
		formatOne.("NEXT",    next,    bypassBKeys, effNext);
	}

	showError { |message|
		("[MPB:error] " ++ message).warn;
	}

	// ----- meter SynthDefs (class-level) -----

	*ensureMeterDefs { arg ch = 2;
		var n;
		// clamp to a sensible positive integer
		n = ch.asInteger.max(1);
		meterChannels = n;

		// Define (or re-define) once per class init (safe to call again after recompile).
		// Uses compile-time channel count 'n' inside the UGen graph.
		Server.default.bind({
			SynthDef(\busMeterA, { arg inBus, rate = 15;
				var sig  = In.ar(inBus, n);                 // compile-time 'n'
				var amp  = Amplitude.ar(sig).clip(0, 1);    // per-channel amplitude
				SendReply.kr(Impulse.kr(rate), '/ampA', A2K.kr(amp));
			}).add;

			SynthDef(\busMeterB, { arg inBus, rate = 15;
				var sig  = In.ar(inBus, n);
				var amp  = Amplitude.ar(sig).clip(0, 1);
				SendReply.kr(Impulse.kr(rate), '/ampB', A2K.kr(amp));
			}).add;
		});

		metersReady = true;
	}

	*setMeterChannels { arg ch = 2;
		// convenience: re-emit defs with a new compile-time channel count
		this.ensureMeterDefs(ch);
	}

}
