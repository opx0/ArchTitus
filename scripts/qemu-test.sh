#!/usr/bin/env bash
# @file QEMU Test Environment
# @brief Launch ArchTitus in a QEMU VM for testing

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VM_DIR="$REPO_ROOT/.vm"

# VM Configuration
VM_DISK="$VM_DIR/arch-test.qcow2"
VM_DISK_SIZE="40G"
VM_RAM="4G"
VM_CPUS="4"
ISO_PATH="$VM_DIR/archlinux.iso"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -------------------------------------------------------------------------
# 1. Setup VM Directory
# -------------------------------------------------------------------------
setup_vm_dir() {
    echo_info "Setting up VM directory..."
    mkdir -p "$VM_DIR"
    
    # Add to gitignore if not already there
    if [[ -f "$REPO_ROOT/.gitignore" ]] && ! grep -q "^\.vm$" "$REPO_ROOT/.gitignore"; then
        echo ".vm" >> "$REPO_ROOT/.gitignore"
        echo_info "Added .vm to .gitignore"
    fi
}

# -------------------------------------------------------------------------
# 2. Download Arch ISO
# -------------------------------------------------------------------------
download_iso() {
    if [[ -f "$ISO_PATH" ]]; then
        echo_info "Arch ISO already exists at $ISO_PATH"
        return 0
    fi
    
    echo_info "Downloading latest Arch Linux ISO..."
    
    # Get latest ISO URL from Arch mirror
    local MIRROR="https://geo.mirror.pkgbuild.com/iso/latest"
    local ISO_NAME=$(curl -s "$MIRROR/" | grep -oP 'archlinux-\d{4}\.\d{2}\.\d{2}-x86_64\.iso' | head -1)
    
    if [[ -z "$ISO_NAME" ]]; then
        echo_error "Could not find latest Arch ISO. Please download manually to: $ISO_PATH"
        echo "       Visit: https://archlinux.org/download/"
        exit 1
    fi
    
    echo_info "Downloading $ISO_NAME..."
    curl -L -o "$ISO_PATH" "$MIRROR/$ISO_NAME" --progress-bar
    
    echo_info "ISO downloaded to $ISO_PATH"
}

# -------------------------------------------------------------------------
# 3. Create Virtual Disk
# -------------------------------------------------------------------------
create_disk() {
    if [[ -f "$VM_DISK" ]]; then
        echo_warn "VM disk already exists: $VM_DISK"
        read -p "Delete and recreate? [y/N]: " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            rm -f "$VM_DISK"
        else
            return 0
        fi
    fi
    
    echo_info "Creating $VM_DISK_SIZE virtual disk..."
    qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"
}

# -------------------------------------------------------------------------
# 4. Create UEFI Vars (for UEFI boot)
# -------------------------------------------------------------------------
setup_uefi() {
    local OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.fd"
    local OVMF_VARS="/usr/share/edk2/x64/OVMF_VARS.fd"
    local VM_VARS="$VM_DIR/OVMF_VARS.fd"
    
    # Check for OVMF
    if [[ ! -f "$OVMF_CODE" ]]; then
        # Try alternative paths
        for path in /usr/share/ovmf/x64/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd; do
            if [[ -f "$path" ]]; then
                OVMF_CODE="$path"
                OVMF_VARS="${path/CODE/VARS}"
                break
            fi
        done
    fi
    
    if [[ ! -f "$OVMF_CODE" ]]; then
        echo_warn "OVMF not found. Install with: sudo pacman -S edk2-ovmf"
        echo_warn "Falling back to BIOS boot..."
        UEFI_ARGS=""
        return 0
    fi
    
    # Copy OVMF_VARS if not exists
    if [[ ! -f "$VM_VARS" ]]; then
        cp "$OVMF_VARS" "$VM_VARS"
    fi
    
    UEFI_ARGS="-drive if=pflash,format=raw,readonly=on,file=$OVMF_CODE -drive if=pflash,format=raw,file=$VM_VARS"
    echo_info "UEFI boot enabled"
}

# -------------------------------------------------------------------------
# 5. Share ArchTitus repo with VM
# -------------------------------------------------------------------------
# We'll use 9p virtio filesystem to share the repo

# -------------------------------------------------------------------------
# 6. Launch QEMU
# -------------------------------------------------------------------------
launch_vm() {
    local boot_args=""
    
    # Boot from ISO if disk is empty/fresh
    if [[ -f "$ISO_PATH" ]]; then
        echo_info "Booting from ISO: $ISO_PATH"
        boot_args="-cdrom $ISO_PATH -boot d"
    fi
    
    echo_info "Launching QEMU VM..."
    echo "-------------------------------------------------------------------------"
    echo "  VM Settings:"
    echo "    RAM:    $VM_RAM"
    echo "    CPUs:   $VM_CPUS"
    echo "    Disk:   $VM_DISK"
    echo "    Share:  $REPO_ROOT (mount in VM: mount -t 9p -o trans=virtio host0 /mnt/archtitus)"
    echo "-------------------------------------------------------------------------"
    echo ""
    echo "Once Arch boots, run these commands to test:"
    echo "  mkdir -p /mnt/archtitus"
    echo "  mount -t 9p -o trans=virtio host0 /mnt/archtitus"
    echo "  cd /mnt/archtitus && ./baseos-setup.sh"
    echo ""
    echo "Press Ctrl+Alt+G to release mouse from VM"
    echo "-------------------------------------------------------------------------"
    
    # Launch with shared folder
    qemu-system-x86_64 \
        -enable-kvm \
        -m "$VM_RAM" \
        -smp "$VM_CPUS" \
        -cpu host \
        -drive file="$VM_DISK",format=qcow2,if=virtio \
        $boot_args \
        $UEFI_ARGS \
        -virtfs local,path="$REPO_ROOT",mount_tag=host0,security_model=mapped-xattr,id=host0 \
        -netdev user,id=net0 \
        -device virtio-net-pci,netdev=net0 \
        -device virtio-vga-gl \
        -display gtk,gl=on \
        -device usb-ehci \
        -device usb-tablet \
        -device intel-hda \
        -device hda-duplex \
        -name "ArchTitus Test VM"
}

# -------------------------------------------------------------------------
# 7. Main Menu
# -------------------------------------------------------------------------
show_menu() {
    echo "==========================================================================="
    echo "                    ArchTitus QEMU Test Environment"
    echo "==========================================================================="
    echo ""
    echo "  1) Full Setup (download ISO + create disk + launch)"
    echo "  2) Launch VM (existing setup)"
    echo "  3) Download Arch ISO only"
    echo "  4) Create/Reset virtual disk"
    echo "  5) Launch from existing ISO (specify path)"
    echo "  q) Quit"
    echo ""
    read -p "Select option [1-5, q]: " choice
    
    case "$choice" in
        1)
            setup_vm_dir
            download_iso
            create_disk
            setup_uefi
            launch_vm
            ;;
        2)
            setup_uefi
            launch_vm
            ;;
        3)
            setup_vm_dir
            download_iso
            ;;
        4)
            setup_vm_dir
            create_disk
            ;;
        5)
            read -p "Enter ISO path: " custom_iso
            if [[ -f "$custom_iso" ]]; then
                ISO_PATH="$custom_iso"
                setup_vm_dir
                create_disk
                setup_uefi
                launch_vm
            else
                echo_error "ISO not found: $custom_iso"
                exit 1
            fi
            ;;
        q|Q)
            exit 0
            ;;
        *)
            echo_error "Invalid option"
            exit 1
            ;;
    esac
}

# Handle command line args
case "${1:-}" in
    --launch|-l)
        setup_uefi
        launch_vm
        ;;
    --setup|-s)
        setup_vm_dir
        download_iso
        create_disk
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --launch, -l    Launch VM directly (must have setup already)"
        echo "  --setup, -s     Setup only (download ISO, create disk)"
        echo "  --help, -h      Show this help"
        echo ""
        echo "Run without options for interactive menu."
        ;;
    *)
        show_menu
        ;;
esac
