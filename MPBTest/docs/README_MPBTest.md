# MPBTest: Test Harness and Acceptance Suite

This folder contains the modular test harness and acceptance suite for the MagicPedalboard project. It is organized for clarity, reproducibility, and ease of extension.

---

## Folder Structure

- `Classes/`  
  Main test harness classes:
    - `MPBTest_BringUp.sc`
    - `MPBTest_Scenario.sc`
    - `MPBTest_AcceptanceSuites.sc`
    - `MPBTest_Assertions.sc`
- `Scripts/`  
  Utility and acceptance scripts:
    - `MPBTest_Run_HealthCheck.scd`
    - `MPBTest_Run_OneGo.scd`
    - `MPBTest_Record_WorkingState.scd`
    - `MPBTest_FreshBootBringUp_Now.scd`
    - `MPBTest_RebindAndFillGUI.scd`
    - `MPBTest_CloseRecreateBind_GUI_GridDemo.scd`
- `docs/`  
  Working state snapshots and documentation (add your Markdown or JSON here).
- `_archive/`  
  For archiving old or superseded test scripts and snapshots.

---

## Usage

```shell
# Health Check
sclang MPBTest/Scripts/MPBTest_Run_HealthCheck.scd

# Bring-Up
sclang MPBTest/Scripts/MPBTest_FreshBootBringUp_Now.scd

# Record Working State
sclang MPBTest/Scripts/MPBTest_Record_WorkingState.scd

# Run All Acceptance Tests
sclang MPBTest/Scripts/MPBTest_Run_OneGo.scd
```

---

## Conventions

- All test harness classes are in `Classes/` and use the `MPBTest_` prefix.
- Scripts in `Scripts/` are named for their function and are safe to run independently.
- Snapshots and documentation should be placed in `docs/`.
- Archive old scripts in `_archive/` to keep the suite clean.

_Last updated: 2025-09-20_
