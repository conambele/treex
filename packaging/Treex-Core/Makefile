SHELL=bash

include ../common.mk

ALLDIRS=${READ_T} ${WRITE_T} ${TOOLS} ${BIN} #bin, core & util are created automatically

MODULES := ${CORE} \
           ${UTIL} \
		   $(addprefix ${BIN}/, treex ttred) \
           $(addprefix ${TOOLS}/, Probe.pm) \
           $(addprefix ${LIB}/, Treex.pm) \
           $(addprefix ${TREEX}/, Core.pm) \
           $(addprefix ${READ}/, Text.pm Treex.pm Sentences.pm BaseReader.pm BaseTextReader.pm BaseSplitterRole.pm) \
           $(addprefix ${READ_T}/, base.t) \
           $(addprefix ${WRITE}/, Text.pm Treex.pm Sentences.pm BaseWriter.pm BaseTextWriter.pm)

postprocess: export.tmp
	./postprocess_POD.pl
	#perl -p -i -e 's/^([^#]*Interset)/#\1/' lib/Treex/Core/Node/A.pm

parser.tmp:
	cd lib/Treex/Core/ && ./compile_grammar.pl && rm compile_grammar.pl
	touch $@
