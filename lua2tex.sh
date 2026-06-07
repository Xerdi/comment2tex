#!/usr/bin/env bash
## \subsection{Lua2\TeX}
## This script converts Lua scripts with embedded \LaTeX\ documentation to a \LaTeX\ file.
## It mirrors \texttt{bash2tex} but for Lua sources: documentation lines start with a triple
## dash (\texttt{-{}-{}-}), which is the conventional Lua doc-comment prefix used by tools
## like LDoc.  Everything else is wrapped in a \texttt{lstlisting} environment with
## \texttt{language={[5.3]Lua}}.
##
## \subsubsection{How it works}
## The script uses \texttt{awk} to process the input file line by line.
## When it encounters a line starting with \texttt{-{}-{}-}, it closes any open code block
## and outputs the line (minus the prefix).
## Otherwise, it opens a code block (if not already in one) and outputs the code line.
##
set -euo pipefail

[[ $# -eq 1 ]] || {
  echo "Usage: $0 src/script.lua" >&2
  exit 1
}

in="$1"
[[ -f "$in" ]] || {
  echo "Input not found: $in" >&2
  exit 1
}

## \subsubsection{Implementation details}
## The \texttt{awk} script maintains a state variable \texttt{in\_code} and a
## \texttt{block\_count} to manage code blocks across multiple doc/code transitions.
##
## \texttt{open\_code()} starts a new \texttt{lstlisting} environment.  Subsequent code
## blocks reuse the previous block's line numbering via \texttt{firstnumber=last} so the
## listing reads as one continuous source.
##
## \texttt{close\_code()} ends the current \texttt{lstlisting} environment.
##
## For each line, check if it starts with \texttt{-{}-{}-}.  Triple-dash lines are doc;
## everything else (including ordinary \texttt{-{}-} comments) is code.  A trailing
## \texttt{close\_code()} in the END block guarantees the listing is closed even when the
## file ends inside a code block.
awk '
BEGIN {
  in_code = 0
  block_count = 0
}

function open_code() {
  if (!in_code) {
    block_count++
    if (block_count == 1) {
      print "\\begin" "{lstlisting}[language={[5.3]Lua},numbers=left]"
    } else {
      print "\\begin" "{lstlisting}[language={[5.3]Lua},firstnumber=last,numbers=left]"
    }
    in_code = 1
  }
}

function close_code() {
  if (in_code) {
    print "\\end" "{lstlisting}"
    in_code = 0
  }
}

{
  if ($0 ~ /^---/) {
    close_code()
    line = $0
    sub(/^---[ ]?/, "", line)
    print line
    next
  }

  open_code()
  print $0
}

END { close_code() }
' "$in"