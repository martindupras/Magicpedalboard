// demo_apply_after_fix.scd
// v0.1
// MD 20250916-1031

(
var log;

log = { arg m; ("[DEMO] " ++ m).postln };

// Adapter must be present
if(~ct_sendAndApply.isNil) {
    "[DEMO] Please evaluate adapter_commandtree_to_magicpedalboard.scd first.".warn;
};

// Reload CommandManager (imports your JSON with payloads/verbs)
~cm = CommandManager.new;
log.("CommandManager reloaded.");

// Sequence: add delay -> switch -> bypass on -> bypass off -> switch
~cm.midiManager.queue.clear;
~cm.midiManager.queue.enqueueCommand(\add);
~cm.midiManager.queue.enqueueCommand(\delay);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

~cm.midiManager.queue.enqueueCommand(\switch);
~ct_sendAndApply.(~cm, ~pedalboard, ~gui);

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
