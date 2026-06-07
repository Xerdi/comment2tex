#!/usr/bin/env bash
## \subsection{Bash2\TeX}
## This script converts Bash scripts with embedded \LaTeX\ documentation to a \LaTeX\ file.
## Documentation lines must start with a double hash (\texttt{\#\#}).
## Code blocks are automatically wrapped in \texttt{lstlisting} environments.
##
## \subsubsection{How it works}
## The script uses \texttt{awk} to process the input file line by line.
## When it encounters a line starting with \texttt{\#\#}, it closes any open code block and outputs the line (minus the \texttt{\#\#}).
## Otherwise, it opens a code block (if not already in one) and outputs the code line.
##
set -euo pipefail

[[ $# -eq 1 ]] || {
  echo "Usage: $0 src/script.sh" >&2
  exit 1
}

in="$1"
[[ -f "$in" ]] || {
  echo "Input not found: $in" >&2
  exit 1
}

## \subsubsection{Implementation details}
## The \texttt{awk} script maintains a state variable \texttt{in\_code} and a \texttt{block\_count} to manage code blocks.
##
## \texttt{open\_code()} starts a new \texttt{lstlisting} environment.
##
## \texttt{close\_code()} ends the current \texttt{lstlisting} environment.
##
## For each line, check if it starts with \texttt{\#\#}.
## If it does not, it is code.
## Always close the code block at the end.
awk '
BEGIN {
  in_code = 0
  block_count = 0
}

function open_code() {
  if (!in_code) {
    block_count++
    if (block_count == 1) {
      print "\\begin" "{lstlisting}[language=bash,numbers=left]"
    } else {
      print "\\begin" "{lstlisting}[language=bash,firstnumber=last,numbers=left]"
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
  if ($0 ~ /^##/) {
    close_code()
    line = $0
    sub(/^##[ ]?/, "", line)
    print line
    next
  }

  open_code()
  print $0
}

END { close_code() }
' "$in"