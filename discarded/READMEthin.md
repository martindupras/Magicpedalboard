
# MagicPedalboardNew – JITLib/Ndef A/B Pedalboard

**Versions**
- `MagicPedalboardNew.sc` **v0.3.8**
- `MagicDisplay.sc` **v0.1.2**
- `MagicDisplayGUI.sc` **v0.2.3**

## Overview
`MagicPedalboardNew` manages two parallel JITLib Ndef chains (`\chainA` and `\chainB`) for live performance. One chain is CURRENT (audible), the other is NEXT (prepared silently). You can mutate NEXT and then switch to it using a short crossfade.

## Architecture
- Chains are Arrays of Symbols: `[sink, … processors …, source]`
- Sinks: `\chainA`, `\chainB`
- Sources/processors: other Ndef keys (e.g., `	sSaw`, `	remolo`)
- Bypass tracked per chain using dictionaries
- Effective list excludes bypassed processors

## Display Adaptors
### MagicDisplay
- Console logger with `logLevel`
- Methods: `showInit`, `showRebuild`, `showPlay`, `showStop`, `showSwitch`, etc.

### MagicDisplayGUI
- Two columns: CURRENT (green) and NEXT (neutral)
- Top-down flow: source → processors → sink
- Expectation field + visual countdown
- Operations panel with Next button
- Embedded level meters
- UI-ready queue prevents nil errors

## Style Rules
- Methods start lowercase; no leading underscore
- All `var` declarations first in every method and block
- Descriptive variable names
- No `server.sync`
- Use `Server.default.bind { … }` for server ops
- Safe reset only in `reset` using `Server.default.waitForBoot { … }`
- Space after accessors (e.g., `classvar < version;`)
- File headers include filename and timestamp like `//MD 20250912-1544`

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

## Troubleshooting
- No sound: check source Ndefs and output device
- Meters update but silent: check routing
- GUI errors: use latest GUI with UI-ready queue
- `'s' not defined`: use `Server.default` in class files

## Version Highlights
- v0.3.8: No reference to `s`; safe reset only in `reset`
- v0.3.5–0.3.7: Crossfade switching, server ops cleanup
- MagicDisplayGUI v0.2.3: GUI with countdown, ops list, meters
