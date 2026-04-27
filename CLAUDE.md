# blackmatter-ghostty — Claude Orientation

> **★★★ CSE / Knowable Construction.** This repo operates under **Constructive Substrate Engineering** — canonical specification at [`pleme-io/theory/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md`](https://github.com/pleme-io/theory/blob/main/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md). The Compounding Directive (operational rules: solve once, load-bearing fixes only, idiom-first, models stay current, direction beats velocity) is in the org-level pleme-io/CLAUDE.md ★★★ section. Read both before non-trivial changes.


One-sentence purpose: impure-build Ghostty terminal for macOS + home-manager
module for config and theme deployment.

## Classification

- **Archetype:** `blackmatter-component-custom-package`
- **Flake shape:** **custom** (does NOT go through mkBlackmatterFlake)
- **Reason:** `__noChroot` Darwin build with Swift toolchain composition,
  custom shim + patches. Template doesn't fit.
- **Option namespace:** `blackmatter.components.ghostty`

## Where to look

| Intent | File |
|--------|------|
| Darwin package derivation | `pkgs/ghostty/default.nix` |
| Impure build env wiring | `pkgs/ghostty/*.nix` |
| HM config module | `module/default.nix` |
| Flake surface | `flake.nix` (custom) |

## What NOT to do

- **Don't migrate to mkBlackmatterFlake** until the helper grows first-class
  support for impure Darwin builds. Right now the custom flake is correct.
- Don't touch the shim files without understanding the SwiftPM sandbox, PATH
  ordering, SSL certs, GNU sed, Metal toolchain, HOME/DEVELOPER_DIR dance.
