# comment2tex --- Makefile
#
# The converter runs under texlua (the standalone Lua interpreter shipped with
# LuaTeX); the documentation is built with LuaLaTeX so the \includelua demo
# converts in process.

TEXLUA   = texlua
TEX      = tex
LATEXMK  = latexmk
C2T      = $(TEXLUA) comment2tex.lua

# Set WATCH=1 (e.g. `make doc WATCH=1`) to keep latexmk running and rebuild the
# documentation on every source change (latexmk --pvc).
WATCH ?=
PVC   = $(if $(WATCH),--pvc,)

DTX      = comment2tex.dtx
INS      = comment2tex.ins
WRAPPERS = comment2tex.sty comment2tex.tex
DOC      = comment2tex.pdf

# Literate sources grouped by doc-comment style ("##" for Bash, "---" for Lua),
# converted to standalone fragments named to match the package convention.
BASH_SRC = bash2tex.sh lua2tex.sh
LUA_SRC  = comment2tex.lua
FRAGS    = $(BASH_SRC:.sh=.c2t.tex) $(LUA_SRC:.lua=.c2t.tex)

.PHONY: all wrappers doc test frags clean help

all: doc

## wrappers: extract comment2tex.sty and comment2tex.tex from the .dtx.
wrappers: $(WRAPPERS)
$(WRAPPERS): $(DTX) $(INS)
	$(TEX) $(INS)

## doc: typeset the documentation (LuaLaTeX, for the in-process \includelua demo).
##      latexmk reruns LuaLaTeX until the table of contents resolves.
doc: $(DOC)
$(DOC): $(DTX) comment2tex.sty comment2tex.lua
	$(LATEXMK) $(PVC) --lualatex --interaction=nonstopmode $(DTX)

## test: run the cross-engine test suite.
test:
	./comment2tex-test.sh

## frags: convert the literate sources to standalone .c2t.tex fragments.
frags: $(FRAGS)

# Bash sources use the "##" doc-comment style.
%.c2t.tex: %.sh comment2tex.lua
	$(C2T) --style bash -o $@ $<

# Lua sources use the "---" doc-comment style.
%.c2t.tex: %.lua comment2tex.lua
	$(C2T) --style lua -o $@ $<

## clean: remove generated files.
clean:
	$(RM) $(WRAPPERS) $(FRAGS) $(DOC) *.c2t.tex \
	  comment2tex.aux comment2tex.toc comment2tex.log \
	  comment2tex.idx comment2tex.glo comment2tex.out comment2tex.hd

## help: list available targets.
help:
	@echo "Targets:"
	@echo "  all        build the documentation (default)"
	@echo "  doc        typeset comment2tex.pdf with LuaLaTeX (WATCH=1 to keep rebuilding)"
	@echo "  wrappers   extract comment2tex.sty and comment2tex.tex"
	@echo "  frags      convert literate sources to .c2t.tex fragments"
	@echo "  test       run the cross-engine test suite"
	@echo "  clean      remove generated files"
