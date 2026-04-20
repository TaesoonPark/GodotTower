# MCP Server Comparison (GodotTower)

Last updated: 2026-04-19

## Purpose
This document records practical differences between the two Godot MCP servers used around this repository, so future work can choose the right server for each task.

## Servers

### 1) `@coding-solo/godot-mcp` (basic)
- Repo: https://github.com/Coding-Solo/godot-mcp
- Current project wiring:
  - `mcp/godot-mcp.shared.json`
  - `scripts/start-godot-mcp.sh`
  - Actual launch: `npx -y @coding-solo/godot-mcp`
- Role in this repository: default/standard MCP path.

### 2) `gopeak` (advanced)
- Repo: https://github.com/HaD0Yun/Gopeak-godot-mcp
- Local vendored copy: `tools/gopeak-mcp/`
- Typical launch: `npx -y gopeak`
- Role in this repository: optional advanced debugging/inspection MCP.

## Version Snapshot (2026-04-19)
- `npm view @coding-solo/godot-mcp version` -> `0.1.1`
- `npm view gopeak version` -> `2.3.6`
- Vendored local GoPeak (`tools/gopeak-mcp/package.json`) -> `2.3.5`

## Functional Differences

| Area | `@coding-solo/godot-mcp` | `gopeak` |
|---|---|---|
| Core run loop | Run project, stop project, collect debug output | Same + richer surrounding tooling |
| Tool surface size | Small/minimal | Large (core + dynamic groups, 110+ total) |
| Script diagnostics | Basic log-driven | LSP diagnostics/completions/hover/symbols |
| Debugging | Basic runtime output | DAP breakpoints/step/stack trace + debug output |
| Runtime introspection | Limited | Runtime tree/property/method/metrics tools |
| Input and visual test actions | Limited | Input injection + screenshot/viewport capture tools |
| Resource/prompt capability | Primarily tools | Tools + `godot://` resources + MCP prompts |
| Complexity | Lower | Higher (more power, more moving parts) |

## TDD Guidance for This Repository

1. Default loop (recommended baseline):
   - Keep `@coding-solo/godot-mcp` as the default MCP.
   - Use repository scripts for objective pass/fail:
     - `bash scripts/run-playtest.sh`
     - `bash scripts/run-parity-suite.sh`
     - `bash scripts/self-check.sh`

2. Use GoPeak when:
   - Root-cause analysis needs deeper observability (LSP/DAP/runtime tree).
   - Input/screenshot automation is needed through MCP tools.
   - You need advanced scene/resource operations in one MCP session.

3. Keep final verification unchanged:
   - Regardless of MCP choice, final pass/fail should come from repository smoke/parity/self-check scripts.

## Operational Policy

1. Do not silently swap the project default MCP server.
2. If both servers are configured in one MCP client, use distinct names:
   - `godot_basic` -> `@coding-solo/godot-mcp`
   - `godot_advanced` -> `gopeak`
3. Prefer deterministic script-based regression checks before merge.

## Quick Maintenance Checklist

```bash
# Check published versions
npm view @coding-solo/godot-mcp version
npm view gopeak version

# Verify local GoPeak copy
cat tools/gopeak-mcp/package.json | grep '"version"'

# Smoke test advanced server (from repo root)
cd tools/gopeak-mcp
npm run smoke
```

