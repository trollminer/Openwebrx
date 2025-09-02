#!/bin/bash
set -eo pipefail

#========================
# Color Codes
#========================
RED=$'\033[31m'
BOLD=$'\033[1m'
GREEN='\033[0;32m'
GRAY=$'\033[90m'
YELLOW=$'\033[33m'
NC=$'\033[0m'
#========================
# Log File
#========================
LOG_FILE="/var/log/openwebrx_install.log"
touch "$LOG_FILE" || { echo "Cannot create log file at $LOG_FILE. Exiting."; exit 1; }
exec > >(tee -a "$LOG_FILE") 2>&1

#========================
# Logging
#========================
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

#========================
# Ask for sudo
#========================
sudo -v || { log "Sudo required. Exiting."; exit 1; }

#========================
# Noninteractive apt
#========================
export DEBIAN_FRONTEND=noninteractive
APT_INSTALL="sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold install"

#========================
# Modules & Status
#========================
modules=("OpenWebRX+" "MBELib" "CodecServer-SoftMBE" "SatDump + NNG" "LiquidDSP" "Libcars" "Dumphfdl" "Dumpvdl2" "Codec2 / FreeDV_RX" "M17-cxx-demod" "Dump1090" "MSK144Decoder" "Dream" "APRS Symbols" "OpenWebRX User")
declare -A status
for mod in "${modules[@]}"; do status["$mod"]="NOT BUILT" status["OpenWebRX User"]="NOT ADDED"; done

#========================
# Helpers
#========================
set_status() {
    local module="$1"
    local new_status="$2"
    status["$module"]="$new_status"
    echo -e "${YELLOW}[$module] Status: $new_status${NC}"
}

restart_services() {
    log "Restarting OpenWebRX+ service..."
    sudo systemctl daemon-reload || true
    sudo systemctl enable openwebrx || true
    sudo systemctl restart openwebrx || true
    log "Restarting Codecserver service..."
    sudo systemctl enable codecserver || true
    sudo systemctl restart codecserver || true
}

#========================
# Dashboard/Menu
#========================
show_banner() {
    banner_lines=(
"   ___                __        __   _     ____  __  __     "
"  / _ \\ _ __   ___ _ _\\ \\      / /__| |__ |  _ \\ \\ \\/ / _   "
" | | | | '_ \\ / _ \\ '_ \\ \\ /\\ / / _ \\ '_ \\| |_) | \\  /_| |_ "
" | |_| | |_) |  __/ | | \\ V  V /  __/ |_) |  _ <  /  \\_   _|"
"  \\___/| .__/ \\___|_| |_|\_/\\_/ \\___|_.__/|_| \\_\\/_/\\_\\|_|  "
"       |_|    --- by Trollminer ---"
    )

    for line in "${banner_lines[@]}"; do
        # main banner in bold red
        printf "%*s\n" $(( (${#line} + menu_width) / 2 )) "${BOLD}${RED}${line}${NC}"
    done
}
show_menu() {
    clear

    menu_items=(
        "=== OpenWebRX+ Installer ==="
        "1) OpenWebRX+ Only"
        "2) Full Install (OWRX + all modules)"
        "3) MBELib"
        "4) SatDump"
        "5) dumphfdl"
        "6) dumpvdl2"
        "7) Codec2 / FreeDV_RX"
        "8) m17-cxx-demod"
        "9) Dump1090"
        "10) msk144decoder"
        "11) Dream"
        "12) APRS Symbols"
        "13) Start/Restart Services"
        "14) Add OpenWebRX User"
        "15) Read Me!"
        "16) Exit"
    )

    # detect longest menu line
    menu_width=0
    for item in "${menu_items[@]}"; do
        (( ${#item} > menu_width )) && menu_width=${#item}
    done

    # build dashboard lines (with colors)
    dash_items=()
    dash_items+=("$(printf "${YELLOW}=== Module Status Dashboard: ===${NC}")")
    dash_width=0
    for mod in "${modules[@]}"; do
        s="${status["$mod"]}"
        case "$s" in
            SUCCESS|ADDED*) color=$GREEN ;;
            FAILED) color=$RED ;;
            NOT\ BUILT|IN\ PROGRESS|NOT\ ADDED|NOT\ DONE) color=$YELLOW ;;
            *) color=$NC ;;
        esac
        line="$(printf "%-25s : ${color}%s${NC}" "$mod" "$s")"
        dash_items+=("$line")

        # update width ignoring color codes
        plain_line="$(printf "%-25s : %s" "$mod" "$s")"
        (( ${#plain_line} > dash_width )) && dash_width=${#plain_line}
    done

    # show banner centered over menu
    show_banner

    # print menu + dashboard side by side
    max_lines=${#menu_items[@]}
    if [ ${#dash_items[@]} -gt $max_lines ]; then
        max_lines=${#dash_items[@]}
    fi

    for ((i=0; i<max_lines; i++)); do
        menu_line="${menu_items[i]}"
        dash_line="${dash_items[i]}"
        printf "%-${menu_width}s   %s\n" "$menu_line" "$dash_line"
    done
    echo ""
}
show_summary() {
    echo ""
    echo "========================================="
    echo "        OpenWebRX+ Installation Summary"
    echo "========================================="
    for mod in "${modules[@]}"; do
        printf "%-25s : %s\n" "$mod" "${status["$mod"]}"
    done
    echo "Full logs: $LOG_FILE"
    echo "========================================="
    read -n1 -rsp $'Press any key to continue...\n'
}

#========================
# Module Install Functions
#========================

install_base() {
    set_status "OpenWebRX+" "IN PROGRESS"
    OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    VERSION_CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    OPENWEBRX_REPO_ADDED=false
    case "$OS_ID" in
        ubuntu)
            case "$VERSION_CODENAME" in
                jammy)
                    curl -s https://luarvique.github.io/ppa/openwebrx-plus.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openwebrx-plus.gpg
                    echo "deb [signed-by=/usr/share/keyrings/openwebrx-plus.gpg] https://luarvique.github.io/ppa/ubuntu ./" | sudo tee /etc/apt/sources.list.d/openwebrx-plus.list
                    curl -s https://repo.openwebrx.de/debian/key.gpg.txt | sudo gpg --dearmor -o /usr/share/keyrings/openwebrx.gpg
                    echo "deb [signed-by=/usr/share/keyrings/openwebrx.gpg] https://repo.openwebrx.de/ubuntu/ jammy main" | sudo tee /etc/apt/sources.list.d/openwebrx.list
                    OPENWEBRX_REPO_ADDED=true
                    ;;
                noble)
                    curl -s https://luarvique.github.io/ppa/openwebrx-plus.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openwebrx-plus.gpg
                    echo "deb [signed-by=/usr/share/keyrings/openwebrx-plus.gpg] https://luarvique.github.io/ppa/noble ./" | sudo tee /etc/apt/sources.list.d/openwebrx-plus.list
                    OPENWEBRX_REPO_ADDED=true
                    ;;
                *) log "Unsupported Ubuntu version"; set_status "Base OpenWebRX+" "FAILED"; return ;;
            esac ;;
        debian)
            case "$VERSION_CODENAME" in
                bullseye)
                    curl -s https://luarvique.github.io/ppa/openwebrx-plus.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openwebrx-plus.gpg
                    echo "deb [signed-by=/usr/share/keyrings/openwebrx-plus.gpg] https://luarvique.github.io/ppa/debian ./" | sudo tee /etc/apt/sources.list.d/openwebrx-plus.list
                    curl -s https://repo.openwebrx.de/debian/key.gpg.txt | sudo gpg --dearmor -o /usr/share/keyrings/openwebrx.gpg
                    echo "deb [signed-by=/usr/share/keyrings/openwebrx.gpg] https://repo.openwebrx.de/debian/ bullseye main" | sudo tee /etc/apt/sources.list.d/openwebrx.list
                    OPENWEBRX_REPO_ADDED=true
                    ;;
                bookworm)
                    curl -s https://luarvique.github.io/ppa/openwebrx-plus.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openwebrx-plus.gpg
                    echo "deb [signed-by=/usr/share/keyrings/openwebrx-plus.gpg] https://luarvique.github.io/ppa/bookworm ./" | sudo tee /etc/apt/sources.list.d/openwebrx-plus.list
                    OPENWEBRX_REPO_ADDED=true
                    ;;
                *) log "Unsupported Debian version"; set_status "Base OpenWebRX+" "FAILED"; return ;;
            esac ;;
        *) log "Unsupported OS"; set_status "Base OpenWebRX+" "FAILED"; return ;;
    esac
    if [ "$OPENWEBRX_REPO_ADDED" = false ]; then
        log "Failed to add repositories"
        set_status "Base OpenWebRX+" "FAILED"
        return
    fi
    if sudo apt update -y && $APT_INSTALL openwebrx; then
        set_status "OpenWebRX+" "SUCCESS"
    else
        set_status "OpenWebRX+" "FAILED"
    fi
}

#========================
# Full Module Implementations
#========================
install_mbelib() {
    set_status "MBELib" "IN PROGRESS"
    $APT_INSTALL git-core debhelper cmake libprotobuf-dev protobuf-compiler libcodecserver-dev
    cd /opt
    [ ! -d mbelib ] && git clone https://github.com/szechyjs/mbelib.git
    cd mbelib
    dpkg-buildpackage
    cd ..
    sudo dpkg -i libmbe1_1.3.0_*.deb libmbe-dev_1.3.0_*.deb
    set_status "MBELib" "SUCCESS"
}

install_codecserver_softmbe() {
    set_status "CodecServer-SoftMBE" "IN PROGRESS"
    cd /opt
    [ ! -d codecserver-softmbe ] && git clone https://github.com/knatterfunker/codecserver-softmbe.git
    cd codecserver-softmbe
    dpkg-buildpackage
    cd ..
    sudo dpkg -i codecserver-driver-softmbe_0.0.1_*.deb
    if ! grep -q "\[device:softmbe\]" /etc/codecserver/codecserver.conf 2>/dev/null; then
        cat >> /etc/codecserver/codecserver.conf << _EOF_
[device:softmbe]
driver=softmbe
_EOF_
        restart_services
    fi
    set_status "CodecServer-SoftMBE" "SUCCESS"
}

install_satdump() {
    set_status "SatDump + NNG" "IN PROGRESS"
    $APT_INSTALL git build-essential cmake g++ pkgconf libfftw3-dev libpng-dev libtiff-dev libjemalloc-dev libcurl4-openssl-dev libvolk-dev libnng-dev libglfw3-dev zenity portaudio19-dev libzstd-dev libhdf5-dev librtlsdr-dev libhackrf-dev libairspy-dev libairspyhf-dev libad9361-dev libiio-dev libbladerf-dev libomp-dev ocl-icd-opencl-dev intel-opencl-icd mesa-opencl-icd
    cd /opt
    [ ! -d nng ] && git clone https://github.com/nanomsg/nng.git -b v1.9.0
    cd nng
    mkdir -p build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/usr ..
    make -j$(nproc)
    sudo make install
    cd /opt
    [ ! -d SatDump ] && git clone https://github.com/SatDump/SatDump.git
    cd SatDump
    mkdir -p build && cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr ..
    make -j$(nproc)
    sudo make install
    set_status "SatDump + NNG" "SUCCESS"
}

install_liquiddsp() {
    set_status "LiquidDSP" "IN PROGRESS"
    cd /opt
    [ ! -d liquid-dsp ] && git clone https://github.com/jgaeddert/liquid-dsp.git
    cd liquid-dsp
    mkdir -p build && cd build
    cmake ..
    make -j$(nproc)
    sudo make install
    set_status "LiquidDSP" "SUCCESS"
}

install_libcars() {
    set_status "Libcars" "IN PROGRESS"
    $APT_INSTALL zlib1g-dev libxml2-dev libjansson-dev
    cd /opt
    [ ! -d libacars ] && git clone https://github.com/szpajder/libacars
    cd libacars
    git checkout unstable
    mkdir -p build && cd build
    cmake ../
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    set_status "Libcars" "SUCCESS"
}

install_dumphfdl() {
    set_status "Dumphfdl" "IN PROGRESS"
    $APT_INSTALL build-essential cmake pkg-config libglib2.0-dev libconfig++-dev libliquid-dev libfftw3-dev
    cd /opt
    [ ! -d dumphfdl ] && git clone --branch devel https://github.com/szpajder/dumphfdl.git
    cd dumphfdl
    mkdir -p build && cd build
    cmake ../
    make
    sudo make install
    set_status "Dumphfdl" "SUCCESS"
}

install_dumpvdl2() {
    set_status "Dumpvdl2" "IN PROGRESS"
    cd /opt
    [ ! -d dumpvdl2 ] && git clone https://github.com/szpajder/dumpvdl2.git
    cd dumpvdl2
    mkdir -p build && cd build
    cmake ../
    make
    sudo make install
    set_status "Dumpvdl2" "SUCCESS"
}

install_codec2() {
    set_status "Codec2 / FreeDV_RX" "IN PROGRESS"
    $APT_INSTALL qt5-qmake libpulse0 libfaad2 libopus0 libpulse-dev libfaad-dev libopus-dev libfftw3-dev wget
    cd /opt
    [ ! -d codec2 ] && git clone https://github.com/drowe67/codec2.git
    cd codec2
    mkdir -p build && cd build
    cmake ..
    make
    sudo make install
    sudo install -m 0755 src/freedv_rx /usr/local/bin
    set_status "Codec2 / FreeDV_RX" "SUCCESS"
}

install_m17() {
    set_status "M17-cxx-demod" "IN PROGRESS"
    $APT_INSTALL libboost-program-options-dev
    cd /opt
    [ ! -d m17-cxx-demod ] && git clone https://github.com/mobilinkd/m17-cxx-demod.git
    cd m17-cxx-demod
    mkdir -p build && cd build
    cmake ..
    make
    sudo make install
    set_status "M17-cxx-demod" "SUCCESS"
}

install_dump1090() {
    set_status "Dump1090" "IN PROGRESS"
    $APT_INSTALL git build-essential libusb-1.0-0-dev librtlsdr-dev pkg-config libncurses-dev
    cd /opt
    [ ! -d dump1090 ] && git clone https://github.com/flightaware/dump1090
    cd dump1090
    make
    sudo install -Dm755 dump1090 /usr/bin/dump1090
    set_status "Dump1090" "SUCCESS"
}

install_msk144decoder() {
    set_status "MSK144Decoder" "IN PROGRESS"
    $APT_INSTALL build-essential cmake gfortran libfftw3-dev libboost-dev libcurl4-openssl-dev
    cd /opt
    [ ! -d msk144decoder ] && git clone https://github.com/alexander-sholohov/msk144decoder.git
    cd msk144decoder
    git submodule init && git submodule update --progress
    mkdir -p build && cd build
    cmake ..
    make
    sudo make install
    set_status "MSK144Decoder" "SUCCESS"
}

install_dream() {
    set_status "Dream" "IN PROGRESS"
    $APT_INSTALL qt5-qmake libpulse0 libfaad2 libopus0 libpulse-dev libfaad-dev libopus-dev libfftw3-dev wget
    cd /opt
    [ ! -f dream-2.1.1-svn808.tar.gz ] && wget https://downloads.sourceforge.net/project/drm/dream/2.1.1/dream-2.1.1-svn808.tar.gz
    tar xvfz dream-2.1.1-svn808.tar.gz
    cd dream
    qmake -qt=qt5 CONFIG+=console
    make
    sudo make install
    set_status "Dream" "SUCCESS"
}

add_openwebrx_user() {
    set_status "OpenWebRX User" "IN PROGRESS"

    read -p "Enter the new OpenWebRX username: " username
    if [ -z "$username" ]; then
        echo "Username cannot be empty!"
        set_status "OpenWebRX User" "NOT ADDED"
        return
    fi

    echo "Adding OpenWebRX user: $username"
    if sudo openwebrx admin adduser "$username"; then
        set_status "OpenWebRX User" "ADDED ($username)"
        log "OpenWebRX user $username added successfully"
    else
        set_status "OpenWebRX User" "FAILED"
        log "Failed to add OpenWebRX user $username"
    fi
}

install_aprs_symbols() {
    set_status "APRS Symbols" "IN PROGRESS"
    cd /opt
    [ ! -d /usr/share/aprs-symbols ] && sudo git clone https://github.com/hessu/aprs-symbols /usr/share/aprs-symbols
    set_status "APRS Symbols" "SUCCESS"
}

show_readme() {
    clear
    echo -e "${BOLD}${YELLOW}=== README ===${NC}"
    echo ""
    echo "${BOLD}${RED}**Only Ubuntu: Jammy/Noble - Debian: Bookworm/Bullseye are supported by this script**${NC}"
    echo ""
    echo "This script provides install options for OWRX+ and its non bundeled decoders"
    echo "aswell as a full OWRX+ System that contains all decoders"
    echo ""
    echo "${BOLD}${RED}The options below are the ones I belive would be most used${NC}"
    echo ""
    echo "1) This will enable the correct repos and then install only OpenWebRX+ and its included decoders"
    echo ""
    echo "2) This will enable to correct repos and install OWRX+ and all decoder listed"
    echo ""
    echo "14) Add a user to access the settings area within OWRX+ web interface"
    echo ""
    echo "Pressing ny other option will install only that decoder and any dependancies it needs"
    echo ""
    echo "Once any actions have been completed you should now be able to use OWRX+ and the decoders chosen"
    echo ""
    echo "You can access OWRX+ at http://IP:8073 and access the settings with the user created by option 14"
    echo ""
    read -p "Press [Enter] to return to menu..."
}
#========================
# Main Loop
#========================
while true; do
    show_menu
    read -p "Enter numbers of modules to install (space separated): " -a choices
    for c in "${choices[@]}"; do
        case $c in
            1) install_base ;;
            2)
                install_base
                install_mbelib
                install_codecserver_softmbe
                install_satdump
                install_liquiddsp
                install_libcars
                install_dumphfdl
                install_dumpvdl2
                install_codec2
                install_m17
                install_dump1090
                install_msk144decoder
                install_dream
                install_aprs_symbols
                restart_services
                ;;
            3) install_mbelib
               install_codecserver_softmbe
                ;;
            4) install_satdump ;;
            5) install_liquiddsp
               install_libcars
               install_dumphfdl 
                ;;
            6) install_liquiddsp
               install_libcars
               install_dumpvdl2
                ;;
            7) install_codec2 ;;
            8) install_m17 ;;
            9) install_dump1090 ;;
            10) install_msk144decoder ;;
            11) install_dream ;;
            12) install_aprs_symbols ;;
            13) restart_services ;;
            14) add_openwebrx_user ;;
            15) show_readme ;;
            16) exit 0 ;;

            *) echo "Invalid choice $c" ;;
        esac
    done
done
