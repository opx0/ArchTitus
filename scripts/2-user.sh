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

sed -n '/'$INSTALL_TYPE'/q;p' ~/ArchTitus/pkg-files/${DESKTOP_ENV}.txt | while read line
do
  if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]
  then
    # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
    continue
  fi
  echo "INSTALLING: ${line}"
  sudo pacman -S --noconfirm --needed ${line}
done


if [[ ! $AUR_HELPER == none ]]; then
  cd ~
  git clone "https://aur.archlinux.org/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  makepkg -si --noconfirm
  # sed $INSTALL_TYPE is using install type to check for MINIMAL installation, if it's true, stop
  # stop the script and move on, not installing any more packages below that line
  sed -n '/'$INSTALL_TYPE'/q;p' ~/ArchTitus/pkg-files/aur-pkgs.txt | while read line
  do
    if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
      # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
      continue
    fi
    echo "INSTALLING: ${line}"
    $AUR_HELPER -S --noconfirm --needed ${line}
  done
fi

export PATH=$PATH:~/.local/bin

# Theming DE for KDE - macOS Tahoe themes (applies to all KDE installs)
if [[ $DESKTOP_ENV == "kde" ]]; then
    cp -r ~/ArchTitus/configs/.config/* ~/.config/
    
    echo -ne "
-------------------------------------------------------------------------
                Installing macOS Tahoe Themes
-------------------------------------------------------------------------
"
    cd ~
    
    # MacTahoe Icons
    echo "Installing MacTahoe Icons..."
    git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git
    cd MacTahoe-icon-theme && ./install.sh && cd ~
    
    # MacTahoe KDE Theme
    echo "Installing MacTahoe KDE Theme..."
    git clone --depth=1 https://github.com/vinceliuice/MacTahoe-kde.git
    cd MacTahoe-kde && ./install.sh && cd ~
    
    # WhiteSur Cursors
    echo "Installing WhiteSur Cursors..."
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git
    cd WhiteSur-cursors && ./install.sh && cd ~
    
    # Apply themes using plasma tools
    echo "Applying macOS themes..."
    plasma-apply-lookandfeel -a com.github.vinceliuice.MacTahoe || true
    plasma-apply-cursortheme WhiteSur-cursors || true
    /usr/lib/plasma-changeicons MacTahoe || true
    
    # Set themes via kwriteconfig5 as fallback
    kwriteconfig5 --file kdeglobals --group Icons --key Theme "MacTahoe"
    kwriteconfig5 --file kdeglobals --group General --key ColorScheme "MacTahoe"
    kwriteconfig5 --file kcminputrc --group Mouse --key cursorTheme "WhiteSur-cursors"
    
    # Cleanup theme repos
    rm -rf ~/MacTahoe-icon-theme ~/MacTahoe-kde ~/WhiteSur-cursors
    
    echo "macOS Tahoe themes installed successfully!"
fi

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
