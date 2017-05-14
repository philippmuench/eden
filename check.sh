#!/bin/bash

# process paramters
if [ $# == 0 ] ; then
    echo $USAGE
    exit 1;
fi

. /opt/bin/shflags
. /home/eden/src/lib.logging.sh

# define input paths
DEFINE_string 'fasta_folder' '/home/eden/data/fasta' '.fasta files'
DEFINE_string 'faa_folder' '/home/eden/data/faa' 'folder with .faa files'
DEFINE_string 'ffn_folder' '/home/eden/data/ffn' 'folder with .ffn files'
DEFINE_string 'hmmfile' '/home/eden/data/model.hmm' 'folder with input hmm files (one hmm for each family)'
DEFINE_string 'output' '/home/eden/data/ko' 'output folder'
DEFINE_string 'gfam' '/home/eden/data/groups_created.txt' 'path to gfam table that will be created'
DEFINE_string 'cpu' '4' 'number of cpus for parallel processing'
DEFINE_string 'model' '~/Downloads/MetaGeneMark_linux_64/mgm/MetaGeneMark_v1.mod' 'path to MetaGeneMark model file'
DEFINE_string 'log' '/home/eden/log.txt' 'path to log file'

LOG_FILE="/home/eden/data/eden.log"

# parse the command-line
FLAGS "$@" || exit $?
if [ $# == 0 ] ; then
    flags_help
    exit 1;
fi
eval set -- "${FLAGS_ARGV}"

# Only after this point should you enable `set -e` as
# shflags does not work when that is turned on first.
set -e


# just a test

# this function outputs .ko files with hmm hit informations
searchGfam()
{
    local filename=$(basename "$1")
    local basename="${filename%.*}"
    echo "annotating $basename" 
    echo "annotating $basename" >> ${FLAGS_log}
    hmmsearch -o $2/$basename.txt --domtblout $2/$basename.domtbl -E 1.0e-2 $3 $1
    # remove redundant lines and remove hits they do not overlap in 40% 
    grep -v '^#' $2/$basename.domtbl | awk '{print $1,$3,$4,$6,$13,$16,$17,$18,$19}' | sed 's/ /\t/g' | \
    sort -k 3,3 -k 8n -k 9n | \
    perl -e 'while(<>){chomp;@a=split;next if $a[-1]==$a[-2];push(@{$b{$a[2]}},$_);}foreach(sort keys %b){@a=@{$b{$_}};for($i=0;$i<$#a;$i++){@b=split(/\t/,$a[$i]);@c=split(/\t/,$a[$i+1]);$len1=$b[-1]-$b[-2];$len2=$c[-1]-$c[-2];$len3=$b[-1]-$c[-2];if($len3>0 and ($len3/$len1>0.5 or $len3/$len2>0.5)){if($b[4]<$c[4]){splice(@a,$i+1,1);}else{splice(@a,$i,1);}$i=$i-1;}}foreach(@a){print $_."\n";}}' | \
    perl -e 'while(<>){chomp;@a=split(/\t/,$_);if(($a[-1]-$a[-2])>80){print $_,"\t",($a[-3]-$a[-4])/$a[1],"\n" if $a[4]<=1e-5;}else{print $_,"\t",($a[-3]-$a[-4])/$a[1],"\n" if $a[4]<=1e-3;}}'\
     | awk '$NF>0.4' | sort -k 3 -k 8,9g | awk '{print $1 "\t" $3}'> $2/$basename.ko
    #todo(pmuench) check if $2/$basename.ko is valid
}

# this function download the TIGRFAM (v.15) database from the ftp servers and convert it to one hmm files
downloadModel()
{
    mkdir -p /home/eden/data/annotation/ 2>/dev/null || { err "Cannot create folder! Aborting."; exit; }
    mkdir -p /home/eden/data/annotation/hmm 2>/dev/null
    wget ftp://ftp.jcvi.org/pub/data/TIGRFAMs/TIGRFAMs_15.0_HMM.tar.gz -O /home/eden/data/annotation/tigrfam.tar.gz >/dev/null 2>&1
    wget ftp://ftp.jcvi.org/pub/data/TIGRFAMs/TIGRFAMS_ROLE_LINK -O /home/eden/data/annotation/TIGRFAMS_ROLE_LINK >/dev/null 2>&1
    wget ftp://ftp.jcvi.org/pub/data/TIGRFAMs/TIGR_ROLE_NAMES -O /home/eden/data/annotation/TIGR_ROLE_NAMES >/dev/null 2>&1
    # unpack files and create a signle hmm file
    gunzip /home/eden/data/annotation/tigrfam.tar.gz || err "Failed to gunzip files. Aborting."
    tar xf /home/eden/data/annotation/tigrfam.tar -C /home/eden/data/annotation/hmm >/dev/null 2>&1 || err "Failed to unpack files. Aborting."
    cat /home/eden/data/annotation/hmm/*.HMM > /home/eden/data/model.hmm || err "Cannot merge HMM files"
    rm -rf /home/eden/data/annotation/hmm & rm /home/eden/data/annotation/tigrfam.tar || true
}

# this function will call the hmmsearch parallized
startAnnotation()
{
  # rm -rf ${FLAGS_output} || true
    mkdir -p ${FLAGS_output} 2>/dev/null || { err "Cannot create folder! Aborting."; exit; }
    log "ls ${FLAGS_faa_folder}/*.faa | parallel --no-notice --bar --files searchGfam {} ${FLAGS_output} ${FLAGS_hmmfile}"
    ls ${FLAGS_faa_folder}/*.faa | parallel --no-notice --bar --files searchGfam {} ${FLAGS_output} ${FLAGS_hmmfile}
}

# this function generates a gfam table which can be used as input for metaselection pipeline
generateTable()
{
    rm -f ${FLAGS_gfam} || true
    cat ${FLAGS_output}/*.ko | awk -F '\t' '{print $2}' |\
     sort | uniq | tail -n +2 > /tmp/all_terms.tmp
    while read ko; do
        echo "$ko:" $(grep "$ko" ${FLAGS_output}/*.ko |\
         awk -F '\t' '{print $1}' |\
         awk -F ':' '{print $2}' |\
          tr "\n" " ") >> ${FLAGS_gfam}
    done </tmp/all_terms.tmp
    rm -rf /tmp/all_terms.tmp || true
    rm -rf ${FLAGS_output} || true
}

# check the provided grouping table and removes singeltons (gene families with just one instance)
checkGroupingTable()
{
    local tmpfile=$(mktemp /tmp/singeltons.XXXXXX)
    grep -n -o "|" ${FLAGS_gfam} | sort -n | uniq -c | cut -d : -f 1 |\
     grep "      1 " | awk '{print $2}' > "$tmpfile"
    if [ -s "$tmpfile" ]; then
        echo "Singeltons in grouping table found. Removing..."
        mv ${FLAGS_gfam} ${FLAGS_gfam}.original
        awk 'FNR == NR { h[$1]; next } !(FNR in h)' "$tmpfile" ${FLAGS_gfam}.original > ${FLAGS_gfam}
    else
        echo "${FLAGS_gfam} checked. No singeltons found."
    fi
    if [ `wc -l ${FLAGS_gfam} | awk '{print $1}'` -ge "0" ]; then
        echo "Grouping table looks fine"
    else
        err "Grouping table looks empty! Aborting."
    fi
    rm -f "$tmpfile" || true
}

runProdigal(){
    echo "run prodigal"
    mkdir -p ${FLAGS_ffn_folder} 2>/dev/null || { err "cannot create ffn folder! Aborting."; exit; }
    mkdir -p ${FLAGS_faa_folder} 2>/dev/null || { err "cannot create faa folder! Aborting."; exit; }
    for file in ${FLAGS_fasta_folder}/*.fasta; do
        name=$(basename "$file" .fasta)
        /opt/bin/prodigal -i $file -a ${FLAGS_faa_folder}/$name.faa -d ${FLAGS_ffn_folder}/$name.ffn -o /tmp/$name.prodigal >/dev/null 2>&1 || { err "Failed to run prodigal. Aborting."; exit; }
    done
#    rm -rf /tmp/*
}

runProkka(){
    echo "setup prokka database"
    mkdir -p ${FLAGS_ffn_folder} 2>/dev/null || { err "Cannot create folder! Aborting."; exit; }
    mkdir -p ${FLAGS_faa_folder} 2>/dev/null || { err "Cannot create folder! Aborting."; exit; }
    /home/eden/prokka/bin/prokka --setupdb --quiet >/dev/null 2>&1 || { err "Cannot setup prokka database"; exit; }
    for file in ${FLAGS_fasta_folder}/*.fasta; do
	   name=$(basename "$file" .fasta)
	   echo "Processing $name"
     /home/eden/prokka/bin/prokka $file --centre eden --compliant --quiet --cpus ${FLAGS_cpu} --prefix $name --outdir /tmp --force >/dev/null 2>&1 || err "Failed to run prokka. Aborting."
    done
#    rm -rf /tmp/*
}

runMetaGenemark(){
    mkdir -p ${FLAGS_ffn_folder} 2>/dev/null || { err "Cannot create folder! Aborting."; exit; }
    mkdir -p ${FLAGS_faa_folder} 2>/dev/null || { err "Cannot create folder! Aborting."; exit; }
    for file in ${FLAGS_fasta_folder}/*.fasta; do
        name=$(basename "$file" .fasta)
        echo "Processing $name"
        gmhmmp -m ${FLAGS_model} -A /tmp/$name.faa -D /tmp/name.ffn $file >/dev/null 2>&1 || err "Failed to run MetaGeneMark. Aborting."
    done
   # rm -rf /tmp/*
}

rewriteHeader(){
    for file in ${FLAGS_ffn_folder}/*.ffn; do
    name=$(basename "$file" .ffn)
        # rewrite fasta header
        mv ${FLAGS_faa_folder}/$name.faa /tmp/$name.faa 
        mv ${FLAGS_ffn_folder}/$name.ffn /tmp/$name.ffn
        awk '/^>/{print ">'"$name"'|'"$name"'.peg." ++i; next}{print}' < /tmp/$name.faa | sed  '/^$/d' > ${FLAGS_faa_folder}/$name.faa || { err "Cannot rewrite fasta headers. Aborting."; exit; }
        awk '/^>/{print ">'"$name"'|'"$name"'.peg." ++i; next}{print}' < /tmp/$name.ffn | sed  '/^$/d' > ${FLAGS_ffn_folder}/$name.ffn || { err "Cannot rewrite fasta headers. Aborting."; exit; }
  #      rm -rf /tmp/*
    done
}

main()
{
    export -f searchGfam
    # check for ORF

    count=`ls -1 ${FLAGS_ffn_folder}/*.ffn 2>/dev/null | wc -l` # check if ORF files are there
    if [ $count != 0 ]; then
 	shinylog "check files"
    else     
        shinylog "run prodigal"
        runProdigal
    fi

    if [ -d "/home/eden/data/faa" ]; then
        # run the annotation and generate the gfam table
        if [ ! -f /home/eden/data/model.hmm ]; then
            shinylog "download HMM model"
            downloadModel
        fi
        # run annotation if no groups.txt is provided
        if [ ! -f /home/eden/data/groups.txt ]; then

        rewriteHeader \
          && shinylog "rewrite fasta headers" \
          || shinyerror "error on rewriting fasta headers"
    
        startAnnotation \
          && shinylog "annotate ORFs" \
          || shinyerror "error on annotate ORFs"
            
        generateTable \
          && shinylog "generate ORF table" \
          || shinyerror "error on generate ORF table"    
        fi

        checkGroupingTable \
          && shinylog "checking grouping table" \
          || shinyerror "error on checking grouping table"
    else
	shinyerror "error"
    fi

}
main "$@"
