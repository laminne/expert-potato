#!/bin/sh

echo " Clapp_project Ex-potato"

echo "Kantan-Installer Ver 1.0"

echo "インストールするものを選んでください"
export LANG=ja_JP.utf8

#1) Install Mastodon 3.0
#2) Install  Gitlab
#3) Install  Mattermost
#4) Exit and Cancel

select VAR in InstallMastodon3.0 InstallGitlab InstallMattermost Exit

do
      echo "You Choose $VAR !"
         if [ "$VAR" = "InstallMastodon3.0" ]; then
           break
         fi
         if [ "$VAR" = "InstallGitlab" ]; then
           sh Gitlab.sh
         fi
         if [ "$VAR" = "InstallMattermost" ]; then
           sh Mattermost.sh
         fi
        if [ "$VAR" = "Exit" ]; then
            break
          fi
done
