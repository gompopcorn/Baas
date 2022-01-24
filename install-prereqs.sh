#!/bin/bash -i

# export environment variables from .env file
export $(xargs < .env)


##########################################################
#                       Validate User
##########################################################

function checkUserPwd()
{
    # current user password
    userPwd=$(cat ./tmp.txt)

    # if NO password is provided
    if [ "$userPwd" == "" ]; then
        echo -e "${bold_Red}* User password MUST be provided as first argument.${NC}"
        echo -e "${bold_Red}Exiting...${NC}"
        exit
    fi

    # check correctness of the password
    echo $userPwd | sudo -S ls
    if [ $? != 0 ]; then
        echo -e "${bold_Red}* User password is INCORRECT.${NC}"
        echo -e "${bold_Red}Exiting...${NC}"
        exit
    fi

    # clear contents of the password file - (for security)
    > ./tmp.txt    
}


##########################################################
#                install required tools
##########################################################

function installTools()
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing required tools${NC}"
    echo "==============================================="
    echo

    # pipes user password for sudo commands
    echo $userPwd | sudo -S apt-get update
    sudo apt-get install -y build-essential git-all make curl wget zip unzip g++ libtool libltdl-dev jq

    # check if any package of the above failed to be installed
    if [ $? != 0 ]; then
        echo
        echo -e "${bold_Red}* Failed to install required tools.${NC}"
        exit
    fi


    echo -e "${bold_Green}* Required tools installed successfully${NC}"
    echo "build-essential, git, make, curl, wget, zip, unzip, g++, libtool, libltdl-dev, jq"
    echo
    echo -e "${bold_Cyan}____________________________________________________________${NC}"
}


##########################################################
#                   Nodejs Installation
##########################################################

# install NVM and Nodejs
function installNodejs() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing NVM and Nodejs${NC}"
    echo "==============================================="
    echo

    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash 

    source ~/.bashrc 
    
    nvm install $nodejsVersion  &&  nvm use $nodejsVersion


    if [ $? == 0 ]
    then
        echo -e 
        echo -e "${bold_Green}* Nodejs installed successfully${NC}"
        node --version
    else
        echo -e 
        echo -e "${bold_Red}* Failed to install Nodejs${NC}"
    fi

    echo 
    echo -e "${bold_Cyan}____________________________________________________________${NC}"
}


##########################################################
#                    GO Installation
##########################################################

function installGo() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}               Installing GO Lang${NC}"
    echo "==============================================="
    echo

    isGoInstalled=false

    # if 'go' directory is NOT avaialble in /usr/local/
    if [ ! -d "$go_installation_path" ] 
    then
        echo -e "${Yellow}go directory NOT found in path:${NC} ${go_installation_path}"
        echo "Downloading go1.17.6"

        # download go
        wget $go_download_link

        # if download failed
        if [ $? != 0 ]
        then
            echo -e "${RED}* Failed to download go. Check network connection or use a VPN${NC}"
            exit
        fi

        sudo tar -C /usr/local -xvzf $go_zip_file
        goExports   # 'export's for 'go'
        
        checkInstallation "go"   # check if 'go' command works
        if [ $? == "200" ]; then isGoInstalled=true; fi

        # if trys for installing 'go' failed
        if [ "$isGoInstalled" == "false" ]
        then
            echo -e "${Red}* Failed to install go (go command does NOT work). Try it yourself!${NC}"
            exit
        fi
    
    # if 'go' directory is avaialble in /usr/local/
    else
        goExports           # 'export's for 'go'
        checkInstallation "go"   # check if 'go' command works
        if [ $? == "200" ]; then isGoInstalled=true; fi

        # if trys for installing 'go' failed
        if [ "$isGoInstalled" == "false" ]
        then
            echo -e "${Red}* Failed to install go (go command does NOT work). Try it yourself!${NC}"
            exit
        fi
    fi

    echo -e 
    echo -e "${bold_Green}* GO installed successfully${NC}"
    go version
    echo 
    echo -e "${bold_Cyan}____________________________________________________________${NC}"
}


# some exports for 'go' to work
function goExports() 
{
    export GOPATH="/usr/local/bin"
    export PATH="$PATH:/usr/local/go/bin"

    echo -e "\n\n\nexport GOPATH=/usr/local/bin" >> ~/.bashrc
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc

    source ~/.bashrc
}


##########################################################
#                   Docker Installation
##########################################################

function checkDocker()
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing Docker Engine${NC}"
    echo "==============================================="
    echo
    
    isDockerInstalled=false

    checkInstallation "docker"   # check if 'docker' command works
    if [ $? == "200" ]; then isDockerInstalled=true; fi

    #  install Docker Engine, if NOT installed
    if [ $isDockerInstalled == "false" ]; then installDocker
    # if Docker is previously installed
    else
        dockerVersion=$(echo $(docker -v))
        currentDockerV=${dockerVersion:15:2}

        # compare installed Docker version with min-required version
        if [ $currentDockerV -ge $minRequiredDockerV ]
        then
            echo -e 
            echo -e "${bold_Green}* Pre-Installed Docker Engine is OK - v18 or greater is OK${NC}"
            docker -v
            echo 
            echo -e "${bold_Cyan}____________________________________________________________${NC}"
        else
            # remove docker (containers and volumes are NOT affected), and Install it again
            sudo apt-get remove docker docker-engine docker.io containerd runc
            installDocker
        fi
    fi

}


function installDocker() 
{
    echo
    echo -e "${Yellow}* Installing Docker Engine...${NC}"

    sudo apt-get update
    sudo apt-get install -y ca-certificates gnupg lsb-release
    sudo rm /usr/share/keyrings/docker-archive-keyring.gpg
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo chmod 666 /var/run/docker.sock

    # exit installation if could NOT install Docker
    checkInstallation "docker"   # check if 'docker' command works
    if [ $? == "404" ]
    then 
        echo "${RED}* Could NOT install Docker Engine, Try it Yourself!${NC}"
        exit
    else

        if [ $? == 0 ]
        then
            echo -e 
            echo -e "${bold_Green}* Docker Engine installed successfully.${NC}"
            docker -v
        else
            echo -e 
            echo -e "${bold_Red}* Failed to install Docker Engine${NC}"
        fi
        
        echo 
        echo -e "${bold_Cyan}____________________________________________________________${NC}"
    fi
}


##########################################################
#              Docker-Compose Installation
##########################################################

function installDockerCompose() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing Docker-Compose${NC}"
    echo "==============================================="
    echo

    # uninstall docker-compose
    sudo rm /usr/local/bin/docker-compose
    sudo rm /usr/local/bin/docker-compose /usr/bin/docker-compose

    # install docker-compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # exit installation if could NOT install Docker-Compose
    checkInstallation "docker-compose"   # check if 'docker' command works
    if [ $? == "404" ]
    then 
        echo "${RED}* Could NOT install Docker-Compose, Try it Yourself!${NC}"
        exit
    else
        echo -e 
        echo -e "${bold_Green}* Docker-Compose installed successfully.${NC}"
        docker-compose -v

        echo 
        echo -e "${bold_Cyan}____________________________________________________________${NC}"
    fi
}


##########################################################
#                       General Tools
##########################################################

# check if 'PACKAGE' is installed by 'PACKAGE version' command
function checkInstallation()
{
    $1 version

    # check if 'PACKAGE' is previously installed
    if [ $? != 0 ]
    then
        return "404"    # Not Installed
    else
        return "200"    # Installed
    fi
}


# log the version of installed packages
function logInstalledPacksVersions() 
{
    echo -e "\n"

    echo -e "${bold_Blue}- GO:${NC}"
    echo -e "${Green}    $(go version)${NC}"

    echo -e "${bold_Blue}- Git:${NC}"
    echo -e "${Green}    $(git version)${NC}"

    echo -e "${bold_Blue}- Nodejs:${NC}"
    echo -e "${Green}    $(node --version)${NC}"

    echo -e "${bold_Blue}- Docker:${NC}"
    echo -e "${Green}    $(docker -v)${NC}"
    
    echo -e "${bold_Blue}- Docker-Compose:${NC}"
    echo -e "${Green}    $(docker-compose -v)${NC}"

    echo 
    echo -e "${bold_Cyan}____________________________________________________________${NC}"

    echo
    echo -e "${Yellow}* If you want to use installed tools, close the terminal and open it again.${NC}"
    echo -e "${Yellow}Or run command ${bold_Purple}'source ~/.bashrc'${NC}"
    echo
}


##########################################################
#                      Run Functions
##########################################################

checkUserPwd
installTools
installNodejs
installGo
checkDocker
installDockerCompose
logInstalledPacksVersions#!/bin/bash -i

# export environment variables from .env file
export $(xargs < .env)


##########################################################
#                       Validate User
##########################################################

function checkUserPwd()
{
    # current user password
    userPwd=$(cat ./tmp.txt)

    # if NO password is provided
    if [ "$userPwd" == "" ]; then
        echo -e "${bold_Red}* User password MUST be provided as first argument.${NC}"
        echo -e "${bold_Red}Exiting...${NC}"
        exit
    fi

    # check correctness of the password
    echo $userPwd | sudo -S ls
    if [ $? != 0 ]; then
        echo -e "${bold_Red}* User password is INCORRECT.${NC}"
        echo -e "${bold_Red}Exiting...${NC}"
        exit
    fi

    # clear contents of the password file - (for security)
    > ./tmp.txt    
}


##########################################################
#                install required tools
##########################################################

function installTools()
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing required tools${NC}"
    echo "==============================================="
    echo

    # pipes user password for sudo commands
    echo $userPwd | sudo -S apt-get update
    sudo apt-get install -y build-essential git-all make curl wget zip unzip g++ libtool libltdl-dev jq

    # check if any package of the above failed to be installed
    if [ $? != 0 ]; then
        echo
        echo -e "${bold_Red}* Failed to install required tools.${NC}"
        exit
    fi


    echo -e "${bold_Green}* Required tools installed successfully${NC}"
    echo "build-essential, git, make, curl, wget, zip, unzip, g++, libtool, libltdl-dev, jq"
    echo
    echo -e "${bold_Cyan}____________________________________________________________${NC}"
}


##########################################################
#                   Nodejs Installation
##########################################################

# install NVM and Nodejs
function installNodejs() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing NVM and Nodejs${NC}"
    echo "==============================================="
    echo

    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash 

    source ~/.bashrc 
    
    nvm install $nodejsVersion  &&  nvm use $nodejsVersion


    if [ $? == 0 ]
    then
        echo -e 
        echo -e "${bold_Green}* Nodejs installed successfully${NC}"
        node --version
    else
        echo -e 
        echo -e "${bold_Red}* Failed to install Nodejs${NC}"
    fi

    echo 
    echo -e "${bold_Cyan}____________________________________________________________${NC}"
}


##########################################################
#                    GO Installation
##########################################################

function installGo() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}               Installing GO Lang${NC}"
    echo "==============================================="
    echo

    isGoInstalled=false

    # if 'go' directory is NOT avaialble in /usr/local/
    if [ ! -d "$go_installation_path" ] 
    then
        echo -e "${Yellow}go directory NOT found in path:${NC} ${go_installation_path}"
        echo "Downloading go1.17.6"

        # download go
        wget $go_download_link

        # if download failed
        if [ $? != 0 ]
        then
            echo -e "${RED}* Failed to download go. Check network connection or use a VPN${NC}"
            exit
        fi

        sudo tar -C /usr/local -xvzf $go_zip_file
        goExports   # 'export's for 'go'
        
        checkInstallation "go"   # check if 'go' command works
        if [ $? == "200" ]; then isGoInstalled=true; fi

        # if trys for installing 'go' failed
        if [ "$isGoInstalled" == "false" ]
        then
            echo -e "${Red}* Failed to install go (go command does NOT work). Try it yourself!${NC}"
            exit
        fi
    
    # if 'go' directory is avaialble in /usr/local/
    else
        goExports           # 'export's for 'go'
        checkInstallation "go"   # check if 'go' command works
        if [ $? == "200" ]; then isGoInstalled=true; fi

        # if trys for installing 'go' failed
        if [ "$isGoInstalled" == "false" ]
        then
            echo -e "${Red}* Failed to install go (go command does NOT work). Try it yourself!${NC}"
            exit
        fi
    fi

    echo -e 
    echo -e "${bold_Green}* GO installed successfully${NC}"
    go version
    echo 
    echo -e "${bold_Cyan}____________________________________________________________${NC}"
}


# some exports for 'go' to work
function goExports() 
{
    export GOPATH="/usr/local/bin"
    export PATH="$PATH:/usr/local/go/bin"

    echo -e "\n\n\nexport GOPATH=/usr/local/bin" >> ~/.bashrc
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc

    source ~/.bashrc
}


##########################################################
#                   Docker Installation
##########################################################

function checkDocker()
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing Docker Engine${NC}"
    echo "==============================================="
    echo
    
    isDockerInstalled=false

    checkInstallation "docker"   # check if 'docker' command works
    if [ $? == "200" ]; then isDockerInstalled=true; fi

    #  install Docker Engine, if NOT installed
    if [ $isDockerInstalled == "false" ]; then installDocker
    # if Docker is previously installed
    else
        dockerVersion=$(echo $(docker -v))
        currentDockerV=${dockerVersion:15:2}

        # compare installed Docker version with min-required version
        if [ $currentDockerV -ge $minRequiredDockerV ]
        then
            echo -e 
            echo -e "${bold_Green}* Pre-Installed Docker Engine is OK - v18 or greater is OK${NC}"
            docker -v
            echo 
            echo -e "${bold_Cyan}____________________________________________________________${NC}"
        else
            # remove docker (containers and volumes are NOT affected), and Install it again
            sudo apt-get remove docker docker-engine docker.io containerd runc
            installDocker
        fi
    fi

}


function installDocker() 
{
    echo
    echo -e "${Yellow}* Installing Docker Engine...${NC}"

    sudo apt-get update
    sudo apt-get install -y ca-certificates gnupg lsb-release
    sudo rm /usr/share/keyrings/docker-archive-keyring.gpg
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get -y install docker-ce docker-ce-cli containerd.io
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo chmod 666 /var/run/docker.sock

    # exit installation if could NOT install Docker
    checkInstallation "docker"   # check if 'docker' command works
    if [ $? == "404" ]
    then 
        echo "${RED}* Could NOT install Docker Engine, Try it Yourself!${NC}"
        exit
    else

        if [ $? == 0 ]
        then
            echo -e 
            echo -e "${bold_Green}* Docker Engine installed successfully.${NC}"
            docker -v
        else
            echo -e 
            echo -e "${bold_Red}* Failed to install Docker Engine${NC}"
        fi
        
        echo 
        echo -e "${bold_Cyan}____________________________________________________________${NC}"
    fi
}


##########################################################
#              Docker-Compose Installation
##########################################################

function installDockerCompose() 
{
    echo
    echo "==============================================="
    echo -e "${bold_Blue}           Installing Docker-Compose${NC}"
    echo "==============================================="
    echo

    # uninstall docker-compose
    sudo rm /usr/local/bin/docker-compose
    sudo rm /usr/local/bin/docker-compose /usr/bin/docker-compose

    # install docker-compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # exit installation if could NOT install Docker-Compose
    checkInstallation "docker-compose"   # check if 'docker' command works
    if [ $? == "404" ]
    then 
        echo "${RED}* Could NOT install Docker-Compose, Try it Yourself!${NC}"
        exit
    else
        echo -e 
        echo -e "${bold_Green}* Docker-Compose installed successfully.${NC}"
        docker-compose -v

        echo 
        echo -e "${bold_Cyan}____________________________________________________________${NC}"
    fi
}


##########################################################
#                       General Tools
##########################################################

# check if 'PACKAGE' is installed by 'PACKAGE version' command
function checkInstallation()
{
    $1 version

    # check if 'PACKAGE' is previously installed
    if [ $? != 0 ]
    then
        return "404"    # Not Installed
    else
        return "200"    # Installed
    fi
}


# log the version of installed packages
function logInstalledPacksVersions() 
{
    echo -e "\n"

    echo -e "${bold_Blue}- GO:${NC}"
    echo -e "${Green}    $(go version)${NC}"

    echo -e "${bold_Blue}- Git:${NC}"
    echo -e "${Green}    $(git version)${NC}"

    echo -e "${bold_Blue}- Nodejs:${NC}"
    echo -e "${Green}    $(node --version)${NC}"

    echo -e "${bold_Blue}- Docker:${NC}"
    echo -e "${Green}    $(docker -v)${NC}"
    
    echo -e "${bold_Blue}- Docker-Compose:${NC}"
    echo -e "${Green}    $(docker-compose -v)${NC}"

    echo 
    echo -e "${bold_Cyan}____________________________________________________________${NC}"

    echo
    echo -e "${Yellow}* If you want to use installed tools, close the terminal and open it again.${NC}"
    echo -e "${Yellow}Or run command ${bold_Purple}'source ~/.bashrc'${NC}"
    echo
}


##########################################################
#                      Run Functions
##########################################################

checkUserPwd
installTools
installNodejs
installGo
checkDocker
installDockerCompose
logInstalledPacksVersions