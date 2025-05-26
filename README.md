# SteamDeck-Builtin-Disabler

Automatically disable/enable the built in Steam Deck controller based on the presence of external gamepads.

It is based on the bash script [Steam-Deck.Auto-Disable-Steam-Controller](https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller) by [scawp](https://github.com/scawp), reimplemented in Python to fix some bugs and be more robust.

**Notes:**
- Keyboard and mouse detection is not implemented.

## Supported OS

This script is only on SteamOS 3.7 stable with the included Python 3.13.

## Installation

Requires the [uv](https://docs.astral.sh/uv/) package manager for Python, due to a dependency on [pyudev](https://github.com/pyudev/pyudev).

Because the script runs as root, [uv installation](https://docs.astral.sh/uv/getting-started/installation/) should run as root:

```
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Once uv is installed, the script's own installer can be executed:

```
curl -LsSf https://raw.githubusercontent.com/nateify/SteamDeck-Builtin-Disabler/refs/heads/main/install.sh | bash
```

## How It Works

The installer script will download sdbd.py from this repo into `/root/.local/bin/` and make it
executable.

It will create two udev rules for the addition and removal of input devices where `ID_INPUT_JOYSTICK=1`, and skips the built-in Steam Deck controls (to prevent causing a loop).

When the script is executed:

- On gamepad addition, the Steam Deck's `usbhid` devices are unbound, disabling them.
- On gamepad removal, checks if any other external gamepad are still connected. If so, Steam Deck controls remain disabled.
- If a gamepad is removed an no external gamepads remain, the internal controls are enabled.

## Tested Controllers

Detection of a device as a gamepad is determined by udev.

Tested by me:

- 8BitDo Retro Receiver
- 8BitDo SN30 Pro+ (Wired and Bluetooth)
- Retro-Bit Sega Saturn USB Controller

Additional testing from the original repo: https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller?tab=readme-ov-file#currently-works-with

## Troubleshooting

The script logs events to `/tmp/nateify/sdbd/debug.log`

## Uninstallation

```
sudo rm -f /etc/udev/rules.d/99-disable-steam-input.rules
sudo rm -f /etc/atomic-update.conf.d/sdbd.conf
sudo rm -f /root/.local/bin/sdbd.py
sudo udevadm control --reload
```
