#!/bin/bash
#github-action genshdoc
#
# @file ArchTitus
# @brief Entrance script that launches children scripts for each phase of installation.

# Find the name of the folder the scripts are in
set -a
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"/scripts
CONFIGS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"/configs
set +a
echo -ne "
-------------------------------------------------------------------------
        ███████╗██╗  ██╗ █████╗ ███╗   ██╗ ██████╗ ██████╗ 
        ██╔════╝╚██╗██╔╝██╔══██╗████╗  ██║██╔═══██╗██╔══██╗
        █████╗   ╚███╔╝ ███████║██╔██╗ ██║██║   ██║██████╔╝
        ██╔══╝   ██╔██╗ ██╔══██║██║╚██╗██║██║   ██║██╔══██╗
        ███████╗██╔╝ ██╗██║  ██║██║ ╚████║╚██████╔╝██║  ██║
        ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
-------------------------------------------------------------------------

                    Automated Arch Linux Installer
-------------------------------------------------------------------------
                Scripts are in directory named ArchTitus
"
    ( bash $SCRIPT_DIR/scripts/core/startup.sh )|& tee startup.log
      source $CONFIGS_DIR/setup.conf
    ( bash $SCRIPT_DIR/scripts/core/0-preinstall.sh )|& tee 0-preinstall.log
    ( arch-chroot /mnt $HOME/ArchTitus/scripts/core/1-setup.sh )|& tee 1-setup.log
    if [[ ! $DESKTOP_ENV == server ]]; then
      ( arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- /home/$USERNAME/ArchTitus/scripts/core/2-user.sh )|& tee 2-user.log
      # Apply Exanor theming
      cp $SCRIPT_DIR/exanor.sh /mnt/home/$USERNAME/ArchTitus/exanor.sh
      chmod +x /mnt/home/$USERNAME/ArchTitus/exanor.sh
      # ( arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- /home/$USERNAME/ArchTitus/exanor.sh )|& tee exanor.log
    fi
    # ( arch-chroot /mnt $HOME/ArchTitus/scripts/core/3-post-setup.sh )|& tee 3-post-setup.log
    echo "
    -------------------------------------------------------------------------
      IMPORTANT: Post-Setup & Theming Skipped (Queued)
      Please run the following commands AFTER rebooting and logging in:
      
      1. Configure System:
         sudo ./ArchTitus/scripts/core/3-post-setup.sh
         
      2. Apply Theming (Optional):
         sudo ./ArchTitus/exanor.sh
    -------------------------------------------------------------------------
    "
    cp -v *.log /mnt/home/$USERNAME

echo -ne "
-------------------------------------------------------------------------
        ███████╗██╗  ██╗ █████╗ ███╗   ██╗ ██████╗ ██████╗ 
        ██╔════╝╚██╗██╔╝██╔══██╗████╗  ██║██╔═══██╗██╔══██╗
        █████╗   ╚███╔╝ ███████║██╔██╗ ██║██║   ██║██████╔╝
        ██╔══╝   ██╔██╗ ██╔══██║██║╚██╗██║██║   ██║██╔══██╗
        ███████╗██╔╝ ██╗██║  ██║██║ ╚████║╚██████╔╝██║  ██║
        ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
-------------------------------------------------------------------------
                Done - Please Eject Install Media and Reboot
"
