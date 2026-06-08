# comment2tex

Include annotated source files as LaTeX listings.

`comment2tex` typesets a source file that carries its documentation in special
comments: the comments become ordinary LaTeX, the rest becomes a listing. A line
beginning with a chosen *doc-comment* prefix is prose (`##` for Bash, `---` for
Lua); everything else is code.

The bundle ships a Lua converter (`comment2tex.lua`) and two TeX wrappers — one
for LaTeX/LuaLaTeX and one for plain TeX — both providing `\includebash` and
`\includelua`. Under LuaLaTeX the conversion runs in process; under pdfLaTeX it
uses `--shell-escape` or a separate pre-build run.

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