#!/bin/bash

# export environment variables from .env file
export $(xargs < .env)

# # prevent from input dialogs
# DEBIAN_FRONTEND=noninteractive


##########################################################
#                install required tools
##########################################################

echo
echo "==============================================="
echo -e "${bold_Blue}           Installing required tools${NC}"
echo "==============================================="
echo

apt-get update && apt-get upgrade
apt-get install -y build-essential git-all make curl wget zip unzip g++ libtool libltdl-dev jq

echo -e "\n" 
echo -e "${bold_Green}* Required tools installed successfully${NC}"
echo "build-essential, git, make, curl, wget, zip, unzip, g++, libtool, libltdl-dev, jq"
echo "-----------------------------------------------"

    
##########################################################
#                   Nodejs Installation
##########################################################

# install NVM and Nodejs
function installNodejs() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}Installing NVM and Nodejs${NC}"
    echo "==============================================="
    echo

    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash 
    source ~/.profile   
    nvm install $nodejsVersion  &&  nvm use $nodejsVersion

    echo -e "\n" 
    echo -e "${bold_Green}* Nodejs installed successfully${NC}"
    node --version
    echo 
    echo "-----------------------------------------------"
}


##########################################################
#                    GO Installation
##########################################################

function installGo() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing GO Lang${NC}"
    echo "==============================================="
    echo

    isGoInstalled=false

    # if 'go' directory is NOT avaialble in /usr/local/
    if [ ! -d "$go_path" ] 
    then
        echo -e "${Yellow}go directory NOT found in path:${NC} ${go_path}"
        echo "Downloading go1.17.6"

        # download go
        wget $go_download_link

        # if download failed
        if [ $? != 0 ]
        then
            echo -e "${RED}Failed to download go. Check network connection or use a VPN${NC}"
            exit
        fi

        sudo tar -C /usr/local -xvzf $go_zip_file
        goExports   # 'export's for 'go'
        
        checkInstallation "go"   # check if 'go' command works
        if [ $? == "200"]; then isGoInstalled=true; fi

        # if trys for installing 'go' failed
        if [ "$isGoInstalled" == "false" ]
        then
            echo -e "${Red}Failed to install go (go command does NOT work). Try it yourself!${NC}"
            exit
        fi
    
    # if 'go' directory is avaialble in /usr/local/
    else
        goExports           # 'export's for 'go'
        checkInstallation "go"   # check if 'go' command works
        if [ $? == "200"]; then isGoInstalled=true; fi

        # if trys for installing 'go' failed
        if [ "$isGoInstalled" == "false" ]
        then
            echo -e "${Red}Failed to install go (go command does NOT work). Try it yourself!${NC}"
            exit
        fi
    fi

    echo -e "\n" 
    echo -e "${bold_Green}* GO installed successfully${NC}"
    go version
    echo 
    echo "-----------------------------------------------"
}


# some exports for 'go' to work
function goExports() 
{
    export GOROOT=$export_GOROOT
    export GOPATH=$export_GOPATH
    export PATH=$export_PATH

    echo -e "\n\n\nexport GOROOT=$GOROOT" >> ~/.bashrc
    echo "export GOPATH=$export_GOPATH" >> ~/.bashrc
    echo "PATH=$export_PATH" >> ~/.bashrc

    source ~/.bashrc
}


##########################################################
#                   Docker Installation
##########################################################

function checkDocker()
{
    isDockerInstalled=false

    checkInstallation "docker"   # check if 'docker' command works
    if [ $? == "200"]; then isDockerInstalled=true; fi

    #  install Docker Engine, if NOT installed
    if [ $isDockerInstalled == "false"]; then installDocker
    # if Docker is previously installed
    else
        dockerVersion=$(echo $(docker -v))
        currentDockerV=${dockerVersion:15:2}

        # compare installed Docker version with min-required version
        if [ $currentDockerV -ge $minRequiredDockerV ]
        then
            echo -e "\n" 
            echo -e "${bold_Green}* Pre-Installed Docker Engine is OK - v18 or greater is OK${NC}"
            docker -v
            echo 
            echo "-----------------------------------------------"
        else
            # remove docker (containers and volumes are NOT affected), and Install it again
            sudo apt-get purge -y docker-ce docker-ce-cli containerd.io
            installDocker
        fi
    fi

}


function installDocker() 
{
    sudo apt-get install ca-certificates gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    sudo apt-get install docker-ce docker-ce-cli containerd.io
    
    systemctl enable docker
    systemctl start docker
    sudo chmod 666 /var/run/docker.sock

    # exit installation if could NOT install Docker
    checkInstallation "docker"   # check if 'docker' command works
    if [ $? == "404"]
    then 
        echo "${RED}Could NOT install Docker Engine, Try it Yourself!${NC}"
        exit
    fi
}


##########################################################
#                       General Tools
##########################################################

# check if 'PACKAGE' is installed by 'PACKAGE version' command
function checkInstallation()
{
    isInstalled=$(echo $($1 version) | grep "version")

    # check if 'PACKAGE' is previously installed
    if [ "$isInstalled" != "" ]
    then
        return "200"    # Installed
    else
        return "404"    # Not Installed
    fi
}


# log the version of installed packages
function logInstalledPacksVersions() 
{
    echo -e "\n"

    echo -e "${bold_Blue}- Nodejs:${NC}"
    echo -e "${Green}    $(node --version)${NC}"

    echo -e "${bold_Blue}- GO:${NC}"
    echo -e "${Green}    $(go version)${NC}"

    echo -e "${bold_Blue}- Git:${NC}"
    echo -e "${Green}    $(git version)${NC}"

    echo -e "${bold_Blue}- Docker:${NC}"
    echo -e "${Green}    $(docker -v)${NC}"
}


##########################################################
#                      Run Functions
##########################################################

installNodejs
installGo
checkDocker
logInstalledPacksVersions