#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "pyudev<1",
# ]
# ///
import warnings

import pyudev

warnings.filterwarnings("ignore", category=DeprecationWarning)


def find_steam_deck_controller_usb_paths():
    context = pyudev.Context()
    found_paths = []

    target_product_name = "Steam Deck Controller"

    # Iterate over all USB interfaces
    for interface_device in context.list_devices(subsystem="usb", DEVTYPE="usb_interface"):
        if interface_device.properties.get("DRIVER") != "usbhid":
            continue

        parent_device = interface_device.find_parent(subsystem="usb", device_type="usb_device")

        if parent_device:
            # Get the 'product' attribute from the parent device
            product_attr_bytes = parent_device.attributes.get("product")

            if product_attr_bytes:
                try:
                    product_name = product_attr_bytes.decode("utf-8", errors="ignore")
                    if product_name == target_product_name:
                        found_paths.append(interface_device.sys_name)
                except AttributeError:
                    pass

    return sorted(set(found_paths))


print(find_steam_deck_controller_usb_paths())
