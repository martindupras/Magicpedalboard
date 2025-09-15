# MagicPedalboardNew – RUNBOOK (v0.3.8) — Test‑Signal Only

**Today’s rule:** NO MIC. `\ts0` is overridden to an internal test source.

## Steps
1) Boot the server.
2) Open `MPB_Scenarios_v6.scd` in SuperCollider.
3) Evaluate from the top, **line by line**.
4) Audio sanity:
```supercollider
~pedalboard.reset;
~pedalboard.setSource(\testmelody);
~pedalboard.switchChain(0.1);
~pedalboard.add(\delay);
~pedalboard.switchChain(0.1);
Ndef(\delay).set(\mix, 0.55, \time, 0.45, \fb, 0.4);
