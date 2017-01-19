#!/bin/sh

# make sure the directory for individual app logs exists
#mkdir -p /var/log/shiny-server
#chown root:root /var/log/shiny-server

rm -f /home/eden/shinylog.txt
touch /home/eden/shinylog.txt
echo ";; start shiny server" > /home/eden/shinylog.txt
exec shiny-server > /var/log/shiny-server.log 2>&1
