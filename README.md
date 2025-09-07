# Debian Made up for Raspberry Pi
"Debian Made up for Raspberry Pi" is a set of scripts that simplifies and automates the process of building a complete and bootable Debian image for the Raspberry Pi SBCs.
 
The goal of this project is to build a headless and generic Debian image with the Kernel version of your choice. By default, it uses a recent one. You can configure the kernel if needed.
 
All of the Raspberry Pi architectures should be supported. Concerning Debian, the lastet release ( Trixie ) still supports arm architectures, but only for upgrades ( https://www.debian.org/releases/trixie/ ). 

It's also possible to build an Ubuntu image but, you will have to dig the code. My project is focused on Debian above all.

usage :
```bash
main.sh -R <Raspberry pi Hardware (RPi5|RPi4|RPi3|RPi2|RPi1)> [opt][-a <arch (aarch64|armhf)> -c <enable kernel conf> -x <enable img compression>]
```

