# Project Status (GodotTower)

Last updated: 2026-04-19

## Purpose
This file is the single status entry for:
- current project snapshot
- active TODO priorities
- recent change highlights

Detailed historical logs and previous status documents are archived under:

`docs/archive/2026-04-19/`

## Current Snapshot

- Core loop: RTS selection/move, job assignment, build/gather/haul/craft/research/combat paths are present.
- UI: top resources, left roster, right selection detail, bottom command/catalog layout are integrated.
- Test assets: smoke/parity scenes are present in `scenes/tests/`.
- Runtime workflow: headless smoke, parity suite, GUI playtest, and self-check scripts are available.

## Active TODO (Priority)

### High
- Construction resource flow hardening and cancellation/recovery paths.
- Build interaction expansion (wall/door and related site handling quality).
- Stability improvements for build/haul edge cases.

### Medium
- Workstation and craft queue UX refinements.
- Haul/storage behavior consistency for edge scenarios.
- Combat/balance tuning with regression-safe validation.

### Low
- Camera/UI polish and responsiveness improvements.
- Additional content/data expansion beyond current baseline.

## Recent Highlights

### 2026-04-19
- Added stockpile bed selection + stockpile icon smoke coverage.
- Added craft repeat queue smoke coverage.

### 2026-04-04
- Standardized MCP runtime path around external `@coding-solo/godot-mcp`.
- Consolidated MCP/playtest setup scripts and documentation.

### 2026-03-26
- Expanded stockpile filter/priority/limit behavior.
- Improved haul reservation/assignment reliability.
- Extended craft queue controls and related validation.

## Verification Baseline

Use these as minimum regression checks:

```bash
python3 scripts/check_encoding.py --all
bash scripts/run-playtest.sh
bash scripts/run-parity-suite.sh
bash scripts/self-check.sh
```

