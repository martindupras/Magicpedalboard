// demo_commandtree_apply_hotfix.scd
// v0.1
// MD 20250916-1020

(
var log;

log = { arg m; ("[DEMO] " ++ m).postln };

// Ensure adapter is loaded; if not, evaluate adapter_commandtree_to_magicpedalboard.scd
if(~ct_sendAndApply.isNil) {
    "[DEMO] Please evaluate adapter_commandtree_to_magicpedalboard.scd first.".warn;
};

// Reload CommandManager (imports your updated JSON with payloads)
~cm = CommandManager.new;
log.("CommandManager reloaded.");

// 1) add delay on NEXT
~cm.midiManager.queue.clear;
~cm.midiManager.queue.enqueueCommand(\add);
~cm.midiManager.queue.enqueueCommand(\delay);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 2) switch to hear delay on CURRENT
~cm.midiManager.queue.enqueueCommand(\switch);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

// 3) bypass delay ON → OFF → final switch
~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\on);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

~cm.midiManager.queue.enqueueCommand(\bypass);
~cm.midiManager.queue.enqueueCommand(\delay);
~cm.midiManager.queue.enqueueCommand(\off);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

~cm.midiManager.queue.enqueueCommand(\switch);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

~pedalboard.printChains;
)
