FROM textlab/ubuntu-essential

MAINTAINER pmuench

#========================================
# Customize sources for apt-get 
#========================================

RUN echo "deb http://archive.ubuntu.com/ubuntu vivid main universe\n" > /etc/apt/sources.list &&\
  echo "deb http://archive.ubuntu.com/ubuntu vivid-updates main universe\n" >> /etc/apt/sources.list &&\
  apt-get update -qqy &&\ 
  apt-get -qqy --no-install-recommends install software-properties-common &&\
add-apt-repository -y ppa:git-core/ppa

#========================================
# Miscellaneous packages
#========================================

# install software
RUN  apt-get -qq update && \
 apt-get install -qq -y --force-yes \
  wget \
  r-recommended \
  unzip \
  nasm \
  procps \
  libssl-dev \
  git \
  parallel \
  openjdk-7-jre \
  nano \
  r-base \
  gdebi-core \
  libcurl4-gnutls-dev \
  perl \
  bioperl \
  cpanminus \
  && rm -rf /var/lib/apt/lists/*

#========================================
# Setup shiny server
#========================================

RUN wget --no-verbose https://s3.amazonaws.com/rstudio-shiny-server-os-build/ubuntu-12.04/x86_64/VERSION -O "version.txt" && \
    VERSION=$(cat version.txt)  && \
    wget --no-verbose "https://s3.amazonaws.com/rstudio-shiny-server-os-build/ubuntu-12.04/x86_64/shiny-server-$VERSION-amd64.deb" -O ss-latest.deb && \
    gdebi -n ss-latest.deb && \
    rm -f version.txt ss-latest.deb

#========================================
# Create folders 
#========================================

RUN mkdir -p /opt/bin \
 /home/eden \
 /srv/shiny-server/ \
 /srv/shiny-server/eden-visualizer &&\
 chmod -R 777 /home/eden /tmp

#========================================
# Import files 
#========================================

ADD src /home/eden/src
COPY entrypoint.sh /home/eden/entrypoint.sh
COPY eden.sh /home/eden/eden.sh
COPY check.sh /home/eden/check.sh
COPY start_check.sh /home/eden/start_check.sh
COPY start_server.sh /home/eden/start_server.sh

#========================================
# Get Shiny App from github.com
#========================================

#RUN wget https://rawgit.com/naturesubmission/eden_visualizer/master/bundle.tar.gz -O /srv/#shiny-server/bundle.tar.gz &&\
# tar -xvzf /srv/shiny-server/bundle.tar.gz --directory=/srv/shiny-server/ && rm -f /srv/#shiny-server/bundle.tar.gz &&\
# chmod -R 777 /srv/shiny-server/eden-visualizer &&\
# chown -R root:root /srv/shiny-server 

RUN wget https://raw.githubusercontent.com/philippmuench/eden_ui/master/packrat/bundles/eden_ui.tar.gz -O /srv/shiny-server/bundle.tar.gz &&\
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

#========================================
# install R packages
#========================================

RUN R -e 'setwd("/srv/shiny-server/eden_ui"); install.packages("packrat" , repos="http://cran.us.r-project.org"); packrat::restore()'

#========================================
# shFlags
#========================================

RUN git clone https://github.com/nvie/shFlags.git &&\
  cp shFlags/src/shflags /opt/bin/shflags &&\
  rm -R shFlags
RUN chmod a+x /opt/bin/shflags

#========================================
# Muscle
#========================================

RUN wget http://www.drive5.com/muscle/downloads3.8.31/muscle3.8.31_i86linux64.tar.gz && \
  tar -xvzf muscle3.8.31_i86linux64.tar.gz &&\
  rm muscle3.8.31_i86linux64.tar.gz &&\
  mv muscle3.8.31_i86linux64 /opt/bin/muscle
RUN chmod a+x /opt/bin/muscle

#========================================
# pal2nal
#========================================

RUN wget http://www.bork.embl.de/pal2nal/distribution/pal2nal.v14.tar.gz &&\
  tar -xvzf pal2nal.v14.tar.gz &&\
  rm pal2nal.v14.tar.gz && mv pal2nal.v14/pal2nal.pl /opt/bin/pal2nal.pl &&\
  rm -R pal2nal.v14
RUN chmod a+x /opt/bin/pal2nal.pl

#========================================
# Clearcut
#========================================

RUN git clone https://github.com/philippmuench/cleargap.git && \
  cp cleargap/cleargap /opt/bin/clearcut &&\
  chmod a+x /opt/bin/clearcut &&\
  rm -R cleargap

# original implementation
#RUN git clone https://github.com/sheneman/clearcut.git &&\
#  make -C clearcut/ &&\
#  cp clearcut/clearcut /opt/bin/clearcut &&\
#  rm -R clearcut

#========================================
# Prokka
#========================================

# install perl modules
#RUN cpanm Time::Piece \
#  XML::Simple \
#  Bio::Perl \
#  Digest::MD5 \
#  && rm -rf .cpanm

#RUN git clone https://github.com/tseemann/prokka.git

#
# Prodigal
#
RUN wget https://github.com/hyattpd/Prodigal/releases/download/v2.6.3/prodigal.linux &&\
  chmod +x prodigal.linux &&\
  mv prodigal.linux /opt/bin/prodigal

# install tbl2ans
RUN wget ftp://ftp.ncbi.nih.gov/toolbox/ncbi_tools/converters/by_program/tbl2asn/linux64.tbl2asn.gz &&\
  gunzip linux64.tbl2asn &&\
  chmod +x linux64.tbl2asn &&\
  rm -f linux64.tbl2asn.gz &&\
  mv linux64.tbl2asn /opt/bin/tbl2asn

#========================================
# Hmmer
#========================================

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
  wget https://www.dropbox.com/s/xf86eaml6qauv3q/oligo.tar?dl=1 -O /home/eden/data/tar/oligo.tar
RUN wget https://www.dropbox.com/s/7usgqx72m4ndlf2/bmi.tar?dl=1 -O /home/eden/data/tar/bmi.tar
RUN wget https://www.dropbox.com/s/ww9ubr4dufh15r9/bodysites.tar?dl=1 -O /home/eden/data/tar/bodysites.tar
#========================================
# Entrypoint
#========================================

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
