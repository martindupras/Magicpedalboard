
# MagicPedalboardNew – A/B Chain Manager for Live Audio in SuperCollider

## Introduction
MagicPedalboardNew is a SuperCollider class designed to manage two parallel audio chains using JITLib's Ndef system. It is intended for live performance scenarios where one chain is actively producing sound (CURRENT), and the other is being prepared silently (NEXT). This allows performers to build or modify effects chains in real time and switch between them seamlessly.

## Design Philosophy
The system is built around the idea of non-destructive, real-time manipulation of audio chains. It avoids server resets during normal operation, ensuring stability and continuity of sound. All server interactions are safely wrapped using `Server.default.bind`, and resets are only performed in the `reset` method using `Server.default.waitForBoot`.

## Core Concepts
- **Chains**: Arrays of Symbols representing Ndef keys. Each chain is ordered `[sink, ...processors..., source]`.
- **CURRENT and NEXT**: Two chains, one active and audible (CURRENT), the other silent and editable (NEXT).
- **Switching**: A crossfade mechanism allows smooth transitions from CURRENT to NEXT.
- **Bypassing**: Individual processors can be bypassed without removing them.
- **Effective List**: The chain with bypassed processors removed, used for actual signal routing.

## Class Details
### MagicPedalboardNew
- `currentChain`, `nextChain`: Pointers to the active and editable chains.
- `chainAList`, `chainBList`: Concrete arrays for each chain.
- `bypassA`, `bypassB`: Dictionaries tracking bypassed processors.
- `defaultNumChannels`: Number of audio channels (typically 2).
- `defaultSource`: Default source Ndef key.
- `display`: Optional display adaptor (console or GUI).

### Methods
- `add`, `addAt`, `removeAt`, `swap`, `clearChain`: Modify NEXT chain.
- `bypass`, `bypassAt`: Bypass processors in NEXT.
- `bypassCurrent`, `bypassAtCurrent`: Bypass processors in CURRENT.
- `setSource`, `setSourceCurrent`: Set source for NEXT or CURRENT.
- `switchChain`: Crossfade from CURRENT to NEXT.
- `reset`: Safely reset server and chains.
- `rebuild`, `rebuildUnbound`: Wire chains using `<<>`.

## GUI Explanation
### MagicDisplayGUI
This GUI provides a visual representation of the CURRENT and NEXT chains:
- **Two Columns**: CURRENT (highlighted in green) and NEXT.
- **Top-Down Flow**: Chains are displayed from source (top) to sink (bottom), matching audio signal flow.
- **Expectation Field**: A text area describing what the user should hear. This helps performers anticipate changes.
- **Visual Countdown**: A numeric and graphical countdown timer appears before a change, allowing the performer to shift attention.
- **Operations Panel**: Lists upcoming actions with a "Next" button. Pressing it starts a 3-second countdown before executing the action.
- **Embedded Meters**: Real-time level indicators for chainA and chainB, helping monitor audio activity.

## Style Rules
- Methods start lowercase; no leading underscores.
- All `var` declarations appear first in every method and block.
- Descriptive variable names; no single-letter variables.
- No `server.sync`.
- Use `Server.default.bind { ... }` for server operations.
- Safe reset only in `reset` using `Server.default.waitForBoot { ... }`.
- Space after accessors (e.g., `classvar < version;`).
- File headers include filename and timestamp like `//MD 20250912-1544`.

## Quick Start
```supercollider
Ndef(	s0,  { Silent.ar(2) });
Ndef(	sSaw,{ Saw.ar(200, 0.18) ! 2 });
m = MagicPedalboardNew.new;
m.setSourceCurrent(	sSaw);
m.playCurrent;
m.setSource(	sSaw);
Ndef(	remolo, { arg rate = 4, depth = 0.8; var x = \in.ar(2); x * SinOsc.kr(rate).range(1 - depth, 1) });
m.add(	remolo);
m.switchChain(0.1);
```

## Advanced Usage
- Use `bypass` to temporarily disable processors.
- Use `swap` to reorder processors.
- Use `clearChain` to reset NEXT to `[sink, source]`.
- Use `printChains` or GUI to inspect chain structure.

## Troubleshooting
- No sound: Ensure sources are defined and server is running.
- Meters update but silent: Check audio routing and output device.
- GUI errors: Use latest GUI with UI-ready queue.
- `'s' not defined`: Use `Server.default` in class files.

## Version History
- v0.3.8: No reference to `s`; safe reset only in `reset`.
- v0.3.5–0.3.7: Crossfade switching, server ops cleanup.
- MagicDisplayGUI v0.2.3: GUI with countdown, ops list, meters.
