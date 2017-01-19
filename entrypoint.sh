#!/bin/bash

# import logging functions
.  /home/eden/src/lib.logging.sh

set -e
LOG_FILE="/home/eden/data/eden.log"
# initialize parameters
THREADS=2
GAP=0.7
ONLY='false'
SHINY='true'
SAMPLE=$(date +%Y-%m-%d-%T)

# generate output folder with right permissions
mkdir -p /home/eden/data/tar && chmod -R 777 /home/eden/data/tar

for i in "$@"
do
case $i in
    -p=*|--processes=*)
    THREADS="${i#*=}"
    ;;
    -g=*|--gap=*)
    GAP="${i#*=}"
    ;;
    -s=*|--sample=*)
    SAMPLE="${i#*=}"
    ;;
    -t|--test)
    TEST=true
    ;;
    -n|--normal)
    TEST=false
    ;;
    -x|--noapp)
    SHINY=false
    ;;
    -z|--onlyapp)
    ONLY=true
    ;;
    *)
    echo "Unknown option"
    ;;
esac
done

readonly THREADS
readonly TEST
readonly SAMPLE
readonly GAP
readonly ONLY

if [ "$ONLY" = true ]; then
      echo "Test"
      echo "Test" > /home/eden/testfile.txt 
#    # clean up input files
#    echocolor "Started. Visit http://localhost:3838/eden-visualizer"
#    nohup shiny-server > my.log 2>&1&
#    echo $! > /home/eden/pid.txt
else
    # check groups.txt
    ./check.sh --faa_folder data/faa --ffn_folder data/ffn --cpu "$THREADS" --hmmfile data/annotation/annotation.hmm --output data/ko --gfam data/groups.txt

    # check if the test mode is enabled
    if [ "$TEST" = true ]; then
        ./eden.sh --docker --cpu_number "$THREADS" --gap_threshold "$GAP" --test --name "$SAMPLE"
    else
        ./eden.sh --docker --cpu_number "$THREADS" --gap_threshold "$GAP" --name "$SAMPLE"
    fi

    # start docker in background
    echocolor "[Please cite: Münch P.C. et. al, EDEN: evolutionary dynamics within environments]"

    if [ "$SHINY" = true ]; then
        echocolor "Starting server, please visit http://localhost:3838/eden-visualizer"
        nohup shiny-server > my.log 2>&1 &
        echo $! > /home/eden/pid.txt
    else
        echocolor "No shiny server started due to the -x or --noapp mode"
    fi
fi
