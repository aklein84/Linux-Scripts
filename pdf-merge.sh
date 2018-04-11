#!/bin/bash

# Merge pdfs into one.
# Adam Klein 20180110
# Hastily written to help wife merge homework into one pdf.

usage() {
	echo "./$(basename $0) <PDF OUTPUT NAME> <pdf 1> <pdf 2> <pdf 3> <etc...>"
}

if [ $# -le 1 ]; then
	usage 
	exit 1
fi

PDFNAME="$1"
shift
PDFS="$@"

$(which gs) -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="${PDFNAME}" ${PDFS} 
