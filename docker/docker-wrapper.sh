#!/bin/bash

# Leverages the ansible-role to create and tear down USB Gadget
# devices and lifts them up into the container for tinypilot
# to use.

# Exit on first error.
set -e

# Echo commands to stdout.
set -x

# Treat undefined environment variables as errors.
set -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
readonly TINYPILOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DEVICE_DIR="${TINYPILOT_DIR}/devices"

# Usage: mk_dev_in_docker "${FUNC_NAME}" "VAR_NAME_FOR_DEVICE_PATH"
mk_dev_in_docker() {
  local -
  set +u
  local _CFG_DEV_PATH="${USB_DEVICE_PATH}/${USB_CONFIG_DIR}/$1/dev"
  if [[ -f "${_CFG_DEV_PATH}" ]]; then
    # shellcheck disable=SC2207 # Splitting into array is what we want.
    local _DEV_VER=($(awk -F ":" '{print $1, $2}' "${_CFG_DEV_PATH}"))
    mkdir -p "${DEVICE_DIR}"
    local _DEV_PATH="${DEVICE_DIR}/$1"
    mknod "${_DEV_PATH}" c "${_DEV_VER[0]}" "${_DEV_VER[1]}"
    chmod 777 "${_DEV_PATH}"
  fi
  eval "$2=${_DEV_PATH:-/dev/null}"
}

print_help() {
  cat << EOF
Usage: ${0##*/} [-r] [-n|--no-init] [-h|--help]
Run Tinypilot in container.
  -n: Do not create or destroy USB Gadgets on the host. Only
        lift them ito the container.
  -h: Display this help and exit.
EOF
}

cleanup() {
  echo "Cleaning up Tinypilot container..."

  if [[ -z "${SKIP_INIT}" ]]; then
    # Make sure there aren't any gadget residuals left over on the host.
    "${TINYPILOT_DIR}/ansible-role/files/remove-usb-gadget"
  fi

  # Finally, remove any device nodes that may have been created in case
  # they exist on a volume that will live longer than this container.
  find "${DEVICE_DIR}" -type c -delete
}
trap cleanup SIGTERM SIGHUP SIGINT EXIT

# Read in command line arguments
SKIP_INIT=
while [[ $# -gt 0 ]]>/dev/null; do
  case $1 in
    -n|--no-init)
      SKIP_INIT=1
      shift # past argument
      ;;
    -h|--help)
      print_help
      exit
      ;;
    *)
      print_help >&2
      exit 1
      ;;
  esac
done


if [[ -z "${SKIP_INIT}" ]]; then
  # First make sure there aren't any gadget residuals around to interfere
  "${TINYPILOT_DIR}/ansible-role/files/remove-usb-gadget"

  # Create the gadget
  "${TINYPILOT_DIR}/ansible-role/files/init-usb-gadget"
fi

# Get the configuration variables for the devices just created
# shellcheck disable=SC1090
. "${TINYPILOT_DIR}/ansible-role/files/lib/usb-gadget.sh"

# Lift the gadget devices into the docker container
# shellcheck disable=SC2086 # We control these variables. We don't need any more quotes.
mk_dev_in_docker "$(awk -F/ '{print $NF}' <<< ${USB_KEYBOARD_FUNCTIONS_DIR})" "KEYBOARD_PATH"
# shellcheck disable=SC2086
mk_dev_in_docker "$(awk -F/ '{print $NF}' <<< ${USB_MOUSE_FUNCTIONS_DIR})" "MOUSE_PATH"
# shellcheck disable=SC2086
mk_dev_in_docker "$(awk -F/ '{print $NF}' <<< ${USB_MOUSE_REL_FUNCTIONS_DIR})" "RELATIVE_MOUSE_PATH"
# shellcheck disable=SC2086
mk_dev_in_docker "$(awk -F/ '{print $NF}' <<< ${USB_MASS_STORAGE_NAME})" "STORAGE_PATH"

# Write out the config file
APP_SETTINGS_FILE="${TINYPILOT_DIR}/app_settings.cfg"
# shellcheck disable=SC2086 # Quotes are in fact being applied.
echo KEYBOARD_PATH = \'${KEYBOARD_PATH}\'>"${APP_SETTINGS_FILE}"
# shellcheck disable=SC2086
echo MOUSE_PATH = \'${MOUSE_PATH}\'>>"${APP_SETTINGS_FILE}"
# shellcheck disable=SC2086
echo RELATIVE_MOUSE_PATH = \'${RELATIVE_MOUSE_PATH}\'>>"${APP_SETTINGS_FILE}"
#echo MASS_STORAGE_PATH = \'${MASS_STORAGE_PATH}\'>>"${APP_SETTINGS_FILE}"

# Start Tinypilot - Wait for stop signal
python "${TINYPILOT_DIR}/app/main.py" &
wait $!
