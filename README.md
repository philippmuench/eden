# EDEN - Evolutionary Dynamics within Environments

EDEN is the first software for the rapid detection of protein families and regions under positive selection, as well as their associated biological processes, from meta- and pangenome data. It provides an interactive result visualization for detailed comparative analyses.
 
## Table of Contents  
[Quick start](#quick-start)  
[Extended installation guide](#extended-installation-guide)  
[Demo](#demo)  
[Development](#development)  
[FAQ](#faq)  

## Quick start
1. make sure you have installed [Docker](https://github.com/docker/docker) or install it via `sudo apt-get install docker.io`
2. make sure you have a up to date version of [Google Chrome](https://www.google.de/chrome/browser/desktop/) or [Mozilla Firefox](https://www.mozilla.org/de/firefox/new/)
3. download/start EDEN by typing `sudo docker run -p 80:3838 philippmuench/eden`
4. open your webbrowser and point it to [localhost](localhost), you should see the welcome screen
5. download [sample input files](https://github.com/philippmuench/eden/tree/master/sample_files) to test EDEN

## Extended installation guide
### Windows
1. see the tutorial https://docs.docker.com/docker-for-windows/ for installation and setting up docker on your windows machine
2. Press **WinKey + R**, Input `cmd` and press enter to start the **cmd.exe** to open the command promt
3. Type in the following command to download/start the docker image `sudo docker run -p 80:3838 edensoftware/eden` 
4. point your webbrowser to [localhost](localhost), you should see the welcome screen

### Amazon AWS (via Windows/Linux/macOS)
1. see https://aws.amazon.com/de/ec2/ and create an account and log in
2. go to **Dahsboard** and click on **Launch Instance** and select **Ubuntu Server 14.4 LTS**
3. choose the size of of server you want to rent, **t2.micro** is maybe free for some users
4. click on **Next:Configure Instance Details** and click on **Next: Add Storage**. On the **Size (GiB)** box add 20GB. Click on **Next Add Tags** and **Next: Configure Security Groups**. Click on **Add Rule** and add a **Custom TCP Rule (TCP)** with port range: `80` and select **Source: Anywhere**. Click on **Review and Launch** and **Launch**
5. create a new key pair, and download this file to your local machine
6. click **View Instance** and wait till the **Instance State** goes from **pending/initializing** to **running**
7. click on "Launch Instance" and select **A Java SSH Client directly from my browser (Java required)** add add the path to the .pem file you downloaded in step 5. 
10. On the terminal screen execute the command: `sudo apt-get install docker.io && sudo docker run -p 80:3838 edensoftware/eden`
11. point your browser to the **Public DNS** or **Public IP** of your instance (i.e. `ec2-54-90-153-208.compute-1.amazonaws.com`)(under the **Description** Tab in the **Instance** Page in the aws administration panel)


## File Format Specification 
EDEN takes as input either fasta files of open reading frames (ORFs) in FASTA format with the file ending `.faa` for amino acid and and `.ffn` for nucleotide sequences or FASTA file of contigs/scaffold with the file edning  `.fasta`.  See /sample_files/fasta for example.

You can also provide one Amino Hidden Markov Models (HMM) file (which can contain may HMM models). See /sample_files/gene_families.hmm for example file. You can generate these files based on multiple sequence alignment of amino acid sequnces of the protein familiy of interest or download precomputed HMM e.g. from TIGRFAM database.

## Demo

[see live demo](http://eden.bifo.helmholtz-hzi.de/)

## FAQ

> What is the minimum fold-coverage of a given gene family below which meaningful analysis is not possible?  

EDEN reaches comparable results to HyPhy SLAC for gene families with 3 or more sequences in their alignment. If less than two sequences are found, the gene family will not be processed in EDEN.

> How many files, and at what file sizes, can the pipeline handle?  

From the software side, there is no limit for the number of analyzed samples per run. For large datasets of more than 25 metagenome samples we recommend using EDEN on a cloud service such as Amazon AWS (installation guide is available at https://github.com/hzi-bifo/eden)

> How does computation time scale with number of nucleotides submitted?  

The runtime is linear with the number of sequences in the alignment for the gene families and the number of HMM models. Please note, that this pipeline needs to be executed on the user's machine or on a cloud (such as Amazon EC2 instances) and currently we not offer computational resources for this software and the link in the manuscripts are currently for providing example output to the reader. We describe the installation process for Amazon AWS, one of the most used cloud services at [Extended installation guide](#Extended-installation-guide). Based on this, the runtime of the pipeline is only limited to the users server capability which can be nearly unlimited in case of Amazon EC2 machines. 

> How much memory is required? 

We used google cAdvisor to analyze resource usage and performance characteristics of EDEN on example datasets. On startup and visualization of precomputed 66 HMP and BMI samples, which are described in the manuscript, a peak RAM usage of 2.05 GB and a maximum of 4.3 GB disk usage was observed. When processing 20 metagenomic samples (HMP project, ~54.000 contigs) we observed a peak RAM usage of 4.15 GB and disk usage of 5.25 GB.

> Is it meaningful to apply the pipeline to microbial communities of low complexity (perhaps dominated by a few abundant pathogens)?  

EDEN can also be applied to dataset of samples with limited diversity e.g. by domination of single population but the $d_N/d_S$ values should be interpreted with caution. (see https://doi.org/10.1371/journal.pgen.1000304)

> Should one upload raw sequencing reads or (partially) assembled sequences?If one is preferred, why?  

We recommend to use assembled input files instead of raw short reads because the thresholds used for HMMER are optimized for sequences that span most of the input HMM, which is usually not the case for short reads.

## Development
### Rebuild docker image 

you can build the docker image from scratch:

```
git clone https://github.com/philippmuench/eden.git
cd eden
sudo docker build -t eden_local .
sudo docker run -p 80:3838 eden_local
# point browser to localhost
```

during the build process the GUI will be installed from https://github.com/philippmuench/eden_ui
if you want to make changes on the UI, you need to clone this repo and change the path to it in the `Dockerfile`
