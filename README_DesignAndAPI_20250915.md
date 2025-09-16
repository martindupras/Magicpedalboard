<!-- Filename: README_DesignAndAPI_20250915.md -->

# Design highlights (SC 3.14, macOS, Qt)

- All GUI work is scheduled on AppClock.
- No `server.sync`.
- No watchers or background polling in the runner.
- Exactly one GUI window: duplicates are closed or a live one is reused.
- Deterministic runs are token-gated; stale scheduled steps are ignored.
- Scripts/tests follow style: tilde interpreter vars, lowercase names, `var` at top of each block, no single-letter locals, and no `^` in .scd scripts.
- Do not override or monkey-patch `queueUi`. Call it if present; otherwise skip.

## Architecture

- MagicPedalboardNew manages two chains (`\chainA`, `\chainB`) built from Ndefs.
- Chains are arrays of symbols: `[sink, ... processors ..., source]`.
- Crossfading `switchChain` swaps CURRENT and NEXT with a short fade.
- MagicDisplay is a console adaptor.
- MagicDisplayGUI is a Qt GUI that shows CURRENT / NEXT lists, an expectation box, countdown, and optional meters.
- MagicProcessorLibrary registers processors/sources and ensures the corresponding Ndefs exist.

---

# Class summaries & key API

## MagicPedalboardNew (Object)

- Role: Manage A/B chains of Ndefs; maintain bypass state; rebuild non-destructively; notify display.
- Construction:
  - `MagicPedalboardNew.new(displayOrNil)`
- Playback:
  - `playCurrent`
  - `stopCurrent`
  - `switchChain(fadeTime = 0.1)`  // short crossfade, clamps to a safe range
- Mutators (operate on NEXT):
  - `add(key)`
  - `addAt(key, index)`
  - `removeAt(index)`
  - `swap(indexA, indexB)`
  - `clearChain`
- Bypass:
  - NEXT: `bypass(key, state=true)`, `bypassAt(index, state=true)`
  - CURRENT: `bypassCurrent(key, state=true)`, `bypassAtCurrent(index, state=true)`
- Sources:
  - `setSource(key)`            // NEXT
  - `setSourceCurrent(key)`     // CURRENT
- Diagnostics:
  - `printChains`
  - `effectiveCurrent`, `effectiveNext`
  - `bypassKeysCurrent`, `bypassKeysNext`
  - `reset`
- Notes:
  - Rebuilds run in `Server.default.bind { ... }` after `ensureServerTree`.
  - A small helper normalizes Ndef channel counts before connections.
  - Pair connections use JITLib’s `<<>>` operator to embed/patch Ndefs.

## MagicDisplay (Object)

- Role: Console display adaptor.
- Selected methods:
  - `showInit(ped, versionString, current, next)`
  - `showRebuild(which, fullChain, effective)`
  - `showPlay(sink)`, `showStop(sink)`
  - `showSwitch(oldSink, newSink, current, next)`
  - `showMutation(action, args, nextChain)`
  - `showBypass(which, key, state, chain, bypassKeys)`
  - `showReset(current, next)`
  - `showChains`, `showChainsDetailed(...)`
  - `showError(message)`

## MagicDisplayGUI (MagicDisplay)

- Role: Visual GUI for CURRENT/NEXT chains, expectation/countdown, operations list, optional A/B meters.
- Construction:
  - `MagicDisplayGUI.new()`   // builds the window from `initGui` on AppClock
- UI queue:
  - `queueUi { |f| ... }`     // buffers until views exist; then runs on AppClock
- Visualization:
  - `highlightCurrentColumn`
  - `formatListTopDown(listRef, bypassKeys, effectiveList)`
- Expectation & countdown:
  - `showExpectation(text, seconds=0)`
  - `startCountdown(seconds, labelText, onFinished)`
- Operations pane:
  - `setOperations(items)`
  - `setNextAction(func)`
  - `runNextOperation(index)`
  - `updateOpsHighlight`
- Meters:
  - `enableMeters(flag=true)`  // may define lightweight meter SynthDefs on demand
- Display hooks:
  - Overrides `showInit / showRebuild / showPlay / showStop / showSwitch / showMutation / showBypass / showReset / showChainsDetailed / showError`.

## MagicProcessorLibrary (Object)

- Role: Registry for processors/sources; server helpers to ensure Ndefs exist.
- API:
  - `register(key, func)`
  - `has(key)`, `get(key)`, `keys`
  - `ensure(key, chans=2)`
  - `ensureMany(keyArray, chans=2)`
  - `ensureFromChain(chainArray, chans=2)`
