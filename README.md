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

## Technical Requirements

- Godot 4.5+
- Desktop (1280×720 base resolution)
- Web export compatible

## Terminology

This project uses **recombination** as the preferred term in UI and docs (replacing "breeding") in line with ethical guidelines.
## License

Educational use permitted. See full GDD for ethical guidelines.

## Credits

Design based on real human genetics research. See GDD Section 2 for gene references.


