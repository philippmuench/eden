#!/bin/bash

. /opt/bin/shflags
. /home/eden/src/lib.logging.sh 

USAGE="Usage: command -hv args"
FFN_ENDING=".ffn"
FAA_ENDING=".faa"
TARNAME=$(date +%Y-%m-%d-%T)

# process paramters
if [ $# == 0 ] ; then
    echo $USAGE
    exit 1;
fi

LOG_FILE="/home/eden/data/eden.log"

# Pipeline steps
DEFINE_boolean 'docker' false 'docker mode' 'o' # standard procedure
DEFINE_boolean 'all' false 'all pipeline steps will be executed' 'v' # for group-wise analysis
DEFINE_boolean 'test' false 'run analysis only on a random subset for testing purpose' 'r'
DEFINE_boolean 'annotation' false 'run analysis with annotation' 'a'

# define input paths
DEFINE_string 'input_faa' '/home/eden/data/faa' 'input faa folder absolute'
DEFINE_string 'input_ffn' '/home/eden/data/ffn' 'input ffn folder absolute'
DEFINE_string 'gfams' '/home/eden/data/groups.txt' 'path to orthoMCL output'
DEFINE_string 'sample_list' '/home/eden/data/samples.txt' 'sample processing table'
DEFINE_string 'faa' 'faa' 'path to faa folder in /home/eden/data' 'x'
DEFINE_string 'ffn' 'ffn' 'path to ffn folder in/home/eden/data' 'y'
DEFINE_string 'name' 'eden_run' 'run name'
DEFINE_string 'log' '/home/eden/log.txt' 'path to log file'

# define name of result folders
DEFINE_string 'hits_folder' 'hits' 'path to hits folder'
DEFINE_string 'msa_folder' 'msa' 'path to msa folder'
DEFINE_string 'codon_folder' 'codon' 'path to codon folder'
DEFINE_string 'tree_folder' 'tree' 'path to tree folder'
DEFINE_string 'dnds_folder' 'dnds' 'path to dnds folder'
DEFINE_string 'gap_folder' 'gap' 'path to gap folder'
DEFINE_string 'consensus_folder' 'consensus' 'path to consensus folder'
DEFINE_string 'repeat_folder' 'repeat' 'path to repeat folder'
DEFINE_string 'summary_folder' 'summary' 'path to summary folder'
DEFINE_string 'plot_folder' 'alignment_plots' 'path to alignment plot folder'
DEFINE_string 'annotation_folder' '/home/eden/hmm' 'path to annotation folder'

# define thresholds and parameters
DEFINE_string 'num' '30' 'number of families to select for random subset (-r) option' 'n'
DEFINE_string 'sample' 'run1' 'name of sample'
DEFINE_string 'path' '/home/eden' 'path to working dir' 
DEFINE_string 'gap_threshold' '0.7' 'positions in the alignment with more gaps than this threshold will be skipped'
DEFINE_string 'top_number' '10' 'number of top candidates for plotting'
DEFINE_string 'cpu_number' ' 10' 'number of CPUs to use'

# parse command line
FLAGS "$@" || err "No command line arguments provided"
eval set -- "${FLAGS_ARGV}"
shift $(($OPTIND - 1))
TAG=${FLAGS_sample}
HIDE_LOG=false
#LOG_FILE="data/$TAG.log"
#LOG_FILE="/home/eden/data/$TAG.log"
#LOG_SHINY=${FLAGS_log}

# Only after this point should you enable `set -e` as
# shflags does not work when that is turned on first.
set -e

# this function checks the input files and calls getSequences for each gfam
orthoMCL() {
    # check if files are there
    for f in ${FLAGS_input_faa}/*
    do
        filename=$(basename "$f")
        extension="${filename##*.}"
        basename="${filename%.*}"
        [[ -f ${FLAGS_input_ffn}/$basename$FFN_ENDING ]] || err "Missing corresponding file" 
        done

    if [ ${FLAGS_test} -eq ${FLAGS_TRUE} ]; then
        log "[I] Create random subset"
        GFAM_SUBSET=$(mktemp -q /tmp/gfam_subset_XXXX.txt) || err "Failed to create temp file"
        sort -R ${FLAGS_gfams} | head -n ${FLAGS_num} > $GFAM_SUBSET
        GFAM_LIST=$(mktemp -q /tmp/gfam_list_XXXX.txt) || {
        echoerror "Failed to create temp file"; exit 1; }
        awk -F ':' '{print $1}' $GFAM_SUBSET  > $GFAM_LIST
        log "[I] gfam list (limited to ${FLAGS_num} gfams) written to $GFAM_LIST"
    else
        # create gfam list
        GFAM_LIST=$(mktemp -q /tmp/gfam_list_XXXX.txt) || err "Failed to create temp file"
        awk -F ':' '{print $1}' ${FLAGS_gfams} > $GFAM_LIST
        log "[I] gfam list written to $GFAM_LIST"
    fi

    # iterate over gfam list
    rm -rf ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}
    mkdir -p ${FLAGS_path}/${FLAGS_sample}
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_ffn}
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_faa}
    log "[I] Output folder ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/ created"
    log "[I] Exporting hits (paralell mode)"
    cat $GFAM_LIST | parallel --no-notice --bar --files -j ${FLAGS_cpu_number} \
        getSequences {} ${FLAGS_gfams} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder} $FAA_ENDING $FFN_ENDING ${FLAGS_input_faa} ${FLAGS_input_ffn} #2> /dev/null
    rm $GFAM_LIST
}

# this function is used to find pegs in faa and fna files and create gfam specific fasta files, $3: sample folder
# $4: faa ending; $5 ffn ending
getSequences()
{
    while IFS= read -r i
    do
        peg_sample=(`echo $i | awk -F '|' '{print $1}' `)
        peg_ident=(`echo $i | awk -F '|' '{print $2"$"}' `)
        # check if we can find the sample in our data
        echo "$peg_sample"
        # check if the sample is in the grouping
        if [ -f $6/$peg_sample$4 ] ; then
            echo ">"$i >> $3/faa/$1$4
            sed '/'$peg_ident'/,/peg/{//!b};d' $6/$peg_sample$4  >> $3/faa/$1$4
            echo ">"$i >> $3/ffn/$1$5
            sed '/'$peg_ident'/,/peg/{//!b};d' $7/$peg_sample$5 >> $3/ffn/$1$5
        fi
    done < <(cat $2 | sed 's/://' | grep "^$1 " | awk '!($1="")' | sed 's/^.//' | sed -e 's/\s\+/\n/g')
}

# this function check if hits have >1 sequences
checkHits()
{
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/unused
    # process faa files
    for file in ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_faa}/*.faa ; do
        if [ "$(grep -c "^>" "${file}")" -gt 1 ]
        then
            log "$file looks fine" 
        else
            mv ${file} ${FLAGS_path}/${FLAGS_sample}/unused || err "error when moving files"
            log "$file deleted"
        fi
    done
    # process ffn files
    for file in ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_ffn}/*.ffn ; do
        if [ "$(grep -c "^>" "${file}")" -gt 1 ]
        then
            log "$file looks fine"
        else
            mv ${file} ${FLAGS_path}/${FLAGS_sample}/unused || err "error when moving files"
            log "$file deleted"
        fi
    done
}


# this function generates codon alignment based on msa faa input ($2). Writes output to $3
runCodon()
{
    filename=$(basename "$1")
    extension="${filename##*.}"
    basename="${filename%.*}"
    log "runCodon calles with $1"
    /opt/bin/pal2nal.pl $2/$basename.faa.msa $1 -output fasta > $3/$basename.codon.aln 2> /dev/null || err "pal2nal failed"
}

# this function creates MSA alignment for each protein family
msa()
{
  rm -rf ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}
  mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}
  mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_ffn}
  mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_faa}
  log "[I] Run msa alignment (parallel mode)"
  target=$(ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_faa}/* -lh | wc -l)
  ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_faa}/* |\
      parallel --no-notice --bar --files -j ${FLAGS_cpu_number} \
      muscle -in {} -out {.}.faa.msa
  ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_ffn}/* |\
      parallel --no-notice --bar --files -j ${FLAGS_cpu_number} \
      muscle -in {} -out {.}.ffn.msa
  log "[I] Moving files"
  mv ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_faa}/*.faa.msa \
      ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_faa}
  mv ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_ffn}/*.ffn.msa \
      ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_ffn}
}

# this function creates codon alignment for each protein family
codon()
{
    log "codon called"
    rm -rf ${FLAGS_path}/${FLAGS_sample}/${FLAGS_codon_folder}
    mkdir -p  ${FLAGS_path}/${FLAGS_sample}/${FLAGS_codon_folder}
    log "[I] Run codon alignment (parallel mode)"
    ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_hits_folder}/${FLAGS_ffn}/* | parallel --no-notice --bar --files -j ${FLAGS_cpu_number} runCodon\
     {} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_faa} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_codon_folder} || err "cannot run parallel to generate codon alignment"
    log "codon parallel executed"
}

# executes clearcut command used by parallel
runClearcut()
{
    filename=$(basename "$1")
    extension="${filename##*.}"
    basename="${filename%.*}"
    basename2="${basename%.*}"
    # this will throw an error if there are < 2 sequences in alignment, need to filter it before
    clearcut --in $2/$basename2.ffn.msa -P -a --out $3/$basename.phy || true
}

# this function creates a tree for each protein family
tree()
{
    rm -rf ${FLAGS_path}/${FLAGS_sample}/${FLAGS_tree_folder} || err "cannot remove directory"
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_tree_folder} || err "cannot create directory"
    ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_ffn}/*.msa | parallel --no-notice --bar --files -j ${FLAGS_cpu_number} runClearcut\
     {} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_ffn} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_tree_folder} || err "cannot run parallel to generate trees"
}

# this function rewrites fasta files
reformatfasta()
{
    log "[I] Reformatting files in folder $1"
    for file in $1/*; do mv "$file" "${file/.*}.msa_unformatted"; done
    cwd=$(pwd)
    cd $1
    /home/eden/src/reformat.pl -g '-' -uc -l 100 fas a2m '*.msa_unformatted' fasta.msa >\
     /dev/null 2> /dev/null || err "cannot reformat FASTA files"
    cd $cwd
}

# this function gets executed by parallel and runs the phylotreetols for dnds
runTreeTools()
{
    filename=$(basename "$1")
    extension="${filename##*.}"
    basename="${filename%.*}"
    basename2="${basename%.*}"
      java -cp /home/eden/src/phyloTreeTools/ phyloDriver \
        -p -n $3/$basename2.ffn.phy \
        -t $1 \
        -f DelTran -cyt \
        -o $4/$basename.txt \
        -tc $5/$basename2.msa \
        -d > /dev/null 2> /dev/null || true
}

# this function creates dnds ratio for every protein family
dnds()
{
    rm -rf ${FLAGS_path}/${FLAGS_sample}/${FLAGS_dnds_folder}  || err "cannot create folder"
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_dnds_folder} || err "cannot create folder"
    reformatfasta ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_ffn} || err "cannot reformat files"
    reformatfasta ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_faa} || err "cannot reformat files"
    reformatfasta ${FLAGS_path}/${FLAGS_sample}/${FLAGS_codon_folder} || true # ignore errors here that occur when a sequence only containing gaps 
    log "[I] Calculating dnds values"
    ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_faa}/*.msa | parallel --no-notice --bar --files -j ${FLAGS_cpu_number} runTreeTools\
     {} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_tree_folder} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_dnds_folder} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_codon_folder} || err "error on dnds parallel"
}

runGaps()
{
    filename=$(basename "$1")
    basename="${filename%.*}"
        /home/eden/src/score_conservation.py \
        -d /home/eden/src/blosum62.distribution \
        -m /home/eden/src/blosum62.bla \
        -s vn_entropy -g 0.999999999999999999999999 -w 0  $1 | \
        awk '{print $2}' | tail -n+2 > $2/$basename.gap.txt || err "error on score_conservation.py"
}

# this function counts then number of gaps in the alignment
getGaps()
{
    log "[I] Check for gaps in the alignment"
    rm -rf ${FLAGS_path}/${FLAGS_sample}/${FLAGS_gap_folder}
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_gap_folder}
    ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_faa}/*.msa | parallel --no-notice --bar --files -j ${FLAGS_cpu_number} runGaps\
     {} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_gap_folder} || err "cannot run parallel to generate gap statistics"
}


# executes createconsensus by parallel
runConsensus_faa()
{
    local filename=$(basename "$1")
    local basename="${filename%.*}"
    echo ">"$basename > $2/$basename.consensus.faa
    /home/eden/src/createConsensus.py \
        -d /home/eden/src/blosum62.distribution \
        -m /home/eden/src/blosum62.bla \
        -s shannon_entropy \
        -w 1 $1 \
        >> $2/$basename.consensus.faa || err "error on createConsensus.py"
}


# executes createconsensus by parallel
runConsensus_ffn()
{
    filename=$(basename "$1")
    basename="${filename%.*}"
    echo ">"$basename > $2/$basename.consensus.ffn
    /home/eden/src/createConsensus.py \
        -d /home/eden/src/blosum62.distribution \
        -m /home/eden/src/blosum62.bla \
        -s shannon_entropy \
        -w 1 $1 \
        >> $2/$basename.consensus.ffn || err "cannot create consensus ffn"
}

# this function creates a consensus sequence based on the most occuring base in alignment
createConensus()
{
    log "[I] Generate consensus sequence"
    rm -rf ${FLAGS_path}/${FLAGS_sample}${FLAGS_consensus_folder}
    mkdir -p ${FLAGS_path}/${FLAGS_sample}/${FLAGS_consensus_folder};
    ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_ffn}/*.msa | parallel --no-notice --bar --files -j ${FLAGS_cpu_number} runConsensus_ffn\
     {} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_consensus_folder} || err "cannot run runConsensus_ffn in parallel"
    ls ${FLAGS_path}/${FLAGS_sample}/${FLAGS_msa_folder}/${FLAGS_faa}/*.msa | parallel --no-notice --bar --files -j ${FLAGS_cpu_number} runConsensus_faa\
     {} ${FLAGS_path}/${FLAGS_sample}/${FLAGS_consensus_folder} || err "cannot run runConsensus_faa in parallel"
}

generateGfamTable()
{
    # check if gfam list exists
    log "[I] Generate gfam list from all .${FLAGS_annotation} files in ${FLAGS_annotation_folder} folder"
    if [ ! -e "${FLAGS_gfams}" ]; then
        # get a list with all KO terms
        cat ${FLAGS_annotation_folder}*.${FLAGS_annotation} | awk -F '\t' '{print $2}' | sort | uniq | tail -n +2 > all_terms.tmp
        while read ko; do
            echo "$ko:" $(grep "$ko" ${FLAGS_annotation_folder}/*${FLAGS_annotation} | awk -F '\t' '{print $1}' | awk -F ':' '{print $2}' | tr "\n" " ") >> ${FLAGS_gfams}
            done <all_terms.tmp
    rm -f all_terms.tmp
    else
        log "[E] ${FLAGS_gfams} exists. This file will not be overwritten. If you want to use this gfam table as input, please remove the -k or --generateGfamTable option."
    fi
}

main()
{
    export -f getSequences
    export -f runCodon
    export -f runClearcut
    export -f runTreeTools
    export -f runConsensus_faa
    export -f runConsensus_ffn
    export -f runGaps
    rm -rf $LOG_FILE || true

    if [ ${FLAGS_docker} -eq ${FLAGS_TRUE} ]; then
        rm -rf ${FLAGS_path}/${FLAGS_sample}
        mkdir ${FLAGS_path}/${FLAGS_sample}
        # check if sample table is provided
        if [ ! -f /home/eden/data/samples.txt ]; then
            log "[I] samples.txt not found, run analysis on pooled samples"
            # these steps are executed if a samples.txt will not be profided, analysis based on grouping of all sampels
	    shinylog "extract hits on pooled samples" & orthoMCL
            shinylog "checking hits on pooled samples" & checkHits
            shinylog "generate alignments on pooled samples" & msa
            shinylog "generate codon alignment on pooled samples" & codon
            shinylog "generating trees on pooled samples" & tree
            shinylog "calculate ratio on pooled samples" & dnds
            shinylog "get alignment informations on pooled samples" & getGaps
            shinylog "create consensus sequence on pooled samples" & createConensus
	    shinylog "exporting results"
            log "analysis complete, exported to /home/eden/data/${FLAGS_name}.tar]"
            pwd=$(pwd)
            cd ${FLAGS_path} && tar --append --file=data/tar/${FLAGS_name}.tar ${FLAGS_sample} && cd $pwd
            shinylog "dnds finished"
            echocolor "[Results for pooled samples are written to /home/eden/data/${FLAGS_name}.tar]"
        else
            log "[I] samples.txt detected, run analysis on groups"
            # run over all lines in sample file and start pipeline for new samples
            while read line; do
                sample_name=$(echo $line | cut -f1 -d ';')
                sample_files=$(echo $line | cut -f2 -d ';')
                fileArray=(${sample_files//+/ })
                rm -rf /home/eden/faa_tmp /home/eden/ffn_tmp
                mkdir -p /home/eden/faa_tmp /home/eden/ffn_tmp
                if [ ${#fileArray[@]} -eq 1 ]; then
                    # there is only one file
                    cp /home/eden/data/${FLAGS_faa}/$sample_files$FAA_ENDING /home/eden/faa_tmp/
                    cp /home/eden/data/${FLAGS_ffn}/$sample_files$FFN_ENDING /home/eden/ffn_tmp/
                else
                    # iterate through the array and copy files to tmp folder
                    for i in "${fileArray[@]}"
                    do
                    :
                        cp ${FLAGS_input_faa}/$i$FAA_ENDING /home/eden/faa_tmp/
                        cp ${FLAGS_input_ffn}/$i$FFN_ENDING /home/eden/ffn_tmp/
                    done
                fi
                log "[I] Processing $sample_name with sample $sample_files"
                if [ ${FLAGS_test} -eq ${FLAGS_TRUE} ]; then
                    log "[I] test mode, run on subset of 100 groups"
                    /home/eden/eden.sh --sample $sample_name --input_faa /home/eden/faa_tmp --input_ffn /home/eden/ffn_tmp --all --gfams ${FLAGS_gfams} --test -n ${FLAGS_num} --cpu_number ${FLAGS_cpu_number} --gap_threshold ${FLAGS_gap_threshold} --name ${FLAGS_name}
                else
                    /home/eden/eden.sh --sample $sample_name --input_faa /home/eden/faa_tmp --input_ffn /home/eden/ffn_tmp --all --gfams ${FLAGS_gfams} --cpu_number ${FLAGS_cpu_number} --gap_threshold ${FLAGS_gap_threshold} --name ${FLAGS_name}
                fi
            done <${FLAGS_sample_list}
        fi
    fi

    # these steps are executed if a samples.txt file will be provided for each grouping seperately
    if [ ${FLAGS_all} -eq ${FLAGS_TRUE} ]; then
	shinylog "extract hits on $TAG samples" & orthoMCL
	shinylog "checking hits on $TAG samples" & checkHits
	shinylog "generate alignments on $TAG samples" & msa
	shinylog "generate codon alignment on $TAG samples" & codon
	shinylog "generating trees on $TAG samples" & tree
	shinylog "calculate ratio on $TAG samples" & dnds
	shinylog "get alignment informations on $TAG samples" & getGaps
	shinylog "create consensus sequence on $TAG samples" & createConensus
	shinylog "exporting results"		
        pwd=$(pwd)
        cd ${FLAGS_path} && tar --append --file=data/tar/${FLAGS_name}.tar ${FLAGS_sample} && cd $pwd
        chmod 777 ${FLAGS_path}/data/tar/${FLAGS_name}.tar
        echocolor "[Results for sample $TAG are written to /home/eden/data/tar/${FLAGS_name}.tar]"
	shinylog "dnds finished"

    fi
}

main "$@"
