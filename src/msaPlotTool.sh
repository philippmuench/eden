#!/bin/bash

VERSION=0.1
SUBJECT=alignmentPlot
USAGE="Usage: command -hv args"
LOG_FILE="alignmentPlot.log"

# --- Option processing --------------------------------------------
if [ $# == 0 ] ; then
    echo $USAGE
    exit 1;
fi

. shflags

# options
DEFINE_boolean 'single' false 'single file input mode' 

DEFINE_string 'gap_file' 'example.gap.txt' 'path to gap file' 'g'
DEFINE_string 'dnds_file' 'example.dnds.txt' 'path to dnds file' 'd'
DEFINE_string 'sample_name' 'example' 'name of sample/protein familiy' 'n'
DEFINE_string 'output_folder' 'example' 'path to output folder' 'o'

# parse command line
FLAGS "$@" || exit 1
eval set -- "${FLAGS_ARGV}"
shift $(($OPTIND - 1))

TAG=${FLAGS_sample}

# --- Logging -----------------------------------------------------
function log() {
    if [ $HIDE_LOG ]; then
        echo -e "[$TAG] $@" >> $LOG_FILE
    else
        echo "[`date +"%Y/%m/%d:%H:%M:%S %z"`] [$TAG] $@" | tee -a $LOG_FILE
    fi
}


plotIt(){
		Rscript msaPlotWrapper.R ${FLAGS_dnds_file} \
		${FLAGS_gap_file} \
		${FLAGS_sample_name} \
        ${FLAGS_output_folder}
}


main(){
	if [ ${FLAGS_single} -eq ${FLAGS_TRUE} ]; then
		plotIt
	fi
}

main "$@"

#log "[I] pipeline end"
# -----------------------------------------------------------------
