#!/bin/bash
# =========================================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (C) 2024 Tanav Malhotra
#
# DISCLAIMER:
# THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
# KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR
# IN CONNECTION WITH THE SCRIPT OR THE USE OR OTHER DEALINGS
# IN THE SCRIPT.
# =========================================================

# Check for sudo access
echo "Checking for \`sudo\` access (which may request your password)..."
if [[ $EUID -ne 0 ]]; then
    echo "\`sudo\` access is required. Please run \`sudo !!\`"
    exit 1
else
    echo "\`sudo\` access confirmed. Proceeding..."
    sleep 1
fi

# Decode Base64 encoded string
read -p "Enter Base64 encoded string: " encoded_string
decoded_string=$(echo "$encoded_string" | base64 --decode)
echo "Decoded string: $decoded_string"

# ===========================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (C) 2024 Tanav Malhotra
# ===========================================