Chromebook Build Scripts

Use the following to build your chromebook from CROSH:

  vmc termina start
  bash -lxc "$(curl -fsSL https://github.com/krobson/ChromeBook/raw/main/buildCrostini.sh)" 
