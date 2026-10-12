# CLAUDE.md

This file is the single copy of the project conventions; AGENTS.md only points here.

# Repository Guidelines

## Project Structure & Module Organization
- `project.godot` is the Godot 4.5+ project entry point.
- `scenes/` contains all `.tscn` scenes, with `scenes/main/GeneticsLab.tscn` as the main scene.
- `scripts/` holds GDScript logic, grouped by feature: `autoload/`, `main/`, `humans/`, and `ui/`.
- `data/` stores gameplay configuration JSON (levels, names, teacher mode defaults).
- `assets/` includes fonts, themes, and visual resources; `.godot/` is editor-generated and should not be manually edited.
- Offspring previews show an "Unsaved result" badge until explicitly saved to the library.
- `scenes/ui/ParentSlot.tscn` wraps the genotype list in a `ScrollContainer` to support more than 3 allele rows.

## Build, Test, and Development Commands
- Open the project in Godot 4.5+ and run the main scene: `scenes/main/GeneticsLab.tscn` (F5).
- CLI launch (Windows): `"C:\Users\seanm\Nextcloud2\Gamedev\GodotGames\Godot_v4.5-stable_win64.exe" --path .` to open the editor, then run the main scene.

## Coding Style & Naming Conventions
- GDScript uses tabs for indentation in this repo; keep existing alignment.
- Prefer snake_case for functions and variables, and PascalCase for scene and script filenames (e.g., `HumanFace.gd`, `TeacherModePanel.tscn`).
- Keep UI node paths consistent with scene tree names to match `@onready` bindings.
- JSON files in `data/` should remain stable in key ordering and use clear, descriptive keys.

## Testing Guidelines
- Run `GODOT=C:/Users/seanm/Nextcloud2/Gamedev/Godot_v4.5-stable_win64.exe ./tests/run_all_tests.sh` (keyboard + smoke suites; it fails on any `SCRIPT ERROR` too). New `class_name`s need an editor scan first (the script does it), or `--script` runs fail to compile.
- Tests write to the real `user://` library and tutorial state, so they remove what they add; keep it that way.
- Also exercise by hand: parent selection, recombination, library refresh, Teacher Mode toggles, constraints, and disclaimer visibility.
- Keep tests under `tests/`.

## Keyboard & web export (sims.mr-miner.com)
- Tab order and the keyboard exit live in `scripts/ui/KeyboardNav.gd`: it builds the Tab list from visible focusable controls in tree order (tutorial box first), so new controls join automatically. `GeneticsLab.close_topmost()` decides what Escape closes. `FocusRing.attach()` gives cards/TextureButtons their focus outline (theme `focus` style is yellow for the rest).
- Anything done by drag needs an A / B key route (see `HumanCard.assign_requested`, `AlleleChip.assign_requested`).
- Web export uses the 2D + GUI template (OptionButton, RichTextLabel, SpinBox); `docs/MANUAL.md` is shipped via `include_filter` because `.md` is not a resource. Loose images in the folder root (screenshots, `faces_level*.jpg`, a personal schedule) are excluded by `*.jpg`; move them out of the project when convenient.
- **No PIN or admin mode (Sean, 2026-10-12).** Web builds get teacher settings only from a class settings link
  (`TeacherModeState.apply_link_settings`, keys in `LINK_KEYS` and the README table); the Teacher Mode panel is for
  desktop debug runs. A new link key must change gameplay (several Teacher Mode setters are not wired to the UI) and
  must be added to the site's form via game-sim-server.
- Header text uses `assets/fonts/header_font_web.tres` (header font + fallback): the web text server draws a hex box for U+2006, which the plain header font lacks.

## Commit & Pull Request Guidelines
- This workspace does not include Git history, so no existing commit convention can be inferred.
- Use short, imperative commit summaries (e.g., "Add teacher mode constraints").
- PRs should include a clear description, reproduction steps, and screenshots or short clips for UI changes.

## Configuration & Content Tips
- Level progression lives in `data/levels.json`; keep level IDs stable to avoid breaking saved data.
- Genetic logic is centralized in `scripts/autoload/HumanGeneticsState.gd`; update related UI text when changing genetics rules.

## Terminology
- Use **recombination** instead of "breeding" in UI, comments, and documentation to align with ethical guidelines.
