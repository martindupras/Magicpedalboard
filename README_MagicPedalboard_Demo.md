
# Magic Pedalboard (SuperCollider) – Demo Readme

**Status**: demo-ready (visual + audio) • **Date**: 2025-09-19 09:27

This document explains what the Magic Pedalboard system does, how its demo works, how to run it, how the pieces fit together, and what to improve next. It is written for a third‑party developer who needs to understand and reproduce today’s demo in SuperCollider.

---

## 1) What the system is

Magic Pedalboard is a SuperCollider system for live guitar processing split into three layers:

1) Audio Engine (SC / JITLib)
   - Two processing chains using Ndef: Chain A (CURRENT) and Chain B (NEXT).
   - Option A safety: NEXT is muted at the source (built silently) and becomes audible only when switched.
   - Effects are attached with Ndef(\chainX).filter from a small effect dictionary (delay, reverb, chorus, tremolo).
   - A small set of helpers controls NEXT’s effect and toggles CURRENT/NEXT.

2) Display GUI (MagicDisplayGUI_GridDemo)
   - A single window named “MagicDisplayGUI – GridDemo” using GridLayout.
   - Row 0: two equal columns (CURRENT left, NEXT right).
   - Rows 1–4: full‑width blocks for expectation, countdown, thin meters (~30 px), and a bottom Processors panel.
   - No mouse interaction required; it reflects state changes from code.

3) Command Tree + MIDI (classes provided)
   - CommandManager / MDCommandTree / MDCommandNode / MDCommandBuilder / MDCommandQueue / MIDIInputManager
   - Modes: \idle, \prog (navigate by fretted notes), \queue (enqueue payload), \send (export OSC path).
   - A bridge maps the exported OSC path tail (e.g. single-delay, freeverb) to an effect symbol and applies it to NEXT.

---

## Resume Prompt

Resume: Magic Pedalboard (SuperCollider) — continue where we left off.

Context snapshot:
- Audio working with JITLib Ndefs: Chain A (CURRENT, audible) and Chain B (NEXT, Option A muted at source). Effects via Ndef(\chainX).filter.
- GUI = MagicDisplayGUI_GridDemo using GridLayout. Row 0 is two equal columns; rows 1–4 are full width (expectation, countdown, thin meters ~30 px, bottom Processors). Visual-only (no clicks).
- Command Tree classes present: CommandManager, MDCommandTree, MDCommandNode, MDCommandBuilder, MDCommandQueue, MIDIInputManager (+ handlers). Modes: \idle → \prog → \queue → \send. Bridge maps OSC tail tokens (e.g. single-delay, freeverb) to effect symbols and applies to NEXT.
- Runtime helpers: ~applyCTEffect.(\effect), ~clearNext.(), ~switchNow.(), ~audioReset.(). GUI–audio sync patch installed so headers/highlight/lists match ~currentIsA, and NEXT shows ~nextEffectSym.

Prescriptions / rules (must follow):
- SuperCollider style: var-first in every block/closure; method names lowercase; avoid single-letter locals; interpreter vars are ~lowercase; no loadRelative.
- GUI ops on AppClock only; no server.sync. Server ops inside Server.default.bind at boot. Safe resets: s.waitForBoot; s.initTree; s.defaultGroup.freeAll.
- For demos/tests: generated audio only; NO SoundIn.
- GUI: single window whose name begins with “MagicDisplayGUI”. Use GridLayout. Keep meters thin strips.
- Audio safety: enforce Option A (NEXT silent at source) until switched.
- When negating a var, multiply by -1 (e.g., depth * -1) instead of a bare unary minus on identifiers.

What to do next (priority):
1) Implement a 50–100 ms crossfade in ~switchNow (dual-gain fade, no clicks).
2) Map Command Tree payload parameters to effect params (e.g., delay time/feedback), with safe ranges and GUI reflection.
3) Confirm hex guitar MIDI routing (ch 0–5 → strings 6→1) and live fret navigation in \prog; integrate foot controller mode changes.
4) Optional: real meters (audio-driven) while keeping thin-strip look.
