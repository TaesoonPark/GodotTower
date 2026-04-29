# MCP Guide (GodotTower)

Last updated: 2026-04-29

## Purpose
This file is the single reference for:
- MCP runtime selection
- playtest execution flow
- optional external MCP runtime notes
- TDD usage guidance

## Default MCP Runtime

Current project default is `@coding-solo/godot-mcp`.

- Config: `mcp/godot-mcp.shared.json`
- Bootstrap: `scripts/start-godot-mcp.sh`
- Launch command:

```bash
npx -y @coding-solo/godot-mcp
```

## Advanced MCP Runtime (Optional External)

GoPeak is not vendored in this repository. If a future task needs it, run it as
an external MCP runtime and keep final pass/fail checks on repository tests.

- Typical launch:

```bash
npx -y gopeak
```

## Feature Comparison

| Area | `@coding-solo/godot-mcp` | `gopeak` |
|---|---|---|
| Core run loop | Run/stop project and collect logs | Same + wider surrounding tools |
| Tool surface | Compact and simple | Large surface (core + dynamic groups) |
| Debug depth | Log-driven | LSP + DAP + runtime inspection |
| UI/input testing | Basic | Input injection + screenshot/viewport capture |
| MCP capabilities | Tool-focused | Tools + `godot://` resources + prompts |
| Operational complexity | Lower | Higher |

## TDD Guidance

1. Default red-green-refactor loop:
   - Use default MCP (`@coding-solo/godot-mcp`) for run/log iteration.
   - Keep pass/fail authoritative with repository tests.

2. Use `gopeak` when:
   - Root-cause analysis needs LSP/DAP/runtime visibility.
   - Input or screenshot-driven reproduction is needed.
   - Advanced scene/resource operations are required in one MCP flow.

3. Final verification rule:
   - Always finish with repository scripts, regardless of MCP server.

## Playtest Commands

### Headless smoke

```bash
bash scripts/run-playtest.sh
PLAYTEST_INCLUDE_RAID=1 bash scripts/run-playtest.sh
```

### Parity suite

```bash
bash scripts/run-parity-suite.sh
```

### GUI playtest

```bash
bash scripts/run-gui-playtest.sh
```

### Full self-check

```bash
bash scripts/self-check.sh
```

## Environment Setup

If Godot Linux binary / GUI venv is missing:

```bash
bash scripts/setup-playtest-env.sh
```

## Maintenance Checklist

```bash
# Published versions
npm view @coding-solo/godot-mcp version
```

## Archive

Pre-integration docs were archived at:

`docs/archive/2026-04-19/`
