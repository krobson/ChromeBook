# TODO: update resolv.conf after network manager install to point to upstream gateway
# TODO: Install crc & ensure that disk image is sparse and look at how to manage pull secret
# TODO: Sert-up Windows 11 and ensure that disk image is sparse
# TODO: Set-up SSH Agent in systemd
# TODO: Set-up symlinks in home directory
# TODO: Abstract away user name
# TODO: Restore dot files from github including secrets management for SSH keys
# TODO: Move cryptomator vault to GPG and use for secrets management & them remove it from build
#       https://www.thegeekdiary.com/how-to-create-virtual-block-device-loop-device-filesystem-in-linux/
#       https://www.nas.nasa.gov/hecc/support/kb/using-gpg-to-encrypt-your-data_242.html
# TODO: Look at adding seperate containers to run CRC and Windows

# Check we are executing in termina and not in penguin
if [[ $PS1 != *termina* ]]; then
  echo Script needs to be run in termina VM
  exit 1
fi

# Ensure that nested security is enabled
lxc start penguin

lxc config set penguin security.nesting true

# Create our build script locally in termina
cat <<EndOfBuildScript > /tmp/build.sh
#!/bin/bash

# Install additonal packages using apt
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
  flatpak \
  git \
  network-manager \
  libvirt-daemon \
  libvirt-clients \
  virt-manager \
  vim

# Install user apps using flathub
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install --assumeyes --noninteractive flathub \
  com.google.Chrome \
  org.mozilla.firefox \
  org.cryptomator.Cryptomator \
  com.visualstudio.code \
  io.github.shiftey.Desktop \
  org.wireshark.Wireshark \
  com.basemark.BasemarkGPU \
  md.obsidian.Obsidian \
  org.signal.Signal \
  com.slack.Slack \
  com.transmissionbt.Transmission \
  org.nmap.Zenmap

flatpak update --assumeyes --noninteractive

# Create systemd timer to update flatpaks
mkdir -p ~/.config/systemd/user

test -f /etc/systemd/system/updateFlatpaks.service || cat <<EndOfServiceFile > ~/.config/systemd/user/updateFlatpaks.service
[Unit]
Description=A job to update flatpaks automatically

[Service]
Type=simple
ExecStart=flatpak update --noninteractive

[Install]
WantedBy=default.target
EndOfServiceFile

systemctl --user enable -q updateFlatpaks.service
systemctl --user start -q updateFlatpaks.service

test -f /etc/systemd/system/updateFlatpaks.timer || cat <<EndOfTimerFile > ~/.config/systemd/user/updateFlatpaks.timer
[Unit]
Description=A job to update flatpaks automatically
RefuseManualStart=no
RefuseManualStop=no

[Timer]
Persistent=true
OnBootSec=120
OnUnitActiveSec=1d
Unit=updateFlatpaks.service

[Install]
WantedBy=timers.target
EndOfTimerFile

systemctl --user enable -q updateFlatpaks.timer
systemctl --user start -q updateFlatpaks.timer

# Install Oh My Bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

# Restore user config from github
#echo ".cfg" >> .gitignore
#git clone --bare git@github.com:krobson/myDotFiles.git $HOME/.cfg

#mkdir -p .config-backup &&
#  git --git-dir=$HOME/.cfg/ --work-tree=$HOME checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}

#git --git-dir=$HOME/.cfg/ --work-tree=$HOME checkout
EndOfBuildScript

# Copy the build script into our container
lxc file push /tmp/build.sh penguin/tmp/build.sh

# Execute our build script in our container
lxc exec penguin -- sudo --user kenrobson bash -x /tmp/build.sh

# Delete our build script in our container
lxc file delete penguin/tmp/build.sh

# Close down our container
lxc stop penguin
