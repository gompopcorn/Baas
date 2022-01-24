#!/bin/bash

# export environment variables from .env file
export $(xargs < .env)


function checkUserPwd()
{
    # current user password
    userPwd=$(cat ./tmp.txt)

    # if NO password is provided
    if [ "$userPwd" == "" ]; then
        echo -e "${bold_Red}* User password MUST be provided in tmp.txt file.${NC}"
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


function run()
{
    echo $userPwd | sudo -S apt-get install tmux

    runCommand=$1
    sessionName=$2

    tmux new -s $sessionName -d
    tmux send-keys -t $sessionName $runCommand C-m
    tmux attach -t $sessionName -d    # shows tmux terminal
}


checkUserPwd
run