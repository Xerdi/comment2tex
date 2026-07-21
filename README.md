# comment2tex

Include annotated source files as LaTeX listings.

`comment2tex` typesets a source file that carries its documentation in special
comments: the comments become ordinary LaTeX, the rest becomes a listing. A line
beginning with a chosen *doc-comment* prefix is prose (`##` for Bash, `---` for
Lua, `##` for YAML); everything else is code. Because `##` is itself a YAML
comment, an annotated YAML file stays valid YAML, so it can be typeset as-is
without keeping a stripped copy.

The bundle ships a Lua converter (`comment2tex.lua`) and two TeX wrappers — one
for LaTeX/LuaLaTeX and one for plain TeX — both providing `\includebash`,
`\includelua` and `\includeyaml`. Under LuaLaTeX the conversion runs in process;
under pdfLaTeX it uses `--shell-escape` or a separate pre-build run.

`listings` provides the `bash` and `Lua` languages itself, but ships no `yaml`
language. `\includeyaml` handles this gracefully: if the document has not
defined a `yaml` language, it installs an empty one so the source typesets under
the default listing style (no YAML-specific highlighting) instead of faulting. A
document that defines its own `yaml` language keeps it.

## Installation

```
tex comment2tex.ins
```

This extracts `comment2tex.sty` and `comment2tex.tex`. Move those, together with
`comment2tex.lua`, into a directory searched by TeX.

## Documentation

```
lualatex comment2tex.dtx
```

LuaLaTeX is required so the `\includelua` demonstration converts in process.

## License

Copyright (C) 2026 Erik Nijenhuis.

This work may be distributed and/or modified under the conditions of the LaTeX
Project Public License, either version 1.3c of this license or (at your option)
any later version.