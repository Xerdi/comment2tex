#!/usr/bin/env bash
## \subsection{What the suite covers}
## \texttt{comment2tex-test.sh} drives the converter and both wrappers through every
## supported \TeX\ route, so a change cannot quietly break one path while another
## keeps working.  Each route is exercised end to end --- annotated source to
## \texttt{.c2t.tex} fragment to \emph{PDF}:
## \begin{itemize}
## \item \texttt{texlua} --- the converter as a command-line program.
## \item Lua\LaTeX\ --- in process through \cs{directlua} (no shell escape, no pre-run).
## \item pdf\LaTeX\ --- shell escape, and a separate run over pre-built fragments.
## \item plain \texttt{luatex} and \texttt{pdftex} --- the plain \TeX\ wrapper.
## \item Lua\LaTeX\ on \texttt{comment2tex.dtx} itself --- the self-documenting
##       \cs{includelua} build of this manual.
## \end{itemize}
## A missing engine is skipped, never failed; any engine that runs and fails makes
## the whole suite exit non-zero.  \texttt{TEXMFHOME} is redirected to an empty tree
## so a personal \textsf{listings} configuration cannot leak into the run.
set -uo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/comment2tex-test.XXXXXX")"
export TEXMFHOME="$WORK/texmf-empty"
mkdir -p "$TEXMFHOME"

pass=0 fail=0 skip=0
failed_names=()

## \subsection{Harness helpers}
## \texttt{log} prints a line; \texttt{have} reports whether an engine is on the
## \texttt{PATH}.
log()  { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

## \texttt{run}~\meta{name}~\meta{output}~\texttt{-{}-}~\meta{cmd}\dots{} runs
## \meta{cmd} with stdin closed and passes only when it exits zero \emph{and} leaves
## a non-empty \meta{output} \emph{PDF}; on failure it prints the first \TeX\ error.
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

## Common engine flags, factored out so the driver runs stay within one line:
## \texttt{\$NS} is nonstop interaction, \texttt{\$OPTS} adds halt-on-error (the
## self-documenting build omits the halt so a warning cannot stop it).
NS="-interaction=nonstopmode"
OPTS="$NS -halt-on-error"

## \subsection{Fixtures}
## Everything runs in a scratch copy of the sources, and the wrappers are extracted
## from the \texttt{.dtx} first, so the suite tests exactly what \texttt{docstrip}
## ships rather than a stale build.  A wrapper that will not build is a hard error,
## not a skip.
log "workspace: $WORK"
cp "$SRC/comment2tex.lua" "$SRC/comment2tex.dtx" "$SRC/comment2tex.ins" \
   "$SRC/Makefile" "$SRC/comment2tex-test.sh" "$WORK"/ || {
  log "FATAL: cannot find comment2tex sources next to this script"; exit 2; }

cd "$WORK" || exit 2

if have tex; then
  if tex comment2tex.ins </dev/null >"$WORK/ins.log" 2>&1 \
       && [ -s comment2tex.sty ] && [ -s comment2tex.tex ]; then
    log "PASS  docstrip extraction (comment2tex.sty, comment2tex.tex)"
    pass=$((pass + 1))
  else
    log "FAIL  docstrip extraction"
    tail -5 "$WORK/ins.log" | sed 's/^/        /'
    fail=$((fail + 1)); failed_names+=("docstrip extraction")
  fi
else
  log "FATAL: 'tex' is required to extract the wrappers"; exit 2
fi

## Three tiny annotated fixtures, one per style, kept trivial so they typeset under
## both \texttt{article} and plain \TeX.  Bash and YAML use the \texttt{\#\#}
## doc-prefix, Lua uses \texttt{-{}-{}-}.  The YAML fixture opens with a
## \texttt{-{}-{}-} document-start marker --- a code line that exercises whatever
## \texttt{literate} rule a \texttt{yaml} language applies to it.
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
printf '%s\n' \
  '## Demonstration YAML source.' \
  '## Double-hash lines become prose.' \
  '---' \
  'key: value' \
  'list:' \
  '  - a' \
  '  - b' \
  '## Done.' > demo-yaml.yml

## \subsection{Driver documents}
## One \LaTeX\ (and one plain \TeX) driver per behaviour under test.  The default
## driver loads no \textsf{listings}, so the include macros must fall back to the
## built-in numbered verbatim without error.
cat > doc-latex.tex <<'EOF'
\documentclass{article}
\usepackage{comment2tex}
\begin{document}
\includebash{demo-bash.sh}
\includelua{demo-lua.lua}
\includeyaml{demo-yaml.yml}
\end{document}
EOF

## In \textsf{listings} mode with no \texttt{yaml} language defined, \cs{includeyaml}
## must install its own empty one and typeset under the default style.
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

## In \textsf{listings} mode \emph{with} a self-contained \texttt{yaml} language (no
## external package --- comment2tex depends on no yaml highlighter), \cs{includeyaml}
## must leave that definition untouched and use it.
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

## The switch driver renders one file verbatim, then \textsf{listings}, then verbatim
## again, exercising \cs{ctxuselistings} and \cs{ctxuseverbatim} in a single run.
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

## The plain \TeX\ driver \cs{input}s \texttt{comment2tex.tex} directly.
cat > doc-plain.tex <<'EOF'
\input comment2tex.tex
\includebash{demo-bash.sh}
\includelua{demo-lua.lua}
\includeyaml{demo-yaml.yml}
\bye
EOF

## \texttt{gen\_frags}~\meta{wrapper} pre-builds the three fragments for the
## separate-run routes; \texttt{clean\_frags} deletes them so an in-process route
## cannot silently reuse a stale fragment.
clean_frags() { rm -f demo-bash.c2t.tex demo-lua.c2t.tex demo-yaml.c2t.tex; }
gen_frags() {  # gen_frags WRAPPER
  $C2T --style bash --wrapper "$1" -o demo-bash.c2t.tex demo-bash.sh &&
  $C2T --style lua  --wrapper "$1" -o demo-lua.c2t.tex  demo-lua.lua &&
  $C2T --style yaml --wrapper "$1" -o demo-yaml.c2t.tex demo-yaml.yml
}

## \subsection{The converter as a command-line program}
## The CLI must emit an \texttt{lstlisting} block per style, the plain wrapper's
## \cs{ctxlisting} and \cs{endctxlisting} brackets, and --- with \texttt{-{}-tangle} ---
## byte-for-byte what the \texttt{sed} it replaces would, for every style.
name="texlua CLI (lstlisting + plain output)"
if have texlua; then
  if $C2T --style bash demo-bash.sh \
       | grep -q '\\begin{lstlisting}\[language=bash' &&
     $C2T --style lua demo-lua.lua \
       | grep -q '\\begin{lstlisting}\[language={\[5.3\]Lua}' &&
     $C2T --style yaml demo-yaml.yml \
       | grep -q '\\begin{lstlisting}\[language=yaml' &&
     $C2T --style make Makefile \
       | grep -q '\\begin{lstlisting}\[language=make' &&
     $C2T --style yaml --wrapper plain demo-yaml.yml \
       | grep -q '\\ctxlisting' &&
     $C2T --style yaml --wrapper plain demo-yaml.yml \
       | grep -q '\\endctxlisting'; then
    log "PASS  $name"; pass=$((pass + 1))
  else
    log "FAIL  $name"; fail=$((fail + 1)); failed_names+=("$name")
  fi

  # --tangle strips doc-comments, style-aware: same output as the old sed.
  name="texlua CLI --tangle (== sed, per style)"
  if diff -q <(sed '/^##/d' demo-bash.sh) \
            <($C2T --style bash --tangle demo-bash.sh) >/dev/null &&
     diff -q <(sed '/^---/d' demo-lua.lua) \
            <($C2T --style lua --tangle demo-lua.lua) >/dev/null &&
     diff -q <(sed '/^##/d' demo-yaml.yml) \
            <($C2T --style yaml --tangle demo-yaml.yml) >/dev/null; then
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

## \subsection{The \LaTeX\ wrapper}
## The same three fixtures are typeset through every \LaTeX\ route --- verbatim
## default, both \textsf{listings} paths, the mid-document switch, and pdf\LaTeX\ by
## shell escape and by separate run --- each passing only on a non-empty \emph{PDF}.
name="LuaLaTeX in-process (verbatim default, no listings)"
if have lualatex; then
  clean_frags
  run "$name" doc-latex.pdf -- lualatex $OPTS doc-latex.tex
else skip "lualatex not installed"; fi

name="LuaLaTeX in-process (listings mode, yaml fallback language)"
if have lualatex; then
  clean_frags
  run "$name" doc-latex-listings.pdf -- lualatex $OPTS doc-latex-listings.tex
else skip "lualatex not installed"; fi

name="LuaLaTeX in-process (listings mode, document-defined yaml language)"
if have lualatex; then
  rm -f demo-yaml.c2t.tex
  run "$name" doc-latex-yaml.pdf -- lualatex $OPTS doc-latex-yaml.tex
else skip "lualatex not installed"; fi

name="LuaLaTeX in-process (mid-document verbatim<->listings switch)"
if have lualatex; then
  clean_frags
  run "$name" doc-latex-switch.pdf -- lualatex $OPTS doc-latex-switch.tex
else skip "lualatex not installed"; fi

name="pdfLaTeX -shell-escape (verbatim default)"
if have pdflatex; then
  clean_frags
  run "$name" doc-latex.pdf -- pdflatex -shell-escape $OPTS doc-latex.tex
else skip "pdflatex not installed"; fi

name="pdfLaTeX separate-run, verbatim (no shell escape)"
if have pdflatex && have texlua; then
  clean_frags
  gen_frags plain
  run "$name" doc-latex.pdf -- pdflatex $OPTS doc-latex.tex
else skip "pdflatex or texlua not installed"; fi

name="pdfLaTeX separate-run, listings (no shell escape)"
if have pdflatex && have texlua; then
  clean_frags
  gen_frags lstlisting
  run "$name" doc-latex-listings.pdf -- pdflatex $OPTS doc-latex-listings.tex
else skip "pdflatex or texlua not installed"; fi

## \subsection{The plain \TeX\ wrapper}
## The plain wrapper has no \textsf{listings}, so it is driven under \texttt{luatex}
## (in process) and \texttt{pdftex} (shell escape and separate run).
name="plain luatex in-process"
if have luatex; then
  clean_frags
  run "$name" doc-plain.pdf -- luatex $OPTS doc-plain.tex
else skip "luatex not installed"; fi

name="plain pdftex -shell-escape"
if have pdftex; then
  clean_frags
  run "$name" doc-plain.pdf -- pdftex -shell-escape $OPTS doc-plain.tex
else skip "pdftex not installed"; fi

name="plain pdftex separate-run (no shell escape)"
if have pdftex && have texlua; then
  clean_frags
  gen_frags plain
  run "$name" doc-plain.pdf -- pdftex $OPTS doc-plain.tex
else skip "pdftex or texlua not installed"; fi

## \subsection{The documentation itself}
## Finally the suite builds \texttt{comment2tex.dtx} --- the very manual you are
## reading --- which \cs{includelua}s the converter and \cs{includebash}s this
## script, so a break in either self-documenting include fails the build.
name="LuaLaTeX builds comment2tex.dtx"
if have lualatex; then
  rm -f comment2tex.c2t.tex
  run "$name" comment2tex.pdf -- lualatex $NS comment2tex.dtx
else skip "lualatex not installed"; fi

## \subsection{Summary}
## The tally is printed; a non-zero \texttt{fail} keeps the workspace for inspection
## and exits non-zero, otherwise the scratch tree is removed.
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
