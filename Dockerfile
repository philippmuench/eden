#FROM textlab/ubuntu-essential
FROM ubuntu:trusty

MAINTAINER pmuench

# java
RUN apt-get update \
  && apt-get install -y \
  openjdk-7-jdk \
  && rm -rf /var/lib/apt/lists/*


#RUN echo "deb http://archive.ubuntu.com/ubuntu vivid main universe\n" > /etc/apt/sources.list &&\
#  echo "deb http://archive.ubuntu.com/ubuntu vivid-updates main universe\n" >> /etc/apt/sources.list &&\
RUN apt-get update -qqy &&\ 
  apt-get -qqy --no-install-recommends install software-properties-common &&\
  add-apt-repository -y ppa:git-core/ppa

#========================================
# Miscellaneous packages
#========================================

RUN sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list'
RUN gpg --keyserver keyserver.ubuntu.com --recv-key E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN gpg -a --export E298A3A825C0D65DFD57CBB651716619E084DAB9 | sudo apt-key add -

# install software
RUN  apt-get -qq update && \
  apt-get install -qq -y --force-yes \
  wget \
  r-recommended \
  unzip \
  nasm \
  procps \
  libstdc++6 \
  libssl-dev \
  git \
  parallel \
  openjdk-7-jre \
  nano \
  r-base \
  r-base-dev \
  gdebi-core \
  libcurl4-gnutls-dev \
  perl \
  bioperl \
  cpanminus \
  && rm -rf /var/lib/apt/lists/*

#========================================
# Setup shiny server
#========================================

# fix shiny-server issues
RUN sudo update-locale 
RUN sudo add-apt-repository ppa:ubuntu-toolchain-r/test
RUN sudo apt-get -qq update
RUN sudo apt-get install -qq -y --force-yes g++-4.9 

RUN wget --no-verbose https://s3.amazonaws.com/rstudio-shiny-server-os-build/ubuntu-12.04/x86_64/VERSION -O "version.txt" && \
  VERSION=$(cat version.txt)  && \
  wget --no-verbose "https://s3.amazonaws.com/rstudio-shiny-server-os-build/ubuntu-12.04/x86_64/shiny-server-$VERSION-amd64.deb" -O ss-latest.deb && \
  gdebi -n ss-latest.deb && \
  rm -f version.txt ss-latest.deb


RUN mkdir -p /opt/bin \
  /home/eden \
  /srv/shiny-server/ \
  /srv/shiny-server/eden-visualizer &&\
  chmod -R 777 /home/eden /tmp


ADD src /home/eden/src
COPY entrypoint.sh /home/eden/entrypoint.sh
COPY eden.sh /home/eden/eden.sh
COPY check.sh /home/eden/check.sh
COPY start_check.sh /home/eden/start_check.sh
COPY start_server.sh /home/eden/start_server.sh

RUN wget https://raw.githubusercontent.com/philippmuench/eden_ui/master/packrat/bundles/eden_ui-fisher.tar.gz -O /srv/shiny-server/bundle.tar.gz &&\
 tar -xvzf /srv/shiny-server/bundle.tar.gz --directory=/srv/shiny-server/ && rm -f /srv/shiny-server/bundle.tar.gz &&\
 chmod -R 777 /srv/shiny-server/eden_ui &&\
 chown -R root:root /srv/shiny-server

# remove example apps
RUN rm -rf /srv/shiny-server/sample-apps /srv/shiny-server/index.html

# add index.html file
COPY src/index.html /srv/shiny-server/index.html
COPY src/bootstrap.css /srv/shiny-server/bootstrap.css
COPY src/bootstrap.min.css /srv/shiny-server/bootstrap.min.css
COPY src/logo2.png /srv/shiny-server/logo2.png

RUN R -e 'setwd("/srv/shiny-server/eden_ui"); install.packages("packrat" , repos="http://cran.us.r-project.org"); packrat::restore()'

RUN git clone https://github.com/nvie/shFlags.git &&\
  cp shFlags/src/shflags /opt/bin/shflags &&\
  rm -R shFlags
RUN chmod a+x /opt/bin/shflags


RUN wget http://www.drive5.com/muscle/downloads3.8.31/muscle3.8.31_i86linux64.tar.gz && \
  tar -xvzf muscle3.8.31_i86linux64.tar.gz &&\
  rm muscle3.8.31_i86linux64.tar.gz &&\
  mv muscle3.8.31_i86linux64 /opt/bin/muscle
RUN chmod a+x /opt/bin/muscle


RUN wget http://www.bork.embl.de/pal2nal/distribution/pal2nal.v14.tar.gz &&\
  tar -xvzf pal2nal.v14.tar.gz &&\
  rm pal2nal.v14.tar.gz && mv pal2nal.v14/pal2nal.pl /opt/bin/pal2nal.pl &&\
  rm -R pal2nal.v14
RUN chmod a+x /opt/bin/pal2nal.pl


RUN git clone https://github.com/philippmuench/cleargap.git && \
  cp cleargap/cleargap /opt/bin/clearcut &&\
  chmod a+x /opt/bin/clearcut &&\
  rm -R cleargap


RUN wget https://github.com/hyattpd/Prodigal/releases/download/v2.6.3/prodigal.linux &&\
  chmod +x prodigal.linux &&\
  mv prodigal.linux /opt/bin/prodigal

# install tbl2ans
RUN wget ftp://ftp.ncbi.nih.gov/toolbox/ncbi_tools/converters/by_program/tbl2asn/linux64.tbl2asn.gz &&\
  gunzip linux64.tbl2asn &&\
  chmod +x linux64.tbl2asn &&\
  rm -f linux64.tbl2asn.gz &&\
  mv linux64.tbl2asn /opt/bin/tbl2asn


RUN wget http://eddylab.org/software/hmmer3/3.1b2/hmmer-3.1b2-linux-intel-x86_64.tar.gz &&\
  tar -xvzf hmmer-3.1b2-linux-intel-x86_64.tar.gz &&\
  mv hmmer-3.1b2-linux-intel-x86_64/binaries/* /opt/bin &&\
  rm -rf hmmer-3.1b2-linux-intel-x86_64 hmmer-3.1b2-linux-intel-x86_64.tar.gz


#========================================
# download tigrfam annotation
#========================================
RUN mkdir /home/eden/tigr_data &&\
  wget ftp://ftp.jcvi.org/pub/data/TIGRFAMs/TIGRFAMS_ROLE_LINK -O /home/eden/tigr_data/TIGRFAMS_ROLE_LINK &&\
  wget ftp://ftp.jcvi.org/pub/data/TIGRFAMs/TIGR_ROLE_NAMES -O /home/eden/tigr_data/TIGR_ROLE_NAMES

#========================================
# get example files
#========================================
RUN mkdir -p /home/eden/data/tar &&\
  wget https://www.dropbox.com/s/gya4azznu7ubx3j/oligo.tar?dl=1 -O /home/eden/data/tar/oligo.tar
RUN wget https://www.dropbox.com/s/w6ea9es1qquwp51/bmi.tar?dl=1 -O /home/eden/data/tar/bmi.tar
RUN wget https://www.dropbox.com/s/lwn9w5x3mtoty0r/bodysites.tar?dl=1 -O /home/eden/data/tar/bodysites.tar

# set paths
ENV PATH /opt/bin:$PATH
WORKDIR /home/eden

# create dirs
RUN mkdir -p /home/eden/data/faa /home/eden/data/ffn /home/eden/data/csv /home/eden/data/raw

RUN chmod 777 -R /usr/local/lib/R/site-library

# port for shiny-server
EXPOSE 3838

# create new user and change file ownership
RUN groupadd -r eden && useradd -r -g eden eden &&\
  chown -R eden:eden /var/log /var/lib /srv/shiny-server /home/eden
RUN sed -i '2s/.*/run_as eden;/' /etc/shiny-server/shiny-server.conf
RUN chmod 777 /etc/shiny-server/shiny-server.conf
RUN sed -i '12s/.*/  site_dir \/srv\/shiny-server\/eden_ui\/;/' /etc/shiny-server/shiny-server.conf
USER eden

# start pipeline
ENTRYPOINT ["/bin/bash","/home/eden/start_server.sh"]
