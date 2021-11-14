#!/bin/bash
sudo apt -y install apt-file bash-completion cron gnupg2 jq whois zip tree gnome-terminal tmux file autossh dnsutils elinks netcat nautilus build-essential awscli wget curl git-all gdebi-core python3 python3-pytest python3-selenium chromium-driver iptables cockpit openssh-server openssh-client

# Install rkt to manage containers
gpg --recv-key 18AD5014C99EF7E3BA5F6CE950BDD3E0FC8A365E
wget https://github.com/rkt/rkt/releases/download/v1.30.0/rkt_1.30.0-1_amd64.deb
wget https://github.com/rkt/rkt/releases/download/v1.30.0/rkt_1.30.0-1_amd64.deb.asc
gpg --verify rkt_1.30.0-1_amd64.deb.asc
sudo gdebi -n rkt_1.30.0-1_amd64.deb
rm rkt_1.30.0-1_amd64.deb
rm rkt_1.30.0-1_amd64.deb.asc

# Fix locales so gnome terminal runs
