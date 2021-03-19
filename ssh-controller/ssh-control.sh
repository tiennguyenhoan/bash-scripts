#!/bin/bash

fileSource=${1:-"server.txt"}
version="3.0"

re='^[0-9]+$'
green=`tput setaf 2`
reset=`tput sgr0`

controller() {
  while true; do
    echo 'Control Manager'
    echo ''
    echo '1- Get ssh info'
    echo '2- Ssh to server'
    echo '3- Transfer data between server'
    echo '4- Open server source'
    echo "---------------------"
    echo 'ANY- exit'
    echo '   '
    echo -n 'Select: '
    read choice
    case $choice in
      1) getServerInfo view && break;;
      2) getServerInfo ssh && break;;
      3) getServerInfo copy && break;;
      4) vi $fileSource && clear && break;;
      *) clear && exit;;
    esac
  done
}

getServerInfo() {
  while true; do
    printOptions
    echo "Mode selected: $1"
    echo ""
    echo -n "Select: "

    read choice
    if [ $choice == "0" ]; then
      clear
      exit
    elif [ $choice == "<" ]; then
      clear
      controller
      break
    elif [ $choice != "0" ]; then
      clear
      if ! [[ $choice =~ $re ]] ; then
        echo "The input is invalid, try again."
        printWaitCommand
        getServerInfo $1
        break
      fi
      executor $1 $choice
      break
    fi
  done
}

executor() {
  if [[ $1 == 'view' ]]; then
    clear
    printServerInfo $2
    printWaitCommand
    getServerInfo view
  elif [[ $1 == 'ssh' ]]; then
    sshToServer $2
  elif [[ $1 == 'copy' ]]; then
    tranferData $2
  fi
}

tranferData() {
  [[ $(uname -a| cut -d " " -f1) == "Darwin" ]] && servers=($(echo $(getServerFromScript) | tr '<' "\n")) || IFS='<' read -ra servers <<< $(getServerFromScript)
  
  serverIp=$(echo ${servers[$1]}| cut -d "|" -f3)
  serverName=$(echo ${servers[$1]}| cut -d "|" -f2)
  userAccess=$(echo ${servers[$1]}| cut -d "|" -f4)
  passAccess=$(echo ${servers[$1]}| cut -d "|" -f5)
  keyPath=$(echo ${servers[$1]}| cut -d "|" -f6)

  if [ "$userAccess" == "" ]; then
    userAccess = "root"
  fi 

  if [ "$serverIp" == "" ]; then
    echo "Invalid server info, please select again"
    printWaitCommand
    clear
    controller
  fi 

  echo 'Please selected mode'
  echo ''
  echo '1- Download'
  echo '2- Upload'
  echo "---------------------"
  echo '   '
  echo -n 'Select: '
  read mode
  
  clear

  if ! [[ $mode =~ $re ]] ; then
    echo "The input is invalid, try again."
    tranferData $1
  fi

  echo "Server            : $serverName"
  [[ $mode == "1" ]] && echo "Mode selected     : Download" || echo "Mode selected     : Upload"
  echo "Current Position  : $PWD"
  echo "---------------------"
  echo -n "Source            : "
  read sourceIn 
  echo -n "Destination       : "
  read destination
  
  echo "Executing...."
  echo ""
  if [ $mode == "1" ]; then
    if [ "$passAccess" == "" ] && [ "$keyPath" == "" ]; then
      scp -r $userAccess@$serverIp:$sourceIn $destination
    elif [ "$passAccess" != "" ]; then
      sshpass -p $passAccess scp -r $userAccess@$serverIp:$sourceIn $destination
    else
      scp -i $keyPath -r $userAccess@$serverIp:$sourceIn $destination
    fi
  elif [ $mode == "2" ]; then
    if  [ "$passAccess" == "" ] && [ "$keyPath" == "" ]; then
      echo "scp -r $sourceIn $userAccess@$serverIp:$destination"
      scp -r $sourceIn $userAccess@$serverIp:$destination
    elif [ "$passAccess" != "" ]; then
      echo "sshpass -p $passAccess scp -r $sourceIn $userAccess@$serverIp:$destination"
      sshpass -p $passAccess scp -r $sourceIn $userAccess@$serverIp:$destination
    else
      echo "scp -i $keyPath -r $sourceIn $userAccess@$serverIp:$destination"
      scp -i $keyPath -r $sourceIn $userAccess@$serverIp:$destination
    fi
  else
    clear
    tranferData $1
  fi
}

printServerInfo() {
  [[ $(uname -a| cut -d " " -f1) == "Darwin" ]] && servers=($(echo $(getServerFromScript) | tr '<' "\n")) || IFS='<' read -ra servers <<< $(getServerFromScript)

  serverName=$(echo ${servers[$1]}| cut -d "|" -f2)
  serverIp=$(echo ${servers[$1]}| cut -d "|" -f3)
  userAccess=$(echo ${servers[$1]}| cut -d "|" -f4)
  keyPath=$(echo ${servers[$1]}| cut -d "|" -f6)
  echo "Name      : $serverName"
  echo "Ip        : $serverIp"
  echo "User      : $userAccess"
  echo "Key Path  : $keyPath"
}

sshToServer() {
  [[ $(uname -a| cut -d " " -f1) == "Darwin" ]] && servers=($(echo $(getServerFromScript) | tr '<' "\n")) || IFS='<' read -ra servers <<< $(getServerFromScript)

  serverIp=$(echo ${servers[$1]}| cut -d "|" -f3)
  userAccess=$(echo ${servers[$1]}| cut -d "|" -f4)
  passAccess=$(echo ${servers[$1]}| cut -d "|" -f5)
  keyPath=$(echo ${servers[$1]}| cut -d "|" -f6)

  if [ "$userAccess" == "" ]; then
    userAccess = "root"
  fi 

  if [ "$serverIp" == "" ]; then
    echo "Invalid server info, please select again"
    printWaitCommand
    clear
    controller
  fi 

  if [ "$passAccess" == "" ] && [ "$keyPath" == "" ]; then
    ssh $userAccess@$serverIp
  elif [ "$passAccess" != "" ]; then
    sshpass -p $passAccess ssh $userAccess@$serverIp
  else
    ssh -i $keyPath $userAccess@$serverIp
  fi
}

getServerFromScript() {
  serverInfo="exit<"
  while IFS= read -r line; do
    serverInfo+="$line<"
  done < $fileSource
  echo "$serverInfo"
}

printWelcomeMess() {
  clear
  echo "${green}##############################################"
  echo "#      Welcome To Server Access Control      #"
  echo "#      --------------------------------      #"
  echo "# This will help ssh easier through servers, #"
  echo "# which is shared between devops             #"
  echo "#                                            #"
  echo "# Version: $version                               #"
  echo "# Maintainer: Tien Nguyen Hoan - DevOps      #"
  echo "##############################################${reset}"
  echo ''
}

printOptions() {
  clear
  echo "Select file server to execute"

  [[ $(uname -a| cut -d " " -f1) == "Darwin" ]] && servers=($(echo $(getServerFromScript) | tr '<' "\n")) || IFS='<' read -ra servers <<< $(getServerFromScript)
  serverLent=${#servers[@]}

  for ((i=1; i < $serverLent; i++)); do
    serverName=$(echo "${servers[$i]}"| cut -d "|" -f2 )
    echo "$i : $serverName"
  done
  echo "---------------------"
  echo "0 : exit"
  echo "< : back"
  echo ""
}

printWaitCommand() {
  echo ""
  echo "---------------------"
  read -n 1 -r -s -p $'Press any keys to continue...\n'
}

printWelcomeMess
controller

