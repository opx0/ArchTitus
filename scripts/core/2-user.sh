#!/usr/bin/env bash
#github-action genshdoc
#
# @file User
# @brief User customizations and AUR package installation.
echo -ne "
-------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
                        SCRIPTHOME: ArchTitus
-------------------------------------------------------------------------

Installing AUR Softwares
"
source $HOME/ArchTitus/configs/setup.conf

  cd ~
  mkdir "/home/$USERNAME/.cache"
  touch "/home/$USERNAME/.cache/zshhistory"
  git clone "https://github.com/ChrisTitusTech/zsh"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
  ln -s "~/zsh/.zshrc" ~/.zshrc

# Read packages into an array to batch installation
mapfile -t pkgs < <(sed -n "/$INSTALL_TYPE/q;p" "$HOME/ArchTitus/pkg-files/${DESKTOP_ENV}.txt" | grep -v -- "--END OF MINIMAL INSTALL--" | grep -v "^$")

if [[ ${#pkgs[@]} -gt 0 ]]; then
    echo "INSTALLING: ${pkgs[*]}"
    sudo pacman -S --noconfirm --needed "${pkgs[@]}"
fi


if [[ ! $AUR_HELPER == none ]]; then
  cd ~
  git clone "https://aur.archlinux.org/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  makepkg -si --noconfirm
  # sed $INSTALL_TYPE is using install type to check for MINIMAL installation, if it's true, stop
  # stop the script and move on, not installing any more packages below that line

  # Read AUR packages into an array
  mapfile -t aur_pkgs < <(sed -n "/$INSTALL_TYPE/q;p" "$HOME/ArchTitus/pkg-files/aur-pkgs.txt" | grep -v -- "--END OF MINIMAL INSTALL--" | grep -v "^$")

  if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
    echo "INSTALLING: ${aur_pkgs[*]}"
    $AUR_HELPER -S --noconfirm --needed "${aur_pkgs[@]}"
  fi
fi

export PATH=$PATH:~/.local/bin

# Theming DE if user chose FULL installation
if [[ $INSTALL_TYPE == "FULL" ]]; then
  if [[ $DESKTOP_ENV == "kde" ]]; then
    cp -r ~/ArchTitus/configs/.config/* ~/.config/
    pip install konsave
    konsave -i ~/ArchTitus/configs/kde.knsv
    sleep 1
    konsave -a kde
 fi
fi

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
