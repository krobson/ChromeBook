# TODO: update resolv.conf after network manager install to point to upstream gateway
#       /tmp/build.sh: line 9: /etc/resolv.conf: Permission denied
# TODO: Install crc & ensure that disk image is sparse and look at how to manage pull secret
#       WARN Wildcard DNS resolution for apps-crc.testing does not appear to be working
#       WARN A new version (2.2.2) has been published on https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/2.2.2/crc-linux-amd64.tar.xz 
#       https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz
#       WARN Cannot add pull secret to keyring: The name org.freedesktop.secrets was not provided by any .service files
#       Update crc in VMM to improve performance if possible and then update build with changes
# TODO: Sert-up Windows 11 and ensure that disk image is sparse
# TODO: Set-up SSH Agent in systemd
# TODO: Set-up symlinks in home directory
# TODO: Abstract away user name
# TODO: Restore dot files from github including secrets management for SSH keys
# TODO: Move cryptomator vault to GPG and use for secrets management & them remove it from build
#       https://www.thegeekdiary.com/how-to-create-virtual-block-device-loop-device-filesystem-in-linux/
#       https://www.nas.nasa.gov/hecc/support/kb/using-gpg-to-encrypt-your-data_242.html
# TODO: Look at adding seperate containers to run CRC and Windows
# TODO: Edit qemu.conf https://www.reddit.com/r/Crostini/comments/sayw8l/unable_to_set_xattr_trustedlibvirtsecuritydac/
# TODO: Update dot files for crc and others?
#       Add docker podman alias

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
  qemu-kvm \
  libvirt-daemon-system \
  gnome-keyring \
  qemu-guest-agent \
  podman \
  libguestfs-tools
  
# Update resolv.conf to use gateway DNS for external lookups
cat << EndOfResolveDotConf > /etc/resolv.conf
domain lxd
search lxd
nameserver 100.115.92.193
EndOfResolveDotConf


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

test -f /etc/systemd/system/updateFlatpaks.service || cat << EndOfServiceFile > ~/.config/systemd/user/updateFlatpaks.service
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

test -f /etc/systemd/system/updateFlatpaks.timer || cat << EndOfTimerFile > ~/.config/systemd/user/updateFlatpaks.timer
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
