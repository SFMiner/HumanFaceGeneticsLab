# Human Face Genetics Simulator

An educational genetics simulator for Godot 4.5 that teaches polygenic inheritance, epistasis, and complex trait expression through human facial features.

## Educational Goals

- Demonstrate epistasis (gene masking, e.g., albinism overriding all pigmentation)
- Show polygenic traits (multiple genes contributing to one phenotype)
- Illustrate dominance hierarchies and incomplete dominance
- Teach Punnett square mechanics with 2-4 gene crosses
- Connect genotype to phenotype through realistic human genetics

## Features

### Genetics System
- **8 Genes**: TYR, OCA2, HERC2, TYRP1, SLC24A5, SLC45A2, MC1R, TCHH
- **4 Traits**: Eye color (9 phenotypes), Skin tone (8 phenotypes), Hair color (8 phenotypes), Hair texture (3 phenotypes)
- **5 Progressive Levels**: Start with eye color basics, end with full human variation

### Teacher Mode
- Gene visibility constraints
- Recombination restrictions (max genes per cross, parent locking)
- Deterministic randomness for reproducible demonstrations
- Probability preview mode (ratios without offspring)
- Ethical safeguards (neutral language, modeling disclaimers)

### User Interface
- Drag-and-drop parent selection
- In-place genotype editing
- Dynamic Punnett square visualization
- Persistent human library with favorites and search

## Feature checklist

- [x] 8 genes, 4 traits, 5 progressive levels
- [x] Library of humans, parent slots, allele chips, Punnett square, recombination, save to library
- [x] Class settings link (web): the teacher's link sets the level and Teacher Mode constraints for that visit; no PIN or Admin button (see "Class settings link" below)
- [x] Teacher Mode panel for desktop and editor runs only (hidden in web builds and whenever a link is used)
- [ ] Site form under "For teachers" that builds the link (game-sim-server)
- [ ] Later: settings saved with the teacher's account for a class (site slice 5 accounts)
- [x] In-game Manual (`docs/MANUAL.md`, shipped in the web export)
- [x] Keyboard: Tab / Shift+Tab through every control, yellow focus outline, A / B on a library card or Allele Bank chip fill Parent A / B (the keyboard route for the drag), Enter on a card enlarges the face
- [x] Keyboard exit for the sims site: Escape closes the innermost open thing (popup, Teacher Mode panel, naming box, tutorial) then leaves; Tab past the last control and Shift+Tab before the first leave (`sims:leave-game`)
- [x] No sound, no fast flashing (the tutorial box fades about once a second)
- [x] Scales to small frames (`canvas_items` stretch, `expand` aspect); the Recombination Area scrolls when the frame is short
- [x] Web export with the 2D + GUI template (`export_presets.cfg`, preset "Web", exports to `../exports/human-face-genetics/`)
- [x] Headless tests: `GODOT=<godot 4.5 binary> ./tests/run_all_tests.sh` (keyboard, link settings, smoke)
- [ ] Settings button (does nothing yet; prints a message)
- [ ] Punnett cell colour is supplementary only (tooltip names the phenotype); no keyboard route to click a cell

## Getting Started

1. Open the project in Godot 4.5+
2. Run the main scene: `scenes/main/GeneticsLab.tscn`
3. Drag humans from the library to parent slots
4. Click "Recombine" to create offspring
5. Save offspring to the library

## Project Structure

```
├── data/
│   ├── levels.json          # Level configuration
│   ├── names.json           # Random name generation
│   └── teacher_mode_defaults.json
├── scenes/
│   ├── main/
│   │   └── GeneticsLab.tscn  # Main scene
│   ├── humans/
│   │   ├── HumanFace.tscn    # Face renderer
│   │   └── HumanCard.tscn    # Library card
│   └── ui/
│       ├── LibraryPanel.tscn
│       ├── RecombinationArea.tscn
│       ├── ParentSlot.tscn    # Genotype list uses a ScrollContainer for long allele lists
│       ├── PunnettGrid.tscn
│       ├── OffspringPreview.tscn
│       ├── AllelePalette.tscn
│       ├── AlleleChip.tscn
│       └── TeacherModePanel.tscn
└── scripts/
    ├── autoload/
    │   ├── HumanGeneticsState.gd  # Core genetics engine
    │   └── TeacherModeState.gd    # Teacher Mode controller
    ├── main/
    │   └── GeneticsLab.gd
    ├── humans/
    │   ├── HumanFace.gd
    │   └── HumanCard.gd
    └── ui/
        └── ... (UI scripts)
```

## Customization

### Adding Levels
Edit `data/levels.json` to create custom level progressions.

### Modifying Genetics
Edit `HumanGeneticsState.gd` to adjust:
- Gene library (`GENE_LIBRARY`)
- Convenience genotypes (`CONVENIENCE_GENOTYPES`)
- Phenotype calculations (`calculate_*` functions)
- Color palettes (`get_*_color` functions)

### Teacher Mode Defaults
Edit `data/teacher_mode_defaults.json` to set default constraints.

### Class settings link
In a web build `TeacherModeState` reads the query string of the game's address, or of the play page around it
(`/play/human-face-genetics?level=2&punnett=ratios`), applies the keys below for that visit only (never saved), and
turns Teacher Mode on with a banner listing them. Unknown keys and bad values are ignored. The list is `LINK_KEYS` in
`scripts/autoload/TeacherModeState.gd`; keep it, this table and the site's form in step.

| Key | Values | Effect |
|---|---|---|
| `level` | 1-5 | Start on this level |
| `locklevel` | 1 | Students can't change the level |
| `punnett` | full, ratios, single, hidden | Punnett square display |
| `genotypes` | show, hide | `hide` removes genotypes from the parent slots and Punnett cells (the Allele Bank still names alleles) |
| `results` | offspring, probabilities | `probabilities` shows the odds and makes no offspring |
| `seed` | 1-999999999 | Same sequence of results for every student |
| `lockparents` | 1 | Parents can't be swapped after recombining |
| `nonew` | 1 | No new random humans |
| `maxgenes` | 1-4 | Most genes in one Punnett square |
| `lowspec` | 1 | Simpler drawing for slow computers |

## Technical Requirements

- Godot 4.5+
- Desktop (1280×720 base resolution, scales down to a 640×360 frame)
- Web export compatible

## Terminology

This project uses **recombination** as the preferred term in UI and docs (replacing "breeding") in line with ethical guidelines.
## License

Educational use permitted. See full GDD for ethical guidelines.

## Credits

Design based on real human genetics research. See GDD Section 2 for gene references.


