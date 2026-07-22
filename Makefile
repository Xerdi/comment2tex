# comment2tex --- Makefile
## \subsection{Configuration}
## The programs the build calls, and a watch switch.  The converter is invoked as
## \texttt{\$(C2T)} throughout; \texttt{make doc WATCH=1} keeps \texttt{latexmk}
## running (\texttt{-{}-pvc}) so the manual rebuilds on every save.
TEXLUA   = texlua
TEX      = tex
LATEXMK  = latexmk
C2T      = $(TEXLUA) comment2tex.lua

WATCH ?=
PVC   = $(if $(WATCH),--pvc,)

## \subsection{Names and the distribution}
## The documented source and its docstrip driver, the generated wrappers, the
## converter, the manual, and the test suite.
NAME     = comment2tex
DTX      = comment2tex.dtx
INS      = comment2tex.ins
WRAPPERS = comment2tex.sty comment2tex.tex
DOC      = comment2tex.pdf
README   = README.md
TESTSH   = comment2tex-test.sh

## \texttt{FRAGS} names the standalone \texttt{.c2t.tex} fragments a source weaves
## to; the converter documents itself with the \texttt{-{}-{}-} Lua style.
LUA_SRC  = comment2tex.lua
FRAGS    = $(LUA_SRC:.lua=.c2t.tex)

## \texttt{DISTFILES} are shipped to CTAN: the hand-written sources plus the README
## and the built PDF.  Per CTAN's upload guide no generated or derived file goes in
## --- \texttt{comment2tex.sty}/\texttt{.tex} are regenerated from the \texttt{.ins},
## and \texttt{comment2tex.lua} ships as its annotated source (its \texttt{-{}-{}-}
## lines are ordinary Lua comments, so it runs unmodified) rather than a tangled
## copy.  The test suite is a development artefact and is not shipped either; the
## manual's \emph{Testing} section \cs{includebash}es it only when present (guarded
## by \cs{IfFileExists}), so the bundled sources still build the PDF without it.
## See the README's CTAN submission section for the full rationale.
DISTFILES = $(DTX) $(INS) $(README) $(LUA_SRC) $(DOC)

.PHONY: all wrappers doc test frags package clean help

all: doc

## \subsection{Targets}
## \texttt{wrappers} extracts the runtime \texttt{.sty}/\texttt{.tex} from the
## \texttt{.dtx} with \texttt{docstrip}.
wrappers: $(WRAPPERS)
$(WRAPPERS): $(DTX) $(INS)
	$(TEX) $(INS)

## \texttt{doc} typesets the manual; \texttt{latexmk} reruns Lua\LaTeX\ until the
## cross-references settle.  It depends on the test suite too, so the \emph{Testing}
## section restages whenever the harness changes.
doc: $(DOC)
$(DOC): $(DTX) comment2tex.sty comment2tex.lua $(TESTSH)
	$(LATEXMK) $(PVC) --lualatex --interaction=nonstopmode $(DTX)

## \texttt{test} runs the cross-engine suite (\texttt{comment2tex-test.sh}).
test:
	./comment2tex-test.sh

## \texttt{frags} weaves the literate sources into standalone \texttt{.c2t.tex}
## fragments; the pattern rule uses the Lua style for a \texttt{.lua} source.
frags: $(FRAGS)

%.c2t.tex: %.lua comment2tex.lua
	$(C2T) --style lua -o $@ $<

## \texttt{package} assembles the CTAN zip: only \texttt{DISTFILES}, under a single
## \texttt{comment2tex/} directory, with no generated or derived file.
package: $(NAME).zip
$(NAME).zip: $(DISTFILES)
	$(RM) -r $(NAME) $(NAME).zip
	mkdir $(NAME)
	cp $(DISTFILES) $(NAME)/
	zip -r $(NAME).zip $(NAME)
	$(RM) -r $(NAME)

## \texttt{clean} removes every generated file --- the wrappers, fragments, the PDF
## and the \TeX\ auxiliaries.
clean:
	$(RM) -r $(NAME) $(NAME).zip
	$(RM) $(WRAPPERS) $(FRAGS) $(DOC) *.c2t.tex \
	  comment2tex.aux comment2tex.toc comment2tex.log \
	  comment2tex.idx comment2tex.ilg comment2tex.ind comment2tex.glo \
	  comment2tex.out comment2tex.hd comment2tex.fls comment2tex.fdb_latexmk

## \texttt{help} lists the targets (echoed literally, so \texttt{make help} needs no
## extra tooling).
help:
	@echo "Targets:"
	@echo "  all        build the documentation (default)"
	@echo "  doc        build comment2tex.pdf (WATCH=1 keeps rebuilding)"
	@echo "  wrappers   extract comment2tex.sty and comment2tex.tex"
	@echo "  frags      convert literate sources to .c2t.tex fragments"
	@echo "  package    build a CTAN-ready zip (comment2tex.zip)"
	@echo "  test       run the cross-engine test suite"
	@echo "  clean      remove generated files"
