#!/bin/bash

# Mock files
mkdir -p pkg-files
cat > pkg-files/pacman-pkgs.txt <<EOF
mesa
xorg
--END OF MINIMAL INSTALL--
alsa-plugins
zsh
EOF

mock_pacman() {
    echo "MOCK PACMAN: $@"
}

run_test() {
    INSTALL_TYPE=$1
    echo "Testing with INSTALL_TYPE=$INSTALL_TYPE"

    # Original Logic Simulation
    echo "--- Original Logic ---"
    sed -n '/'$INSTALL_TYPE'/q;p' pkg-files/pacman-pkgs.txt | while read line
    do
        if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
            continue
        fi
        echo "INSTALLING: ${line}"
        mock_pacman -S --noconfirm --needed ${line}
    done

    # New Logic Simulation
    echo "--- New Logic ---"
    pacman_pkgs=()
    while read -r line; do
        if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
            continue
        fi
        [[ -z "$line" ]] && continue
        pacman_pkgs+=("$line")
    done < <(sed -n '/'$INSTALL_TYPE'/q;p' "pkg-files/pacman-pkgs.txt")

    if (( ${#pacman_pkgs[@]} > 0 )); then
        echo "INSTALLING PACKAGES: ${pacman_pkgs[*]}"
        mock_pacman -S --noconfirm --needed "${pacman_pkgs[@]}"
    fi
    echo ""
}

run_test "FULL"
run_test "MINIMAL"
