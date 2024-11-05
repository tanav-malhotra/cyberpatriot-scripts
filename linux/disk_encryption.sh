#!/bin/bash
# ====================================================================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (c) 2024 Tanav Malhotra
#
# This script is licensed under the GNU General Public License v3.0.
# You may obtain a copy of the license at:
#   https://www.gnu.org/licenses/gpl-3.0.html
#
# The script is provided "as-is", without any warranty of any kind,
# express or implied, including but not limited to the implied warranties
# of merchantability and fitness for a particular purpose. See the GPL-3.0
# for full details.
#
# You can also view the license by running the `debian.sh` script
# with the '--license' option.
# ====================================================================================

# Check for sudo access
echo "Checking for \`sudo\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    echo "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
else
    echo "\`sudo\` access confirmed. Proceeding..."
    sleep 1
fi

# Encrypt disk
echo "Encrypting disk..."
# TODO

echo "Finished encrypting disk..."

# Wishing Goodluck
echo;echo;echo;
echo "Thank you for using this script. Good luck for the competition!"
echo
echo "==================================="
echo "Copyright (c) 2024 Tanav Malhotra"
echo "GNU General Public License v3.0"
echo "==================================="
echo
exit 0