#!/bin/bash
# entrypoint for shiny, this script will run check.sh and eden.sh

set -e
LOCK_FILE=/home/eden/lock.txt

# source logging functions
. /home/eden/src/lib.logging.sh \
  || shinyerror "cannot find src/lib.logging.sh, error code 98"

function clean_up {
  mv data/tar_tmp/* data/tar/
  shinylog "moving files" \
  rm -f $LOCK_FILE
  exit
}

# remove lock file if something goes wrong
trap clean_up SIGHUP SIGINT SIGTERM

# generate lock file, this will be processed by shiny to show that the process in running
touch $LOCK_FILE \
  && shinylog "start process" \
|| shinyerror "cannot create lock file, error code 99"

# run check procedure
shinylog "running check.sh"
echo "/home/eden/check.sh --faa_folder $1 --ffn_folder $2 --cpu $3 --hmmfile $6 --output /home/eden/data/ko --gfam /home/eden/data/groups.txt"

/home/eden/check.sh --faa_folder $1 \
  --ffn_folder $2 \
  --cpu $3 \
  --hmmfile $6 \
  --output /home/eden/data/ko \
  --gfam /home/eden/data/groups.txt \
  && shinylog "check finished" \
  || shinyerror "cannot start check procedure, error code: 100"

# run eden
if [ -z "$7" ] && [ "$checkpassed" = true ]; then
  shinylog "running eden.sh"
  /home/eden/eden.sh --docker \
  --cpu_number $3 \
  --gap_threshold $5 \
  --name $4 \
  && shinylog "eden finished" \
  && edenpassed=true \
  || shinyerror "canont run eden.sh"
else
  shinylog "running eden.sh"
  /home/eden/eden.sh --docker\
  --cpu_number $3 \
  --gap_threshold $5 \
  --name $4 \
  --sample_list $7
  edenpassed=true
  shinylog "movind data"
  mv /home/eden/data/tar_tmp/* /home/eden/data/tar
  shinylog "finished"
  rm -f $LOCK_FILE
fi || shinyerror "cannot execute eden.sh, error code 101"

# remove lock file if eden completed
#if [ "$edenpassed" = true ]; then
#  rm -f $LOCK_FILE
#  shinylog "finished"
#fi

