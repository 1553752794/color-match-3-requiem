# Codex Game Studio Context

This workspace has Claude Code Game Studios installed as a local game-development support layer.

## Installed Sources

- Upstream repository: `pixel-cellar/Claude-Code-Game-Studios`
- Local vendor copy: `.vendor/Claude-Code-Game-Studios`
- Installed Claude Code config: `.claude/`
- Installed shared docs: `docs/`
- Installed production workspace: `production/`
- Installed on: 2026-06-27
- Installed commit: `2c016ef53e7f6f5143cde15e0e1ddafb9f2b42d3`

## Current Game

- Project name: 色彩勇者：三消镇魂曲 MVP Demo
- Godot project path: `Spritesheetweapon-master/05-成品项目/色彩勇者Demo/`
- Engine: Godot 4.6
- Language: GDScript
- Main scene: `res://scenes/Main.tscn`
- Autoload: `GameManager` -> `res://scripts/GameManager.gd`

## How To Use This Context

- For implementation work, use the Godot specialists' guidance in `.claude/agents/godot-specialist.md` and `.claude/agents/godot-gdscript-specialist.md`.
- For workflow prompts, read the relevant `.claude/skills/*/SKILL.md` file and adapt it to Codex rather than assuming slash commands are available here.
- For engine-version questions, consult `docs/engine-reference/godot/VERSION.md`, `deprecated-apis.md`, `breaking-changes.md`, and the relevant module docs before suggesting APIs.
- For design work, keep the collaborative pattern from `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`: clarify intent, propose options, then implement once the direction is clear.
- Avoid editing generated Godot import metadata unless the task specifically requires it.

## Current MVP Summary

The game is a single-player match-3 RPG combat demo. It has a main menu, three-node route map, normal/elite/boss battles, a 7x7 board, swaps, matches, cascades, turn-based enemy actions, red burn, blue freeze, gold rewards, shield effects, three skills, post-battle color rewards, and a final tendency result.

Useful next directions include an 8-color system, data-driven color/effect tables, shop and relic systems, events, branching maps, enemy intents, resistances, animation states, UI scene extraction, stronger audio/VFX polish, saves, and meta-progression.
