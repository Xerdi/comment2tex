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

NAME     = comment2tex
DTX      = comment2tex.dtx
INS      = comment2tex.ins
WRAPPERS = comment2tex.sty comment2tex.tex
DOC      = comment2tex.pdf
README   = README.md
TESTSH   = comment2tex-test.sh

# Literate sources converted to standalone fragments named to match the package
# convention.  comment2tex.lua documents itself with the "---" doc-comment style.
LUA_SRC  = comment2tex.lua
FRAGS    = $(LUA_SRC:.lua=.c2t.tex)

# Files shipped in the CTAN upload: the hand-written sources (.dtx, .ins, and the
# converter comment2tex.lua) plus the README and the built PDF.  Per CTAN's upload
# guide no generated/derived file is shipped: comment2tex.sty/.tex are regenerated
# from the .ins by CTAN and TeX Live, and comment2tex.lua ships as its annotated
# source (its "---" lines are ordinary Lua comments, so it runs unmodified) rather
# than a tangled copy, which would be a derived file.  The test suite is a
# development artefact and is not shipped either; the manual's Testing section
# \includebash's it only when present (guarded by \IfFileExists), so the bundled
# sources still build the PDF without it.
DISTFILES = $(DTX) $(INS) $(README) $(LUA_SRC) $(DOC)

.PHONY: all wrappers doc test frags package clean help

all: doc

## wrappers: extract comment2tex.sty and comment2tex.tex from the .dtx.
wrappers: $(WRAPPERS)
$(WRAPPERS): $(DTX) $(INS)
	$(TEX) $(INS)

## doc: typeset the documentation (LuaLaTeX, for the in-process \includelua demo).
##      latexmk reruns LuaLaTeX until the table of contents resolves.
doc: $(DOC)
$(DOC): $(DTX) comment2tex.sty comment2tex.lua $(TESTSH)
	$(LATEXMK) $(PVC) --lualatex --interaction=nonstopmode $(DTX)

## test: run the cross-engine test suite.
test:
	./comment2tex-test.sh

## frags: convert the literate sources to standalone .c2t.tex fragments.
frags: $(FRAGS)

# Lua sources use the "---" doc-comment style.
%.c2t.tex: %.lua comment2tex.lua
	$(C2T) --style lua -o $@ $<

## package: build a CTAN-ready zip (sources + PDF under a comment2tex/ dir).
##          Only sources and the built PDF go in -- no generated/derived files
##          (see the DISTFILES note and the README's CTAN submission section).
package: $(NAME).zip
$(NAME).zip: $(DISTFILES)
	$(RM) -r $(NAME) $(NAME).zip
	mkdir $(NAME)
	cp $(DISTFILES) $(NAME)/
	zip -r $(NAME).zip $(NAME)
	$(RM) -r $(NAME)

## clean: remove generated files.
clean:
	$(RM) -r $(NAME) $(NAME).zip
	$(RM) $(WRAPPERS) $(FRAGS) $(DOC) *.c2t.tex \
	  comment2tex.aux comment2tex.toc comment2tex.log \
	  comment2tex.idx comment2tex.ilg comment2tex.ind comment2tex.glo \
	  comment2tex.out comment2tex.hd comment2tex.fls comment2tex.fdb_latexmk

## help: list available targets.
help:
	@echo "Targets:"
	@echo "  all        build the documentation (default)"
	@echo "  doc        typeset comment2tex.pdf with LuaLaTeX (WATCH=1 to keep rebuilding)"
	@echo "  wrappers   extract comment2tex.sty and comment2tex.tex"
	@echo "  frags      convert literate sources to .c2t.tex fragments"
	@echo "  package    build a CTAN-ready zip (comment2tex.zip)"
	@echo "  test       run the cross-engine test suite"
	@echo "  clean      remove generated files"
