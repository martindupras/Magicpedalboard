## ② Monday‑morning status summary

**What’s working now**
- **Core A/B engine** (`MagicPedalboardNew v0.3.8`):
  - Stable **non‑destructive rebuilds** (no resets in rebuild path).
  - **Crossfade switching** (default 100 ms, clamped 80–200 ms).
  - **NEXT‑chain mutations**: `add`, `addAt`, `removeAt`, `swap`, `clearChain`.
  - **Bypass** on NEXT and CURRENT, with **effective** list logic.
  - **Source setters**: `setSource` (NEXT) and `setSourceCurrent` (CURRENT).
  - **Wiring** via `Ndef(left) <<> Ndef(right)`; **bus ar()** ensured per key.

- **Displays**:
  - `MagicDisplay v0.1.2` prints structured events.
  - `MagicDisplayGUI v0.2.3` adds **CURRENT in green**, **src→procs→sink**, **what to listen for**, **visual countdown**, **ops list + Next**, and **embedded meters** with nil‑safe updates.

- **Safety + Style**:
  - **No `server.sync`**.
  - Server ops inside **`Server.default.bind`** only.
  - **Safe reset** only in `reset` and in **tests** (preflight clears proxies; no double frees).
  - **Var‑first** and **lowercase method names** enforced across the latest drops.

**Recent fixes**
- Removed destructive reset calls from `rebuild` path (these were killing audio).
- Replaced any `s.*` with **`Server.default.*`** (class‑safe).
- GUI `OutOfContextReturn` and `items_/value_ to nil` were fixed via **UI‑ready queue** and avoiding `^` in inner functions.
- Preflight cleanup now **clears** Ndefs without extra `.stop` to avoid `/n_free … not found`.

**Still to do / polish**
1. **GUI**
   - Add **parameter badges** for processors (e.g., `\tremolo (rate=4, depth=0.8)`), with live refresh.
   - **Tint the CURRENT meter row** (flip on switch) for faster recognition.
   - Optional: a tiny **output device / channels** display to catch routing issues quickly.

2. **Tests**
   - Expand parameter sweep tests and add automatic **level assertions** (e.g., envelope above threshold).
   - Include **bypass edge cases** (multiple processors, removal while bypassed).

3. **API refinements**
   - Expose a **global default crossfade** setter with bounds check.
   - Add **`ensureServerTree` diagnostics** when server is not running (optional `display.showError`).

**Known pitfalls to avoid**
- Don’t call any server reset in `rebuild`/`rebuildUnbound`.
- Don’t use `s` inside class files.
- Keep **var‑first** in **every** method and closure, including GUI `action_`, `drawFunc_`, `AppClock.sched`, and `Routine`.