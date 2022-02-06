#!/bin/bash

# export environment variables from .env file
export $(xargs < .env)


function checkUserPwd()
{
    # current user password
    userPwd=$(cat ./pwd.txt)

    # if NO password is provided
    if [ "$userPwd" == "" ]; then
        echo -e "${bold_Red}* User password MUST be provided in pwd.txt file.${NC}"
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
}


function run()
{
    echo $userPwd | sudo -S apt-get install tmux

    runCommand=$1
    sessionName=$2

    tmux new -s $sessionName -d
    tmux send-keys -t $sessionName $runCommand C-m
    # tmux attach -t $sessionName   # shows tmux terminal
}


checkUserPwd
run $1 $2