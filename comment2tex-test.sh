#!/usr/bin/env bash
# comment2tex-test.sh -- exercise comment2tex across every TeX engine.
#
# It extracts the wrappers from the .dtx, builds small annotated fixtures, and
# drives each supported route to a PDF:
#
#   * texlua          the converter as a CLI (parity with the legacy scripts)
#   * LuaLaTeX        in-process via \directlua (no shell escape, no pre-run)
#   * pdfLaTeX        shell escape (-shell-escape -> texlua)
#   * pdfLaTeX        separate run (fragments pre-built, then plain pdflatex)
#   * plain luatex    in-process via \directlua
#   * plain pdftex    shell escape and separate run
#   * LuaLaTeX        the comment2tex.dtx documentation (the \includelua dogfood)
#
# Missing engines are skipped, not failed.  Any engine that runs and fails makes
# the whole suite exit non-zero.
#
# TEXMFHOME is redirected to an empty directory so a user's personal listings
# configuration cannot interfere with the package under test.

set -uo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/comment2tex-test.XXXXXX")"
export TEXMFHOME="$WORK/texmf-empty"
mkdir -p "$TEXMFHOME"

pass=0 fail=0 skip=0
failed_names=()

log()  { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# run NAME OUTPUT -- CMD...
# Runs CMD (stdin closed); a pass needs exit 0 and a non-empty OUTPUT file.
run() {
  local name="$1" out="$2"; shift 2
  [ "$1" = "--" ] && shift
  rm -f "$out"
  if "$@" </dev/null >"$WORK/last.log" 2>&1 && [ -s "$out" ]; then
    log "PASS  $name"
    pass=$((pass + 1))
  else
    log "FAIL  $name (exit $?)"
    sed -n '/^! /,+4p' "$WORK/last.log" | sed 's/^/        /' | head -20
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
}

skip() { log "SKIP  $name -- $1"; skip=$((skip + 1)); }

C2T="texlua $WORK/comment2tex.lua"

# --------------------------------------------------------------------------
# Fixtures and wrappers
# --------------------------------------------------------------------------
log "workspace: $WORK"
cp "$SRC/comment2tex.lua" "$SRC/comment2tex.dtx" "$SRC/comment2tex.ins" "$WORK"/ || {
  log "FATAL: cannot find comment2tex sources next to this script"; exit 2; }

cd "$WORK" || exit 2

# Extract comment2tex.sty and comment2tex.tex from the .dtx.
if have tex; then
  if tex comment2tex.ins </dev/null >"$WORK/ins.log" 2>&1 && [ -s comment2tex.sty ] && [ -s comment2tex.tex ]; then
    log "PASS  docstrip extraction (comment2tex.sty, comment2tex.tex)"
    pass=$((pass + 1))
  else
    log "FAIL  docstrip extraction"; tail -5 "$WORK/ins.log" | sed 's/^/        /'
    fail=$((fail + 1)); failed_names+=("docstrip extraction")
  fi
else
  log "FATAL: 'tex' is required to extract the wrappers"; exit 2
fi

# Doc-comment fixtures, kept plain so they typeset under article *and* plain TeX.
printf '%s\n' \
  '## Demonstration Bash source.' \
  '## Double-hash lines become prose.' \
  'echo "hello"' \
  'ls -la' \
  '## A second paragraph, then more code.' \
  'exit 0' > demo-bash.sh
printf '%s\n' \
  '--- Demonstration Lua source.' \
  '--- Triple-dash lines become prose.' \
  'local x = 1' \
  'print(x)' \
  '--- Done.' > demo-lua.lua
# YAML doc-comments are "##" -- ordinary YAML comments, so the fixture stays
# valid YAML while the double-hash lines become prose.  The "---" document-start
# marker is a code line: it exercises the path that a yaml language's literate
# rules act on.
printf '%s\n' \
  '## Demonstration YAML source.' \
  '## Double-hash lines become prose.' \
  '---' \
  'key: value' \
  'list:' \
  '  - a' \
  '  - b' \
  '## Done.' > demo-yaml.yml

# Default (verbatim) path: listings is NOT loaded.  The include macros must fall
# back to the built-in numbered verbatim -- no listings, no yaml language, no
# error.  (The suite runs under a deliberately-empty TEXMFHOME, so no personal or
# system config leaks in.)
cat > doc-latex.tex <<'EOF'
\documentclass{article}
\usepackage{comment2tex}
\begin{document}
\includebash{demo-bash.sh}
\includelua{demo-lua.lua}
\includeyaml{demo-yaml.yml}
\end{document}
EOF

# Listings path, no yaml language defined: the document loads listings and opts
# in with \ctxuselistings, so \includeyaml must install its own empty "yaml"
# language and typeset under the default style rather than faulting.
cat > doc-latex-listings.tex <<'EOF'
\documentclass{article}
\usepackage{listings}
\usepackage{comment2tex}
\begin{document}
\ctxuselistings
\includebash{demo-bash.sh}
\includelua{demo-lua.lua}
\includeyaml{demo-yaml.yml}
\end{document}
EOF

# Listings path, document-defined yaml language: a self-contained "yaml" language
# (no external package -- comment2tex has no dependency on any yaml highlighter).
# \includeyaml in listings mode must leave this definition untouched and use it.
cat > doc-latex-yaml.tex <<'EOF'
\documentclass{article}
\usepackage{listings}
\usepackage{comment2tex}
\lstdefinelanguage{yaml}{
  comment=[l]{\#},
  morestring=[b]',
  morestring=[b]",
  literate={---}{{\bfseries-{}-{}-}}3
}
\begin{document}
\ctxuselistings
\includeyaml{demo-yaml.yml}
\end{document}
EOF

# Mid-document switch: the same file rendered verbatim (default), then listings,
# then verbatim again -- exercises \ctxuselistings / \ctxuseverbatim in one run.
cat > doc-latex-switch.tex <<'EOF'
\documentclass{article}
\usepackage{listings}
\usepackage{comment2tex}
\begin{document}
Default verbatim:\par
\includebash{demo-bash.sh}
\ctxuselistings
Now listings:\par
\includebash{demo-bash.sh}
\ctxuseverbatim
Back to verbatim:\par
\includeyaml{demo-yaml.yml}
\end{document}
EOF

cat > doc-plain.tex <<'EOF'
\input comment2tex.tex
\includebash{demo-bash.sh}
\includelua{demo-lua.lua}
\includeyaml{demo-yaml.yml}
\bye
EOF

clean_frags() { rm -f demo-bash.c2t.tex demo-lua.c2t.tex demo-yaml.c2t.tex; }
gen_frags() {  # gen_frags WRAPPER
  $C2T --style bash --wrapper "$1" -o demo-bash.c2t.tex demo-bash.sh &&
  $C2T --style lua  --wrapper "$1" -o demo-lua.c2t.tex  demo-lua.lua &&
  $C2T --style yaml --wrapper "$1" -o demo-yaml.c2t.tex demo-yaml.yml
}

# --------------------------------------------------------------------------
# 1. The converter as a CLI
# --------------------------------------------------------------------------
name="texlua CLI (lstlisting + plain output)"
if have texlua; then
  if $C2T --style bash demo-bash.sh | grep -q '\\begin{lstlisting}\[language=bash' &&
     $C2T --style lua  demo-lua.lua  | grep -q '\\begin{lstlisting}\[language={\[5.3\]Lua}' &&
     $C2T --style yaml demo-yaml.yml | grep -q '\\begin{lstlisting}\[language=yaml' &&
     $C2T --style yaml --wrapper plain demo-yaml.yml | grep -q '\\ctxlisting' &&
     $C2T --style yaml --wrapper plain demo-yaml.yml | grep -q '\\endctxlisting'; then
    log "PASS  $name"; pass=$((pass + 1))
  else
    log "FAIL  $name"; fail=$((fail + 1)); failed_names+=("$name")
  fi
  # Parity with the original shell scripts, when they are present.
  if [ -x "$SRC/bash2tex.sh" ]; then
    name="texlua CLI parity vs bash2tex.sh"
    if diff -q <("$SRC/bash2tex.sh" "$SRC/bash2tex.sh") \
              <($C2T --style bash "$SRC/bash2tex.sh") >/dev/null; then
      log "PASS  $name"; pass=$((pass + 1))
    else
      log "FAIL  $name"; fail=$((fail + 1)); failed_names+=("$name")
    fi
  fi
else
  skip "texlua not installed"
fi

# --------------------------------------------------------------------------
# 2. LaTeX wrapper
# --------------------------------------------------------------------------
name="LuaLaTeX in-process (verbatim default, no listings)"
if have lualatex; then
  clean_frags
  run "$name" doc-latex.pdf -- lualatex -interaction=nonstopmode -halt-on-error doc-latex.tex
else skip "lualatex not installed"; fi

name="LuaLaTeX in-process (listings mode, yaml fallback language)"
if have lualatex; then
  clean_frags
  run "$name" doc-latex-listings.pdf -- lualatex -interaction=nonstopmode -halt-on-error doc-latex-listings.tex
else skip "lualatex not installed"; fi

name="LuaLaTeX in-process (listings mode, document-defined yaml language)"
if have lualatex; then
  rm -f demo-yaml.c2t.tex
  run "$name" doc-latex-yaml.pdf -- lualatex -interaction=nonstopmode -halt-on-error doc-latex-yaml.tex
else skip "lualatex not installed"; fi

name="LuaLaTeX in-process (mid-document verbatim<->listings switch)"
if have lualatex; then
  clean_frags
  run "$name" doc-latex-switch.pdf -- lualatex -interaction=nonstopmode -halt-on-error doc-latex-switch.tex
else skip "lualatex not installed"; fi

name="pdfLaTeX -shell-escape (verbatim default)"
if have pdflatex; then
  clean_frags
  run "$name" doc-latex.pdf -- pdflatex -shell-escape -interaction=nonstopmode -halt-on-error doc-latex.tex
else skip "pdflatex not installed"; fi

name="pdfLaTeX separate-run, verbatim (no shell escape)"
if have pdflatex && have texlua; then
  clean_frags
  gen_frags plain
  run "$name" doc-latex.pdf -- pdflatex -interaction=nonstopmode -halt-on-error doc-latex.tex
else skip "pdflatex or texlua not installed"; fi

name="pdfLaTeX separate-run, listings (no shell escape)"
if have pdflatex && have texlua; then
  clean_frags
  gen_frags lstlisting
  run "$name" doc-latex-listings.pdf -- pdflatex -interaction=nonstopmode -halt-on-error doc-latex-listings.tex
else skip "pdflatex or texlua not installed"; fi

# --------------------------------------------------------------------------
# 3. plain TeX wrapper
# --------------------------------------------------------------------------
name="plain luatex in-process"
if have luatex; then
  clean_frags
  run "$name" doc-plain.pdf -- luatex -interaction=nonstopmode -halt-on-error doc-plain.tex
else skip "luatex not installed"; fi

name="plain pdftex -shell-escape"
if have pdftex; then
  clean_frags
  run "$name" doc-plain.pdf -- pdftex -shell-escape -interaction=nonstopmode -halt-on-error doc-plain.tex
else skip "pdftex not installed"; fi

name="plain pdftex separate-run (no shell escape)"
if have pdftex && have texlua; then
  clean_frags
  gen_frags plain
  run "$name" doc-plain.pdf -- pdftex -interaction=nonstopmode -halt-on-error doc-plain.tex
else skip "pdftex or texlua not installed"; fi

# --------------------------------------------------------------------------
# 4. The documentation itself (dogfood: \includelua{comment2tex.lua})
# --------------------------------------------------------------------------
name="LuaLaTeX builds comment2tex.dtx"
if have lualatex; then
  rm -f comment2tex.c2t.tex
  run "$name" comment2tex.pdf -- lualatex -interaction=nonstopmode comment2tex.dtx
else skip "lualatex not installed"; fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
log ""
log "------------------------------------------------------------"
log "PASS: $pass   FAIL: $fail   SKIP: $skip"
if [ "$fail" -gt 0 ]; then
  log "Failures: ${failed_names[*]}"
  log "Workspace kept for inspection: $WORK"
  exit 1
fi
rm -rf "$WORK"
log "All engine tests passed."
