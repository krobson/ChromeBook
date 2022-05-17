# TODO: Install crc & ensure that disk image is sparse and look at how to manage pull secret
#       WARN Wildcard DNS resolution for apps-crc.testing does not appear to be working
#       WARN Cannot add pull secret to keyring: The name org.freedesktop.secrets was not provided by any .service files
#       Update crc in VMM to improve performance if possible and then update build with changes
# TODO: Set-up Windows 11 and ensure that disk image is sparse
# TODO: Set-up SSH Agent in systemd
# TODO: Update dot files for crc and others?
#       Add docker podman alias

# Command to build
# bash -lxc "$(curl -fsSL https://github.com/krobson/ChromeBook/raw/main/buildCrostini.sh)"

# Check we are executing in termina and not in penguin
if [[ $PS1 != *termina* ]]; then
  echo Script needs to be run in termina VM
  exit 1
fi

# Ensure that nested security is enabled
lxc start penguin

lxc config set penguin security.nesting true

# Create our build script locally in termina
cat << 'EndOfBuildScript' > /tmp/build.sh
#!/bin/bash

# Use restrictive file permissions
umask 077

# Install additonal packages using apt
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
  emacs \
  flatpak \
  git-all \
  network-manager \
  libvirt-daemon \
  libvirt-clients \
  virt-manager \
  qemu-kvm \
  libvirt-daemon-system \
  gnome-keyring \
  qemu-guest-agent \
  podman \
  libguestfs-tools \
  dnsutils \
  jq \
  gnupg2 \
  securefs \
  fuse \
  kubernetes-client \
  make \
  vim-gtk3

# Fix up NetworkManager dnsmasq configuation in preparation for crc install
# Here documents need tabs not space for indents
sudo bash <<- EndOfBashScript
	cat <<- EndOfLocalDotConf > /etc/NetworkManager/dnsmasq.d/local.conf
		server=100.115.92.193
		local=/.local/
		expand-hosts
		domain=.local
	EndOfLocalDotConf
EndOfBashScript

sudo chmod go+r /etc/NetworkManager/dnsmasq.d/local.conf
sudo systemctl restart NetworkManager

# Install user apps using flathub
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install --assumeyes --noninteractive flathub \
  com.google.Chrome \
  # org.mozilla.firefox \
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
mkdir -p $HOME/.config/systemd/user
export XDG_CONFIG_HOME=/home/kenrobson/.config
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export XDG_RUNTIME_DIR=/run/user/1000

test -f /etc/systemd/system/updateFlatpaks.service || cat << EndOfServiceFile > $HOME/.config/systemd/user/updateFlatpaks.service
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

test -f /etc/systemd/system/updateFlatpaks.timer || cat << EndOfTimerFile > $HOME/.config/systemd/user/updateFlatpaks.timer
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
curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | /usr/bin/bash -l

# Install Bash Line Editor to get syntax highlighting
cd /tmp
git clone --recursive https://github.com/akinomyoga/ble.sh.git
make -C ble.sh install PREFIX=~/.local
cd $HOME

# Define location of Google Drive
GOOGLEDRIVE=/mnt/chromeos/GoogleDrive/MyDrive

# Mount Vault and copy SSH keys
VAULTPATH=$HOME/mnt/vault
mkdir -p $HOME/.ssh
mkdir -p $VAULTPATH
echo Enter SecureFS Vault passphrase
securefs mount -b --noflock --single $GOOGLEDRIVE/Vaults/Vault $VAULTPATH
cp $VAULTPATH/myKeys/ken/ssh/* $HOME/.ssh
chmod -R go-rwx $HOME/.ssh

# Create symlinks to Google Drive content
ln -s $GOOGLEDRIVE/Downloads $HOME/downloads
ln -s $GOOGLEDRIVE/Applications $HOME/bin
ln -s $GOOGLEDRIVE/Backups $HOME/backups
ln -s $GOOGLEDRIVE/'01 - Projects' $HOME/projects
ln -s $GOOGLEDRIVE/Images $HOME/images

# Add keys to ssh agent for git
eval "$(ssh-agent -s)"
echo Add SSH key passphrase
ssh-add $HOME/.ssh/id_ed25519

# Restore user config from github
rm .gitignore && cat <<- EndOfGitIgnore > $HOME/.gitignore
  .cfg
EndOfGitIgnore

test -d $HOME/.cfg &&
  rm -rf $HOME/.cfg
git clone --bare git@github.com:krobson/myDotFiles.git $HOME/.cfg

mkdir -p $HOME/.config-backup &&
  git --git-dir=$HOME/.cfg/ --work-tree=$HOME checkout 2>&1 |
  egrep "\s+\." | awk {'print $1'} |
  xargs -I {} bash -c "mkdir -p $HOME/.cfg-backup/\$(dirname {}) && mv $HOME/{} $HOME/.cfg-backup/{}"

git --git-dir=$HOME/.cfg/ --work-tree=$HOME checkout
git --git-dir=$HOME/.cfg/ --work-tree=$HOME push --set-upstream origin main
git --git-dir=$HOME/.cfg/ --work-tree=$HOME config --local status.showUntrackedFiles no

# Set-up QEMU
sudo grep -q QemuDotConf /etc/libvirt/qemu.conf || sudo bash -l <<- EndOfBashScript
	cat <<- EndOfQemuDotConf >> /etc/libvirt/qemu.conf
		# Install token = QemuDotConf
		# Local additions
		user = "root"
		group = "root"
		remember_owner = 0
	EndOfQemuDotConf
EndOfBashScript

# Set-up local OpenShift
wget --output-document /tmp/crc-linux-amd64.tar.xz https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz
tar xvf /tmp/crc-linux-amd64.tar.xz --directory /tmp
mv /tmp/crc-linux-*/crc $HOME/bin
$HOME/bin/crc config set consent-telemetry yes
$HOME/bin/crc config set nameserver 8.8.8.8
$HOME/bin/crc setup
$HOME/bin/crc start -p $HOME/mnt/vault/myKeys/ken/redhat/pull-secret.txt
$HOME/bin/crc stop


# Setup SSH Agent in systemd
test -f $HOME/.config/systemd/user/ssh-agent.service || cat <<- EndSshAgentFile > $HOME/.config/systemd/user/ssh-agent.service
	[Unit]
	Description=SSH Key Agent
	After=systemd-user-sessions.service user-runtime-dir@%i.service dbus.service
  

	[Service]
	Type=simple
	Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
	ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK
	Requires=user-runtime-dir@%i.service

	[Install]
	WantedBy=default.target
EndSshAgentFile

grep -q "SSH_AUTH_SOCK DEFAULT" $HOME/.pam_environment || cat <<- EndOfPamFile >> $HOME/.pam_environment
	SSH_AUTH_SOCK DEFAULT=\${XDG_RUNTIME_DIR}/ssh-agent.socket
EndOfPamFile

systemctl --user enable ssh-agent
systemctl --user start ssh-agent

chmod -R 600 $HOME/.ssh/*

# Unmount key vault
umount $VAULTPATH
EndOfBuildScript

# Copy the build script into our container
lxc file push /tmp/build.sh penguin/tmp/build.sh

# Execute our build script in our container
lxc exec penguin -- sudo --user kenrobson --group kenrobson /usr/bin/bash -lx /tmp/build.sh

# Delete our build script in our container
#lxc file delete penguin/tmp/build.sh

# Close down our container
#lxc stop penguin
