#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "pyudev<1",
# ]
# ///
import logging
import sys
import warnings
from pathlib import Path

import pyudev

warnings.filterwarnings("ignore", category=DeprecationWarning) # For pyudev


def init_logger(file_path):
    logger = logging.getLogger("sdbd")
    logger.setLevel(logging.INFO)

    formatter = logging.Formatter(fmt="%(asctime)s %(message)s", datefmt="%Y-%m-%dT%H:%M:%S")

    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setFormatter(formatter)

    file_handler = logging.FileHandler(file_path)
    file_handler.setFormatter(formatter)

    logger.addHandler(stdout_handler)
    logger.addHandler(file_handler)

    return logger


def get_external_joysticks():
    external_joysticks = []
    context = pyudev.Context()

    for device in context.list_devices(subsystem="input", ID_INPUT_JOYSTICK="1"):
        if device.parent and device.parent.properties.get("SUBSYSTEM") == "input":
            # Ignore child input devices
            continue

        vendor_id = device.properties.get("ID_VENDOR_ID")

        if not vendor_id:
            product_str = device.properties.get("PRODUCT")
            if product_str:
                parts = product_str.split("/")
                if len(parts) == 4:
                    vendor_id = parts[1]

        if vendor_id and vendor_id.lower() != VALVE_VENDOR_ID:
            joystick_info = {
                "name": device.properties.get("NAME", device.sys_name),
                "product_id": device.properties.get("PRODUCT"),
            }
            external_joysticks.append(joystick_info)

    return external_joysticks


def test_steam_input_bound():
    if not USB_HID_DRIVER_PATH.is_dir():
        return False

    return all((USB_HID_DRIVER_PATH / path_suffix).exists() for path_suffix in STEAM_DECK_USB_PATHS)


def modify_steam_deck_usb_hid(usb_hid_path, log):
    failures = 0
    num_paths = len(STEAM_DECK_USB_PATHS)

    for path_suffix in STEAM_DECK_USB_PATHS:
        try:
            with open(usb_hid_path, "w", encoding="utf-8") as f:
                f.write(path_suffix)
        except OSError as e:
            log.error(f"ERROR: Failed to write {usb_hid_path}/{path_suffix}: {e}")
            failures += 1

    if num_paths > 0 and failures == num_paths:
        log.info("WARN: Exiting without changing Steam Deck USB HID state")
        sys.exit(1)


# Logging constants
TMP_BASE_DIR = Path("/tmp/nateify/sdbd")
DEBUG_LOG_FILE = TMP_BASE_DIR / "debug.log"

# USB constants
VALVE_VENDOR_ID = "28de"
STEAM_DECK_USB_PATHS = ["3-3:1.0", "3-3:1.1", "3-3:1.2"]
USB_HID_DRIVER_PATH = Path("/sys/bus/usb/drivers/usbhid")
USB_HID_UNBIND_PATH = USB_HID_DRIVER_PATH / "unbind"
USB_HID_BIND_PATH = USB_HID_DRIVER_PATH / "bind"

def main():
    action_type = sys.argv[1]
    kernel_name = sys.argv[2]
    device_name_attr = sys.argv[3]
    product_info_attr = sys.argv[4]

    TMP_BASE_DIR.mkdir(parents=True, exist_ok=True)

    log = init_logger(DEBUG_LOG_FILE)

    log.info(f"{action_type.upper()}: {kernel_name} - {product_info_attr} - {device_name_attr}")

    if action_type == "inserted":
        if test_steam_input_bound():
            log.info("Steam Deck controller is bound, attempting to unbind")
            modify_steam_deck_usb_hid(USB_HID_UNBIND_PATH, log)
            log.info("Steam Deck controller is unbound")
        else:
            log.info("Steam Deck controller is already unbound, exiting")
            sys.exit(0)
    elif action_type == "removed":
        if test_steam_input_bound():
            log.info("Steam Deck controller is already bound, exiting")
            sys.exit(0)
        else:
            active_gamepads = get_external_joysticks()
            if len(active_gamepads) > 0:
                log.info(f"Will not bind Steam Deck controller, {len(active_gamepads)} gamepad(s) still connected:")
                for gamepad in active_gamepads:
                    log.info(f"{gamepad['product_id']} - {gamepad['name']}")
            else:
                log.info("No other active external gamepads, attempting to bind Steam Deck controller")
                modify_steam_deck_usb_hid(USB_HID_BIND_PATH, log)
                log.info("Steam Deck controller is bound")


if __name__ == "__main__":
    main()
