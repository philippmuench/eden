#!/bin/bash
# this script gets executed when the "start check" button is pressed on the eden shiny app
# example usuage:
# /home/eden/start_check.sh /home/eden/data/faa /home/eden/data/ffn 4 example_run_1 0.7 /home/eden/data/model.hmm

. /home/eden/src/lib.logging.sh

# /home/eden/check.sh --faa_folder /home/eden/data/faa --ffn_folder /home/eden/data/ffn --cpu 2 --hmmfile /home/eden/data/model.hmm --output /home/eden/data/ko --gfam /home/eden/data/groups.txt

#  /home/eden/eden.sh --docker --cpu_number 3 --gap_threshold 0.8 --name bla
touch /home/eden/lock.txt # create lock file

shinylog "start check"

/home/eden/check.sh --faa_folder $1 --ffn_folder $2 --cpu $3 --hmmfile $6 --output /home/eden/data/ko --gfam /home/eden/data/groups.txt
shinylog "run prodigal" "check passed"

if [ -z "$7" ]; then
  shinylog "start pooled analysis"
  /home/eden/eden.sh --docker --cpu_number $3 --gap_threshold $5 --name $4
else
  shinylog "start pooled analysis"
  /home/eden/eden.sh --docker --cpu_number $3 --gap_threshold $5 --name $4 --sample_list $7
fi

# remove lock file
rm -rf /home/eden/lock.txt
shinylog "finished"

