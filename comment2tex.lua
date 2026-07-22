#!/usr/bin/env texlua
--- \subsection{The converter}
--- This file is the engine behind \cs{includebash} and \cs{includelua}.  It plays two
--- roles from one source: a command-line program run under \texttt{texlua}, and a Lua
--- library loaded \emph{in process} by the \TeX\ wrappers under Lua\TeX.
---
--- Run as a program it reads a source file and emits \LaTeX\ on stdout (or to
--- \texttt{-o}).  Loaded as a
--- library --- \texttt{require"comment2tex"} or \texttt{loadfile(...)("comment2tex")} ---
--- it returns a module table whose \texttt{write} entry converts a file directly, so
--- Lua\LaTeX\ needs neither shell escape nor a separate run.
---
--- The two modes are told apart by the first vararg of the chunk: \texttt{require} (and
--- our explicit loader) pass the module name \texttt{"comment2tex"}, whereas
--- \texttt{texlua} passes the command-line arguments.  Per the Lua\TeX\ manual,
--- \texttt{texlua} is a stand-alone Lua~5.3 interpreter that fills the global
--- \texttt{arg} table just like stock \texttt{lua}.
local LIBRARY_MODE = (... == "comment2tex")

local M = {}

--- \subsubsection{Styles and wrappers}
--- A \emph{style} pairs a doc-comment prefix with a listing language; a \emph{wrapper}
--- is the pair of \texttt{begin}/\texttt{end} lines emitted around a code block.  Both
--- are presets so that a single \texttt{--style}/\texttt{--wrapper} selects sensible
--- defaults, while \texttt{--comment}, \texttt{--language}, \texttt{--begin} and
--- \texttt{--end} still override any individual field.
M.styles = {
  bash = { comment = "##",  language = "bash" },
  lua  = { comment = "---", language = "{[5.3]Lua}" },
  yaml = { comment = "##",  language = "yaml" },
}

--- The \texttt{lstlisting} wrapper targets \LaTeX\ (the \texttt{listings} package); the
--- \texttt{plain} wrapper targets plain \TeX, where \cs{ctxlisting} reads its body
--- verbatim up to a line equal to \cs{endctxlisting}.  Templates substitute
--- \texttt{@LANG@} with the language and \texttt{@CONT@} with \texttt{firstnumber=last,}
--- on every block after the first (empty on the first) so numbering stays continuous.
M.wrappers = {
  lstlisting = {
    begin  = "\\begin{lstlisting}[language=@LANG@,@CONT@numbers=left]",
    finish = "\\end{lstlisting}",
  },
  plain = {
    begin  = "\\ctxlisting%",
    finish = "\\endctxlisting",
  },
}

M.defaults = {
  style    = "bash",
  wrapper  = "lstlisting",
  comment  = nil,
  language = nil,
  begin    = nil,
  finish   = nil,
}

--- \subsubsection{Option handling}
--- \texttt{new\_opts} layers explicit overrides on top of the defaults; \texttt{resolve}
--- then fills any still-empty field from the chosen style and wrapper presets.
function M.new_opts(over)
  local o = {}
  for k, v in pairs(M.defaults) do o[k] = v end
  if over then
    for k, v in pairs(over) do
      if v ~= nil then o[k] = v end
    end
  end
  return o
end

function M.resolve(o)
  local style = M.styles[o.style]
  if not style then
    error("comment2tex: unknown style: " .. tostring(o.style)
      .. " (expected bash, lua or yaml)")
  end
  local wrapper = M.wrappers[o.wrapper]
  if not wrapper then
    error("comment2tex: unknown wrapper: " .. tostring(o.wrapper)
      .. " (expected lstlisting or plain)")
  end
  o.comment  = o.comment  or style.comment
  o.language = o.language or style.language
  o.begin    = o.begin    or wrapper.begin
  o.finish   = o.finish   or wrapper.finish
  return o
end

--- \subsubsection{Conversion}
--- The source is walked line by line.  A line that starts with the comment prefix is
--- documentation: any open code block is closed and the line is emitted with the prefix
--- (and one optional following space) stripped.  Anything else is code: a block is
--- opened if one is not already running and the line is emitted unchanged.  A final
--- close guarantees the listing is shut even when the file ends inside code.
function M.convert(o, lines, emit)
  local prefix = o.comment
  local plen = #prefix
  local in_code = false
  local block_count = 0

  local function open_code()
    if not in_code then
      block_count = block_count + 1
      local cont = block_count == 1 and "" or "firstnumber=last,"
      local line = o.begin:gsub("@LANG@", o.language):gsub("@CONT@", cont)
      emit(line)
      in_code = true
    end
  end

  local function close_code()
    if in_code then
      emit(o.finish)
      in_code = false
    end
  end

  for _, line in ipairs(lines) do
    if line:sub(1, plen) == prefix then
      close_code()
      emit((line:sub(plen + 1):gsub("^ ", "")))
    else
      open_code()
      emit(line)
    end
  end
  close_code()
end

--- \subsubsection{Tangling}
--- The inverse of weaving: \texttt{tangle} drops every doc-comment line and emits the
--- rest of the source unchanged, so an annotated file yields its runnable form without a
--- separate \texttt{sed}/\texttt{grep} pass.  The lines it keeps are exactly the lines
--- \texttt{convert} would have numbered, so a tangled file and its typeset listing agree
--- on line numbers.
function M.tangle(o, lines, emit)
  local prefix = o.comment
  local plen = #prefix
  for _, line in ipairs(lines) do
    if line:sub(1, plen) ~= prefix then
      emit(line)
    end
  end
end

--- \subsubsection{File helpers}
--- \texttt{read\_lines} slurps a file and splits it into lines, keeping a final
--- unterminated line if present.  \texttt{convert\_file} returns the converted \LaTeX\
--- as a string; \texttt{write\_file} sends it to \texttt{outfile}.
function M.read_lines(path)
  local fh, err = io.open(path, "r")
  if not fh then
    error("comment2tex: cannot open input: " .. tostring(err))
  end
  local data = fh:read("*a")
  fh:close()
  local lines = {}
  for line in (data .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  if data:sub(-1) == "\n" then
    lines[#lines] = nil
  end
  return lines
end

function M.convert_file(path, o)
  o = M.resolve(o or M.new_opts())
  local out = {}
  M.convert(o, M.read_lines(path), function(line) out[#out + 1] = line end)
  return table.concat(out, "\n") .. "\n"
end

function M.tangle_file(path, o)
  o = M.resolve(o or M.new_opts())
  local out = {}
  M.tangle(o, M.read_lines(path), function(line) out[#out + 1] = line end)
  return table.concat(out, "\n") .. "\n"
end

function M.write_file(infile, outfile, o)
  local text = M.convert_file(infile, o)
  local fh, err = io.open(outfile, "w")
  if not fh then
    error("comment2tex: cannot open output: " .. tostring(err))
  end
  fh:write(text)
  fh:close()
  return outfile
end

--- \subsubsection{The \TeX-facing entry point}
--- \cs{includebash} and \cs{includelua} call this through \cs{directlua}: it converts
--- \texttt{infile} to \texttt{outfile} for the given style and wrapper, entirely in
--- process.  Keeping the signature positional keeps the \TeX\ side trivial.
function M.write(style, wrapper, infile, outfile)
  return M.write_file(infile, outfile,
    M.new_opts{ style = style, wrapper = wrapper })
end

--- \subsubsection{Command-line interface}
--- Parsing mirrors the documented options; \texttt{die} reports to stderr and exits
--- non-zero.  Only reached when the file is executed by \texttt{texlua}, never when it
--- is loaded as a library.
local function usage(stream)
  stream:write([[
Usage: comment2tex.lua [options] <input>

Weave a source with embedded LaTeX doc-comments into LaTeX, or with
--tangle strip the doc-comments back to the runnable source.

Options:
  -s, --style NAME       bash (##), lua (---) or yaml (##) [default: bash]
  -w, --wrapper NAME     lstlisting or plain [default: lstlisting]
  -c, --comment PREFIX   doc-comment prefix marking a doc line
  -l, --language LANG    listing language for code blocks
  -b, --begin TEMPLATE   listing begin template (@LANG@, @CONT@)
  -e, --end TEMPLATE     listing end template
  -t, --tangle           strip doc-comments; emit runnable source
  -o, --output FILE      write output here instead of stdout
  -h, --help             show this help

Templates substitute @LANG@ with the language and @CONT@ with
"firstnumber=last," on continuation blocks (empty on the first).
]])
end

local function die(msg)
  io.stderr:write("comment2tex: " .. msg .. "\n")
  os.exit(1)
end

function M.main(argv)
  local over = {}
  local tangle = false
  local input
  local i = 1
  local function value(flag)
    i = i + 1
    local v = argv[i]
    if v == nil then die("missing value for " .. flag) end
    return v
  end
  while i <= #argv do
    local a = argv[i]
    if a == "-h" or a == "--help" then
      usage(io.stdout); return 0
    elseif a == "-s" or a == "--style" then
      over.style = value(a)
    elseif a == "-w" or a == "--wrapper" then
      over.wrapper = value(a)
    elseif a == "-c" or a == "--comment" then
      over.comment = value(a)
    elseif a == "-l" or a == "--language" then
      over.language = value(a)
    elseif a == "-b" or a == "--begin" then
      over.begin = value(a)
    elseif a == "-e" or a == "--end" then
      over.finish = value(a)
    elseif a == "-t" or a == "--tangle" then
      tangle = true
    elseif a == "-o" or a == "--output" then
      over.output = value(a)
    elseif a == "--" then
      input = argv[i + 1]; break
    elseif a:sub(1, 1) == "-" and a ~= "-" then
      die("unknown option: " .. a)
    elseif input == nil then
      input = a
    else
      die("unexpected argument: " .. a)
    end
    i = i + 1
  end

  if not input then
    usage(io.stderr); return 1
  end

  local ok, err = pcall(function()
    local o = M.resolve(M.new_opts(over))
    local text = tangle and M.tangle_file(input, o)
      or M.convert_file(input, o)
    if over.output then
      local fh, e = io.open(over.output, "w")
      if not fh then
        error("comment2tex: cannot open output: " .. tostring(e))
      end
      fh:write(text)
      fh:close()
    else
      io.stdout:write(text)
    end
  end)
  if not ok then die(tostring(err):gsub("^comment2tex: ", "")) end
  return 0
end

if not LIBRARY_MODE then
  os.exit(M.main(arg))
end

return M
