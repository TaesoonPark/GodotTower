# MCP Guide (GodotTower)

Last updated: 2026-05-07

## Purpose
This file is the single reference for:
- MCP runtime selection
- playtest execution flow
- Context7 documentation lookup
- optional external MCP runtime notes
- TDD usage guidance

## Default MCP Runtime Pair

Current project default is a two-server MCP setup:

- `godot`: run/playtest/debug feedback through `@coding-solo/godot-mcp`
- `context7`: current external library and API documentation through `@upstash/context7-mcp`
- Shared config: `mcp/godot-mcp.shared.json`
- Cursor project config: `.cursor/mcp.json`

Godot bootstrap:

```bash
bash scripts/start-godot-mcp.sh
```

Context7 stdio bootstrap:

```bash
npx -y @upstash/context7-mcp
```

`CONTEXT7_API_KEY` is optional, but recommended if Context7 rate limits become a problem.

## Codex MCP Registration

The current machine has these global Codex MCP servers registered:

```bash
codex mcp add godot --env DEBUG=true -- bash "$(pwd)/scripts/start-godot-mcp.sh"
codex mcp add context7 -- npx -y @upstash/context7-mcp
codex mcp list
```

After changing MCP config, restart the Codex session so the new tools are loaded.

Use `godot` MCP for project execution and debug output. Use `context7` when a task depends on current Godot, GDScript, MCP, or external package documentation.

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
npm view @upstash/context7-mcp version

# MCP bootstrap checks
npx -y @upstash/context7-mcp --help
codex mcp list
```

## Archive

Pre-integration docs were archived at:

`docs/archive/2026-04-19/`
