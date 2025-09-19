// Test_CommandTree_To_AudioBridge.scd
// v0.6.2
// MD 20250919-09:16 BST

/*
Purpose
- Bridge Command Tree -> Audio + GUI:
  - Simulate 3–5–7 → \queue → \send (demo).
  - Map OSC tokens (strings; hyphen-safe) to NEXT (B) effect.
  - Ignore trivial paths like "/audio".
  - Passive observer watches ~commandToSend for real SENDs.

Style
- var-first; AppClock-only; no server.sync.
*/

(
var ensureDeps, buildEffectMap, simulatePath_3_5_7, queueAndSend, reflectOsc, startObserver;

ensureDeps = {
    var run;
    run = {
        if(~fx.isNil or: { ~applyToNext.isNil }) {
            "[ERROR] Audio helpers not found. Run Test_MagicAudio_BringUp_A_B.scd first.".warn;
        };
        ~ct = ~ct ?? { CommandManager.new };
        if(~ct.display.notNil and: { ~ct.display.window.notNil }) { ~ct.display.window.front };
        if(~gui.isNil) { "[WARN] ~gui not present (GUI optional). Proceeding…".postln };
        "[CT] CommandManager ready".postln;
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

buildEffectMap = {
    var run;
    run = {
        ~ctFxMapS = IdentityDictionary[
            "single-delay" -> \delay,
            "delay"        -> \delay,
            "echo"         -> \delay,
            "freeverb"     -> \reverb,
            "reverb"       -> \reverb,
            "chorus"       -> \chorus,
            "tremolo"      -> \tremolo,
            "flanger"      -> \flanger
        ];
        "[CT] Effect token map (string-keyed) installed".postln;
        nil
    };
    AppClock.sched(0.02, { run.value; nil });
};

reflectOsc = { arg pathStr;
    var run;
    run = {
        var tokens, effTok, effSym, hasMeaning;
        var current, next, effC, effN, bA, bB;

        tokens = pathStr.asString.split($/).reject(_.isEmpty);
        hasMeaning = (tokens.size >= 2); // ignore "/audio" or similar one-token paths
        if(hasMeaning.not) {
            ("[CT] Ignoring trivial path: " ++ pathStr).postln;
        }{
            effTok = tokens.reverse.detect({ arg t; ~ctFxMapS.includesKey(t.asString) });
            effSym = (effTok.isNil).if({ \delay }, { ~ctFxMapS[effTok.asString] });

            ~applyToNext.(effSym);

            if(~gui.notNil) {
                ~gui.showExpectation("CT SEND → " ++ pathStr, 0);
                current = [\chainA, \testmelody];
                next    = [\chainB, effSym, \testmelody];
                effC = current; effN = next; bA=[]; bB=[];
                ~gui.showChainsDetailed(current, next, bA, bB, effC, effN);
            };
        };
        nil
    };
    AppClock.sched(0.00, { run.value; nil });
};

simulatePath_3_5_7 = {
    var run;
    run = {
        var mm, gh;
        mm = ~ct.midiManager; gh = mm.guitarHandler;

        mm.setMode(mm.modes[\prog]); // resets nav, starts at string 6
        gh.handleMessage(0, \noteOn, 43); 0.12.wait; // fret 3 on string 6
        gh.handleMessage(1, \noteOn, 50); 0.12.wait; // fret 5 on string 5
        gh.handleMessage(2, \noteOn, 57); 0.08.wait; // fret 7 on string 4

        if(~gui.notNil) { ~gui.showExpectation("CT PROG: 3–5–7 reached. Queue when ready.", 0) };
        nil
    };
    Routine({ run.value }).play(AppClock);
};

queueAndSend = {
    var run;
    run = {
        var mm, path;
        mm = ~ct.midiManager;
        mm.setMode(mm.modes[\queue]); 0.08.wait;
        mm.setMode(mm.modes[\send]);  0.08.wait;

        path = ~ct.midiManager.queue.exportAsOSCPath;
        ("[CT] OSC path exported: " ++ path).postln;
        reflectOsc.value(path);

        "[CT] Applied effect to NEXT; call ~switchNow.() to promote".postln;
        nil
    };
    Routine({ run.value }).play(AppClock);
};

startObserver = {
    var run;
    run = {
        var lastSeen;
        lastSeen = "";
        if(~ctObserver.notNil) { AppClock.clear(~ctObserver); ~ctObserver = nil };
        ~ctObserver = AppClock.sched(0.20, {
            var currentStr, tokens, hasMeaning;
            currentStr = (~commandToSend ? "").asString;
            if(currentStr.size > 0 and: { currentStr != lastSeen }) {
                tokens = currentStr.split($/).reject(_.isEmpty);
                hasMeaning = (tokens.size >= 2);
                if(hasMeaning) {
                    ("[CT OBS] detected SEND: " ++ currentStr).postln;
                    reflectOsc.value(currentStr);
                }{
                    ("[CT OBS] ignoring trivial path: " ++ currentStr).postln;
                };
                lastSeen = currentStr;
            };
            0.20  // reschedule
        });
        "[CT] Observer started (listening to ~commandToSend)".postln;
        nil
    };
    AppClock.sched(0.10, { run.value; nil });
};

// ---- run sequence ----
ensureDeps.value;
buildEffectMap.value;

// Demo pass (comment out if using real controller later)
AppClock.sched(0.25, { simulatePath_3_5_7.value; nil });
AppClock.sched(1.10, { queueAndSend.value; nil });

// Passive observer for real SENDs
startObserver.value;
)
