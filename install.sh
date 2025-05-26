#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo." >&2
    exit 1
fi

if [ ! -f "/etc/steamos-release" ]; then
    echo "SteamOS was not detected. Please submit a bug report if this is inaccurate."
    exit 1
fi

BIN_DIR="/root/.local/bin"
UV_PATH="/root/.local/bin/uv"
UV_INSTALL_URL="https://docs.astral.sh/uv/getting-started/installation/"

if [ ! -d "${BIN_DIR}" ]; then
    echo "Creating directory: ${BIN_DIR}"
    mkdir -p "${BIN_DIR}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create directory: ${BIN_DIR}" >&2
        exit 1
    fi
fi

if [ ! -f "${UV_PATH}" ]; then
    echo "Error: ${UV_PATH} does not exist." >&2
    echo "Please install uv by following the instructions in the root session: ${UV_INSTALL_URL}" >&2
    exit 1
fi

UDEV_RULES_FILE="/etc/udev/rules.d/99-disable-steam-input.rules"
UDEV_RULES_CONTENT=$(
    cat <<EOF

# Skip Steam Deck built in controller
KERNEL=="input*", SUBSYSTEM=="input", ENV{ID_INPUT_JOYSTICK}=="1", ENV{PRODUCT}=="*/28de/1205/*", GOTO="sdbd_bypass"

# Skip virtual Xbox 360 controller
KERNEL=="input*", SUBSYSTEM=="input", ENV{ID_INPUT_JOYSTICK}=="1", ENV{PRODUCT}=="*/28de/11ff/*", GOTO="sdbd_bypass"

KERNEL=="input*", SUBSYSTEM=="input", ENV{ID_INPUT_JOYSTICK}=="1", ACTION=="add", RUN+="${UV_PATH} run --script ${BIN_DIR}/sdbd.py inserted %k %E{NAME} %E{PRODUCT}"
KERNEL=="input*", SUBSYSTEM=="input", ENV{ID_INPUT_JOYSTICK}=="1", ACTION=="remove", RUN+="${UV_PATH} run --script ${BIN_DIR}/sdbd.py removed %k %E{NAME} %E{PRODUCT}"

LABEL="sdbd_bypass"
EOF
)

# # Ensure udev rule file exists and contains the correct content
if [ ! -f "${UDEV_RULES_FILE}" ] || ! cmp -s <(echo "${UDEV_RULES_CONTENT}") "${UDEV_RULES_FILE}"; then
    echo "Creating/Updating udev rule file: ${UDEV_RULES_FILE}"
    echo "${UDEV_RULES_CONTENT}" >"${UDEV_RULES_FILE}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to write to ${UDEV_RULES_FILE}." >&2
        exit 1
    fi
else
    echo "Udev rule file ${UDEV_RULES_FILE} is already up to date."
fi

# This is required to persist on SteamOS upgrades
ATOMIC_CONF_FILE="/etc/atomic-update.conf.d/sdbd.conf"
ATOMIC_CONF_CONTENT="/etc/udev/rules.d/99-disable-steam-input.rules"

# Ensure atomic-update.conf.d file exists and contains the correct content
if [ ! -f "${ATOMIC_CONF_FILE}" ] || [ "$(cat "${ATOMIC_CONF_FILE}")" != "${ATOMIC_CONF_CONTENT}" ]; then
    echo "Creating/Updating atomic update config: ${ATOMIC_CONF_FILE}"
    echo "${ATOMIC_CONF_CONTENT}" >"${ATOMIC_CONF_FILE}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to write to ${ATOMIC_CONF_FILE}." >&2
        exit 1
    fi
else
    echo "Atomic update config ${ATOMIC_CONF_FILE} is already up to date."
fi

sdbd_PY_URL="https://raw.githubusercontent.com/nateify/SteamDeck-Builtin-Disabler/refs/heads/main/sdbd.py"
sdbd_PY_PATH="${BIN_DIR}/sdbd.py"

echo "Attempting to download/update ${sdbd_PY_PATH}..."

# We download to a temporary file first, then move it, to avoid a partially downloaded or corrupted script if the download fails.
TEMP_sdbd_PY=$(mktemp)
if curl -fsSL "${sdbd_PY_URL}" -o "${TEMP_sdbd_PY}"; then
    # Check if the downloaded file is different from the existing one or if the existing one doesn't exist
    if [ ! -f "${sdbd_PY_PATH}" ] || ! cmp -s "${TEMP_sdbd_PY}" "${sdbd_PY_PATH}"; then
        echo "Updating ${sdbd_PY_PATH}."
        mv "${TEMP_sdbd_PY}" "${sdbd_PY_PATH}"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to move downloaded script to ${sdbd_PY_PATH}." >&2
            rm -f "${TEMP_sdbd_PY}" # Clean up temp file
            exit 1
        fi
        echo "Setting execute permissions for ${sdbd_PY_PATH}."
        chmod +x "${sdbd_PY_PATH}"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to set execute permissions for ${sdbd_PY_PATH}." >&2
            exit 1
        fi
    else
        echo "${sdbd_PY_PATH} is already up to date."
        rm -f "${TEMP_sdbd_PY}" # Clean up temp file
        # Ensure it's executable even if it's up to date
        if [ ! -x "${sdbd_PY_PATH}" ]; then
            echo "Setting execute permissions for existing ${sdbd_PY_PATH}."
            chmod +x "${sdbd_PY_PATH}"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to set execute permissions for ${sdbd_PY_PATH}." >&2
                exit 1
            fi
        fi
    fi
else
    echo "Error: Failed to download sdbd.py from ${sdbd_PY_URL}." >&2
    echo "Please check your internet connection and the URL." >&2
    rm -f "${TEMP_sdbd_PY}" # Clean up temp file
    # Do not exit if the file already exists
    if [ ! -f "${sdbd_PY_PATH}" ]; then
        exit 1
    fi
fi

echo "Reloading udev rules..."
udevadm control --reload
if [ $? -ne 0 ]; then
    echo "Warning: udevadm control --reload failed. A reboot might be required for changes to take effect." >&2
else
    echo "Udev rules reloaded successfully."
fi

echo ""
echo "Script finished."

exit 0
