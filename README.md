Chromebook Build Scripts

Use the following to build your chromebook from CROSH:

  vmc termina start
  
  curl -fsSL https://github.com/krobson/ChromeBook/raw/main/buildCrostini.sh | bash -lx (Deprecated)
  
  bash -lxc "$(curl -fsSL https://github.com/krobson/ChromeBook/raw/main/buildCrostini.sh)"
