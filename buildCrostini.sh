
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
  git


# Install user apps using flathub
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install --noninteractive flathub \
  com.google.Chrome \
  org.mozilla.firefox \
  org.cryptomator.Cryptomator \
  com.visualstudio.code \
  org.telegram.desktop \
  com.microsoft.Teams \
  io.github.shiftey.Desktop \
  org.wireshark.Wireshark \
  com.basemark.BasemarkGPU \
  com.discordapp.Discord \
  md.obsidian.Obsidian \
  org.signal.Signal \
  com.slack.Slack \
  org.telegram.desktop \
  com.transmissionbt.Transmission \
  org.nmap.Zenmap

flatpak update --noninteractive;

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
EndOfBuildScript

# Copy the build script into our container
lxc file push /tmp/build.sh penguin/tmp/build.sh

# Execute our build script in our container
lxc exec penguin -- sudo --login --user kenrobson bash -lx /tmp/build.sh

# Delete our build script in our container
lxc file delete penguin/tmp/build.sh

# Close down our container
lxc stop penguin
