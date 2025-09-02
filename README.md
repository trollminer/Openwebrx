OpenWebRX+ Installer

A menu-driven Bash installer for OpenWebRX+
 and its optional decoders.
This script provides a dashboard, status tracking, and easy one-click installs of additional modules not bundled with OpenWebRX+.

✨ Features

Installs OpenWebRX+ with supported repositories

Interactive dashboard + menu for managing installs

One-click full installation (all modules) or selective installs

Support for adding OpenWebRX web users

Auto-handles dependencies and service restarts

Logs everything to /var/log/openwebrx_install.log

🖥️ Supported Systems

Ubuntu: Jammy (22.04), Noble (24.04)

Debian: Bullseye (11), Bookworm (12)

⚠️ Other distributions are not supported by this script.

📦 Modules Supported

OpenWebRX+ (base)

MBELib

CodecServer-SoftMBE

SatDump + NNG

LiquidDSP

Libacars

Dumphfdl

Dumpvdl2

Codec2 / FreeDV_RX

M17-cxx-demod

Dump1090

MSK144Decoder

Dream

APRS Symbols

Each module has its own install routine and tracked status (SUCCESS, FAILED, etc).

🚀 Installation

Clone this repo and run the installer:

git clone https://github.com/trollminer/Openwebrx.git

cd Openwebrx

chmod +x openwebrx.sh

./openwebrx.sh


The script will create a log at:

/var/log/openwebrx_install.log

📋 Menu Options

When you run the script, you’ll see a dashboard and menu.

1 → Install OpenWebRX+ only

2 → Full install (all modules)

3–12 → Install individual modules

13 → Start/Restart services

14 → Add an OpenWebRX user

15 → Show inline README

16 → Exit

🌐 Access

Once installed, OpenWebRX+ will be available at:

http://your-server-ip:8073


Use the user created in option 14 to access the settings panel.

📄 Logs

All installation steps are logged at:

/var/log/openwebrx_install.log

🤝 Contributing

Pull requests and improvements are welcome!

If you encounter issues, please open an issue
.

📜 License

MIT License – feel free to use, modify, and share.
