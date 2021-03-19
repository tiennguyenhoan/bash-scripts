#!/bin/bash

read -p "Enter new user: " new_user
read -p "Enter group of user: " group

if [ -z "$new_user" ]; then
  echo "Missing Username"
  exit 1
fi

if [ -d "$new_user" ]; then
  echo "User already exist"
  exit 1
fi

if [ -n "$group" ]; then
        if ! grep -q "^${group}:" /etc/group; then
          echo "Group is not exist"
          read -p "Do you want to create new? [y/n]" choice
          if [ "$choice" = "y" ]; then
            groupadd "$group"
          fi
        fi
        useradd -m -s /bin/bash -g "$group" "$new_user"
else
        useradd -m -s /bin/bash "$new_user"
fi

mkdir /home/$new_user/.ssh

touch /home/$new_user/.ssh/authorized_keys

if [ -n "$group" ]; then
  chown $new_user:$group /home/$new_user/.ssh/authorized_keys
  chown $new_user:$group /home/$new_user/.ssh
else
  chown $new_user:$new_user /home/$new_user/.ssh/authorized_keys
  chown $new_user:$new_user /home/$new_user/.ssh
fi

chmod 600 /home/$new_user/.ssh/authorized_keys
chmod 700 /home/$new_user/.ssh

read -p "Do you want to update access keys? [y/n] " addKey
if [ "$addKey" = "y" ] || [ "$addKey" = "Y" ]; then
  vi /home/$new_user/.ssh/authorized_keys
fi

