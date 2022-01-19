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
    nvm install node  &&  nvm install $nodejsVersion  &&  nvm use $nodejsVersion

    echo -e "\n" 
    echo -e "${bold_Green}* Nodejs installed successfully${NC}"
    node --version
    echo 
    echo "-----------------------------------------------"
}

installNodejs


##########################################################
#                    GO Installation
##########################################################

function installGo()
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing NVM and Nodejs${NC}"
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
        
        checkGoInstalled    # check if 'go' command works

        # if trys for installing 'go' failed
        if [ "$isGoInstalled" == "false" ]
        then
            echo -e "${Red}Failed to install go (go command does NOT work). Try it yourself!${NC}"
            exit
        fi
    
    # if 'go' directory is avaialble in /usr/local/
    else
        goExports           # 'export's for 'go'
        checkGoInstalled    # check if 'go' command works

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

installGo

# check if 'GO' is installed by 'go version' command
function checkGoInstalled()
{
    isInstalled=$(echo $(go version) | grep "version")

    # check if 'GO' is previously installed
    if [ "$isInstalled" != "" ]
    then
        isGoInstalled=true
    fi
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
#                       General Tools
##########################################################

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
}

logInstalledPacksVersions