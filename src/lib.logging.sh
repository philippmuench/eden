#!/bin/bash

#================================================
# Purpose: write log file to "$LOG_FILE"
# Arguments:
#   $1 -> String to log
#================================================

function log()
{
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi
    echo -e "[`date +"%Y/%m/%d:%H:%M:%S %z"`] [$TAG] $@"
    echo -e "[`date +"%Y/%m/%d:%H:%M:%S %z"`] [$TAG] $@" >> "$LOG_FILE" 
}


function shinylog()
{
  
    echo ";;$@" >> /home/eden/shinylog.txt
}
#================================================
# Purpose: write log file for shiny app
# Arguments:
#   $1 -> String to log
#================================================

function log2shiny()
{
    echo "[`date +"%Y/%m/%d:%H:%M:%S %z"`] [$TAG] $@" >> $LOG_SHINY
}

#================================================
# Purpose: write warning and go on
# Arguments:
#   $1 -> String to print on screen
#================================================

function echowarning()
{
    COLOR='\033[1;31m'
    NC='\033[0m'
    printf "${COLOR}[ERROR] $1${NC}\n"
}

#================================================
# Purpose: write in color 
# Arguments:
#   $1 -> String to print on screen in color
#================================================

function echocolor()
{
    COLOR='\033[1;33m'
    NC='\033[0m'
    printf "${COLOR}$1${NC}\n"
}

#================================================
# Purpose: write usage message
# Arguments:
#   none
#================================================

flags_help()
{
    echo "Usuage:"
}

#================================================
# Purpose: write error and exit
# Arguments:
#   $1 -> String to print on screen
#================================================

err()
{
    echo "${0##*/}: error: $*" >&2
    exit 1
}
