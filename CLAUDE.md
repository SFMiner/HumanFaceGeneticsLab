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
- No automated tests are present. Validate changes by running the main scene and exercising:
  - Parent selection, recombination, and library refresh.
  - Teacher Mode toggles, constraints, and disclaimer visibility.
- If you add tests, document how to run them here and keep them isolated under a `tests/` folder.

## Commit & Pull Request Guidelines
- This workspace does not include Git history, so no existing commit convention can be inferred.
- Use short, imperative commit summaries (e.g., "Add teacher mode constraints").
- PRs should include a clear description, reproduction steps, and screenshots or short clips for UI changes.

## Configuration & Content Tips
- Level progression lives in `data/levels.json`; keep level IDs stable to avoid breaking saved data.
- Genetic logic is centralized in `scripts/autoload/HumanGeneticsState.gd`; update related UI text when changing genetics rules.

## Terminology
- Use **recombination** instead of "breeding" in UI, comments, and documentation to align with ethical guidelines.
