# Virtual Screen Enabling Script

## Description

This script manages virtual screens in a multi-display setup using `xrandr`. It extracts and processes information from the DRM subsystem via `drm_info` and updates configuration files in JSON format with details of the connected screens.

The script performs dynamic checks and updates the configuration based on the available screens, connectors, and cards.

### Key Features

- Automatically detects and enables virtual screens based on a predefined configuration.
- Updates screen information using `xrandr` and `drm_info`.
- Writes details of each enabled screen (including CRTC IDs and plane IDs) to a JSON file for further use.
- Clears and regenerates output configuration files with each run.

## Prerequisites

The following tools are required to run this script:

- **bash**: Command-line interpreter.
- **xrandr**: Utility to manage screen output in X server.
- **jq**: JSON processing utility.
- **drm_info**: Command-line tool to retrieve detailed information about DRM (Direct Rendering Manager) devices.

**IMPORTANT**:  
This script is designed for **Arch Linux** and has only been tested on **Arch Linux**.

## Usage Instructions

### Configuration

1. Create a Zaphodhead configuration for xorg (e.g., `zaphodhead-xorg.conf`).
2. Place the `zaphodhead-xorg.conf` file into `/etc/X11/xorg.conf.d/`.  
   Make sure to rename it to `xorg.conf`.

### Troubleshooting

If your display manager does not start with this `xorg.conf`, you may need to remove the configuration file.  
To do this:

1. Reboot your system and press `Ctrl+Alt+F2` to enter tty mode (a text-based terminal).
2. Log in to your system.
3. Navigate to `/etc/X11/xorg.conf.d/` and delete the `xorg.conf` file.

## Known Issues

### GPU Detection Problem

One of the issues encountered is that the GPU is sometimes detected as `/dev/dri/card1` instead of `/dev/dri/card0`, which prevents screens from initializing properly. None of the driver versions, including specifying modules like `amdgpu` and `radeon`, could solve this issue. 

Here is the ticket and solution I found: [Arch Linux Forum Discussion](https://bbs.archlinux.org/viewtopic.php?id=288578). The solution involves adding the kernel parameter:

```bash
initcall_blacklist=simpledrm_platform_driver_init
