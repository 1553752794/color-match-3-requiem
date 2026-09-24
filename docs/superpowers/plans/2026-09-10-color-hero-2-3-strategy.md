# 2.3 Strategy Implementation Plan

**Goal:** Deliver the playable layer in production/gameplay-design/v2_3_strategy_spec.md.
**Architecture:** StrategyRules holds policies; ChapterProjects owns progress; GameManager transacts resources/save state; Main composes council/previews.
**Tech Stack:** Godot 4.6.3, GDScript, SceneTree tests, Windows export.
**Spec:** production/gameplay-design/v2_3_strategy_spec.md.

## Constraints

Keep combat and map topology intact. No new currency, save reset, generated import edits or unrelated refactor. No usable Git repository exists. Continue without approval checkpoints as requested.

## Execution

- [x] Inspect 2.2 baseline and incomplete 2.3 integration.
- [ ] Add failing tests for eligibility, chapter replacement, tradeoffs, negative payment and old-save restore.
- [ ] Implement policy boundaries and real battle/price hooks.
- [ ] Implement ChapterProjects with independent tests; integrate start_project, node completion and save/restore.
- [ ] Implement camp conversion transaction with shortage/replay tests.
- [ ] Implement council view/node forecast; verify interaction and layout at 1280×720 and 1600×900.
- [ ] Run all tests using tools/run_all_tests.ps1 and isolated profiles.
- [ ] Align project/save/export/launcher/release tests to 2.3.0.
- [ ] Export Windows with normal APPDATA, verify exported startup, update factual audit.
