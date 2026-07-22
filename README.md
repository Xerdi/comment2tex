# comment2tex

Include annotated source files as LaTeX listings — a Lua converter plus LaTeX and
plain-TeX wrappers (`\includebash`, `\includelua`, `\includeyaml`) that typeset a
Bash, Lua or YAML source whose doc-comments become prose and whose code becomes a
listing.

> **This README is for package maintainers, developers, and CTAN reviewers**, not
> for LaTeX end users. End-user documentation is the typeset manual
> `comment2tex.pdf`, built from `comment2tex.dtx`.

## Overview

A line that begins with a style's doc-comment prefix (`##` for Bash and YAML,
`---` for Lua) is documentation; every other line is code. The converter,
`comment2tex.lua`, runs both as a `texlua` command-line program and — under
LuaLaTeX — in process via `\directlua`. Under LaTeX the include macros default to
a built-in numbered verbatim (no dependency, no setup); `\ctxuselistings` opts
subsequent includes into `listings` output and `\ctxuseverbatim` switches back.

## Repository layout

| File | Role |
|---|---|
| `comment2tex.dtx` | Documented source: prose plus the `.sty`/`.tex` wrapper code. |
| `comment2tex.ins` | docstrip driver; extracts the wrappers. |
| `comment2tex.lua` | The converter (hand-written; its `---` lines are Lua comments). |
| `comment2tex-test.sh` | Cross-engine test suite (development only). |
| `Makefile` | Build, test and packaging targets (`make help`). |
| `comment2tex.sty`, `comment2tex.tex` | **Generated** from the `.ins` (git-ignored). |
| `comment2tex.pdf` | **Generated** manual from the `.dtx`. |

## Building and testing

```sh
make wrappers   # docstrip: comment2tex.{sty,tex} from the .dtx + .ins
make doc        # typeset comment2tex.pdf (LuaLaTeX; make doc WATCH=1 for --pvc)
make test       # run comment2tex-test.sh across every installed TeX engine
make package    # build the CTAN upload zip (see below)
make clean
```

Building the manual needs LuaLaTeX, because the `\includelua`/`\includebash`
demonstrations convert in process. The suite exercises texlua, LuaLaTeX, pdfLaTeX
(shell-escape and separate run) and plain luatex/pdftex; missing engines are
skipped, not failed.

## CTAN submission

`make package` produces `comment2tex.zip` with everything under a single
`comment2tex/` directory. Following CTAN's upload guide
(<https://ctan.org/help/upload-pkg>), the bundle contains **only sources and the
built documentation** — no file that can be regenerated from another in the
package:

**Included**

- `comment2tex.dtx`, `comment2tex.ins` — documented source and docstrip driver.
- `comment2tex.lua` — the converter, shipped as its **annotated source**. Its
  `---` doc-comment lines are ordinary Lua comments, so the file runs unmodified;
  a tangled/stripped copy is deliberately **not** shipped, because a stripped file
  would be a derived artefact, which the upload guide says must not be included.
- `README.md`, `comment2tex.pdf`.

**Excluded** (derived or development artefacts)

- `comment2tex.sty`, `comment2tex.tex` — generated from `comment2tex.ins`; CTAN
  and TeX Live regenerate them, so shipping them would ship derived files.
- `Makefile`, `comment2tex-test.sh` — the build system and test suite. The
  manual's *The build* and *Testing* sections `\includemake`/`\includebash` them
  only when present (guarded by `\IfFileExists`), so the bundled sources still
  build the PDF without them.
- Intermediate TeX output (`*.aux`, `*.log`, `*.c2t.tex`, …) and version-control
  files.

Review the bundle by hand first. To upload, open the package's CTAN page and use
the upload button — it pre-fills the suggested directory — attaching
`comment2tex.zip`.

## Versioning

The version and date live in `comment2tex.dtx` (`\ProvidesPackage`). Bump them,
commit, then tag the release so the two agree.

## License

Copyright © 2026 Erik Nijenhuis. This work may be distributed and/or modified
under the conditions of the LaTeX Project Public License (LPPL), version 1.3c or,
at your option, any later version.
