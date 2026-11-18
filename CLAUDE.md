# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of standalone [Quarto](https://quarto.org) documents: teaching slide decks and assignment handouts, plus company (GETGAIN) presentations and proposals. It is published as static HTML via GitHub Pages (`.nojekyll`, remote `Gustavo-Reis/quarto-presentations`). There is no code to build or test. The "source" is `.qmd` (sometimes `.md`) and the "build output" is the rendered `.html` committed next to it.

## Rendering

There is **no `_quarto.yml` project file**. Each document is self-contained, and its YAML front matter defines its format, theme and CSS. Render one file at a time:

```sh
quarto render path/to/file.qmd          # writes path/to/file.html (+ file_files/ unless embed-resources)
quarto preview path/to/file.qmd         # live-reload preview
quarto render path/to/file.qmd --to pdf # only for docs that declare a pdf format
```

Quarto is installed at `C:\Users\gusta\AppData\Local\Programs\Quarto\bin\quarto`.

- Commit the regenerated `.html` together with the `.qmd` change. Pages serves the HTML directly, so a `.qmd` edit without a re-render doesn't go live.
- Docs without `embed-resources: true` also produce a `<name>_files/libs/...` folder (reveal.js, plugins, etc.). Those folders are generated and tracked, so don't hand-edit them.
- **`ggs/` HTML is password-protected with StatiCrypt.** After rendering any `ggs/` document, run `STATICRYPT_PASSWORD=... ./encrypt-ggs.sh <file.html>` before committing (no args = all of `ggs/`). Never commit a freshly rendered, unencrypted `ggs/` HTML. Keep `.staticrypt.json` (the salt) committed. Never write the password into any file.
- `_quarto_internal_scss_error.scss` at the root is a Quarto debugging artifact, not a source file.

## Layout and conventions

The top-level folders are subjects or clients. Each one holds its own `.qmd` files with local images and styles:

- `AIAG/`: AI Applied to Games (lectures `NN_*`, practicals `PNN_*`, class project, research work). English.
- `atgp/`: C++ and game-engine programming (modern C++, CMake/vcpkg, SDL3, Box2D, threads, projects). English.
- `cg/`: Computer Graphics with OpenGL (follows LearnOpenGL). English.
- `ge2/`, `gnp/`: Unreal Engine game/network programming assignments (multiplayer, Blueprints). English.
- `unreal_cpp_lecture/`, `2dactorplus/`: one-off lectures and architecture docs.
- `ggs/`: GETGAIN Solutions material: client proposals, AI portfolio, trainings, viability analyses (e.g. `ggs/Visabeira/`). Mostly **Portuguese (pt-PT)**. Several of these are marked internal or confidential in their footer.
- `test/`: scratch documents.

Recurring front-matter patterns (copy from a sibling file in the same folder instead of inventing new ones):

- **Lecture decks:** `format: revealjs`, `theme: dracula`, `width: 1920`, `height: 1080`, `chalkboard: true`, `highlight-style: github-dark`, `slide-number`, `footer`, `css: custom.css`. Many `css:` references point to files that don't exist; Quarto ignores them silently.
- **GETGAIN decks:** `theme: [default, custom.scss]` using the folder's `custom.scss` and/or `getgain_style.css`, with `logo: ../logo-getgain.png` (the logo lives at `ggs/logo-getgain.png`). Some newer ones (Visabeira/MOB) inline their CSS through `include-in-header` and use `embed-resources: true`, so they ship as a single HTML file.
- **Assignment handouts and worksheets:** `format: html` with `toc: true` and `number-sections: true`.
- Mermaid diagrams (` ```{mermaid} `) are used in some decks.

Files with an `_old` suffix, and older versions such as `P03_Advanced_AI_old/`, are kept for reference. Edit the current version unless told otherwise.
