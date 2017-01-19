# eden
dependencies: 
- [Docker](https://github.com/docker/docker)
- up to date version of [Google Chrome](https://www.google.de/chrome/browser/desktop/) or [Mozilla Firefox](https://www.mozilla.org/de/firefox/new/)

# how to start docker
## install linux & macOS
1. make sure you have installed docker or install it via `sudo apt-get install docker.io`
2. download/start the docker image `sudo docker run -p 80:3838 edensoftware/eden` (version with example files) you may want to use the smaller docker image without example files `sudo docker run -p 80:3838 edensoftware/eden:minimal` 
4. open your webbrowser and point it to [localhost](localhost), you should see the welcome screen

## install eden on windows
1. see the tutorial https://docs.docker.com/docker-for-windows/ for installation and setting up docker on your windows machine
2. Press **WinKey + R**, Input `cmd` and press enter to start the **cmd.exe** to open the command promt
3. Type in the following command to download/start the docker image `sudo docker run -p 80:3838 edensoftware/eden` 
4. point your webbrowser to [localhost](localhost), you should see the welcome screen

## install eden in the cloud (via amazon aws) (windows/linux/macOS)
1. see https://aws.amazon.com/de/ec2/ and create an account and log in
2. go to **Dahsboard** and click on **Launch Instance** and select **Ubuntu Server 14.4 LTS**
3. choose the size of of server you want to rent, **t2.micro** is maybe free for some users
4. click on **Next:Configure Instance Details** and click on **Next: Add Storage**. On the **Size (GiB)** box add 20GB. Click on **Next Add Tags** and **Next: Configure Security Groups**. Click on **Add Rule** and add a **Custom TCP Rule (TCP)** with port range: `80` and select **Source: Anywhere**. Click on **Review and Launch** and **Launch**
5. create a new key pair, and download this file to your local machine
6. click **View Instance** and wait till the **Instance State** goes from **pending/initializing** to **running**
7. click on "Launch Instance" and select **A Java SSH Client directly from my browser (Java required)** add add the path to the .pem file you downloaded in step 5. 
10. On the terminal screen execute the command: `sudo apt-get install docker.io && sudo docker run -p 80:3838 edensoftware/eden`
11. point your browser to the **Public DNS** or **Public IP** of your instance (i.e. `ec2-54-90-153-208.compute-1.amazonaws.com`)(under the **Description** Tab in the **Instance** Page in the aws administration panel)

# how to use docker
## submit a new job
![submit a new job](start.gif "submit a new job")

## visualize results
![visualize results](samples.gif "visualize results")

# develop
## build your own docker image

you can create the docker image from scratch:

```
git clone https://github.com/naturesubmission/eden.git
cd eden
sudo docker build eden_local .
sudo docker run -p 80:3838 eden_local
# point browser to localhost
```

