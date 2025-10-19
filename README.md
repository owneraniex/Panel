# 🚀 Pterodactyl Installer Script 🚀

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![OS](https://img.shields.io/badge/OS-Linux-green.svg)

This script automates the installation of the [Pterodactyl Panel](https://pterodactyl.io/) and its [Wings](https://pterodactyl.io/wings/1.0/installing.html) daemon on a fresh server. It is designed to be easy to use and to get you up and running with Pterodactyl as quickly as possible.

## 💻 Supported Operating Systems

*   🐧 Debian 10/11
*   🐧 Ubuntu 20.04/22.04
*   🐧 CentOS 7/8

## ✨ Features

*   ✅ Installs Pterodactyl Panel and/or Wings
*   ✅ Automatically detects the operating system
*   ✅ Installs all required dependencies, including Nginx, PHP, Redis, and Docker
*   ✅ Configures the Pterodactyl Panel and Wings
*   ✅ Sets up systemd services for the queue listener and Wings
*   ✅ Interactive, menu-driven installation process

##  prerequisites

*    FRESH, clean server running one of the supported operating systems.
*   🔐 Root access to the server.

## 🚀 Usage

To run the script, you can use the following command:

```bash
curl -s https://raw.githubusercontent.com/owneraniex/Panel/main/install.sh | sudo bash
```

The script will guide you through the installation process. You will be prompted to choose what you want to install (Panel, Wings, or both) and to provide some information, such as a database password.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/owneraniex/Panel/issues).

## 📜 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## ⚠️ Disclaimer

This script is provided as-is and without any warranty. Use it at your own risk. It is always recommended to back up your data before running any script that makes changes to your system.
