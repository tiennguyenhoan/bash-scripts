#!/bin/bash

# Color format 
greenCol="\e[32m"
redCol="\e[31m"
cyanCol="\e[96m"
blueCol="\e[34m"
darkGrayCol="\e[90m"
resetCol="\e[0m"
# End color format 

awsConfigRoot="$HOME/.aws"
awsCredentials="${awsConfigRoot}/credentials"
awsConfig="${awsConfigRoot}/config"

trackingFile="${awsConfigRoot}/awsTokenInfo-${configProfile}"
authConfigFile="${awsConfigRoot}/auth.json"

# To use this script it will require to config profile with aws cli first
if [ ! -f "$awsConfig" ]; then
  echo -e "${redCol}Please config aws profile before begin${resetCol}"
  exit 1
fi

# The script will read profile directly from the aws configuration
listProfile=($(grep -e "^\[.*\]$" $awsCredentials | sed 's/[][]//g' | sed 's/ /\\n/g'))
echo "Detected Profile(s):"
for ((i=0; i < ${#listProfile[@]}; i++)); do
  echo -e "${darkGrayCol}$i${resetCol}: ${listProfile[$i]}"
done
echo -e "${darkGrayCol}****************************************${resetCol}"
echo -e -n "Enter profile name to use (${cyanCol}default profile: ${greenCol}default${resetCol}): "
read configProfile
configProfile=${configProfile:-"default"}

if [ ! -f "$authConfigFile" ]; then
  echo '{}' > $authConfigFile
fi

isProfileExisted=$(jq ". | select(.$configProfile)" $authConfigFile)
if [ -z "$isProfileExisted" ]; then
  echo $(cat $authConfigFile | jq ". + {$configProfile: {} }") > $authConfigFile
fi

# Check aws role arn of the profile
profileContent=$(jq ". | select(.$configProfile != null) | .$configProfile" $authConfigFile)
isProfileArnExist=$(echo "$profileContent" | jq ". | select(.role_arn)")
if [ -n "$isProfileArnExist" ]; then
  profileArn=$(echo "$isProfileArnExist" | jq ".role_arn" | sed -e 's/^"//' -e 's/"$//' )
  echo -e "Found user role arn: ${blueCol}$profileArn${resetCol}"
else 
  read -p "Enter profile role arn: " profileArn
  echo $(cat $authConfigFile | jq ".$configProfile |= . + {role_arn: \"$profileArn\"}") > $authConfigFile
fi

# Check authorized key for mfa still valid
expiredTimeFromLastSession=$(cat $authConfigFile | jq ".$configProfile | select(.Expiration != null) | .Expiration" | sed -e 's/^"//' -e 's/"$//' )
if [ -n "$expiredTimeFromLastSession" ]; then
  if [ `date +%s` -lt `date -d "$expiredTimeFromLastSession" +%s` ]; then
    echo -e "\n${greenCol}Key Still Valid, we don't need to renew${resetCol}"
    export AWS_ACCESS_KEY_ID=$(echo $lastSession| jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $lastSession| jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $lastSession| jq -r '.Credentials.SessionToken')
    exit 0 
  fi
fi

# Input MFA authenticate token
while true; do
  read -p "Enter MFA token: " mfaToken 
  if [ -n "$mfaToken" ]; then
    requestedToken=$(aws sts get-session-token --serial-number "$profileArn" --token-code $mfaToken --duration-seconds 129600| jq)
    if echo "$requestedToken" | grep -q "SessionToken"; then
      break
    fi
    echo -e "\n${redCol}Invalid request, Please retry again${resetCol}\n"
  else
    echo -e "${redCol}Please insert MFA token as the second parameter${resetCol}\n"
  fi
done

export AWS_ACCESS_KEY_ID=$(echo $requestedToken| jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $requestedToken| jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $requestedToken| jq -r '.Credentials.SessionToken')
export AWS_SESSION_EXPIRATION=$(echo $requestedToken| jq -r '.Credentials.Expiration')


#Update key session for this time
echo $(cat $authConfigFile | jq ".$configProfile |= . + {AccessKeyId: \"$AWS_ACCESS_KEY_ID\", SecretAccessKey: \"$AWS_SECRET_ACCESS_KEY\", SessionToken: \"$AWS_SESSION_TOKEN\", Expiration: \"$AWS_SESSION_EXPIRATION\"}") > $authConfigFile

echo -e "\n${greenCol}Key authorized!${resetCol}"
