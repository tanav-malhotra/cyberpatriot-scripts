#!/bin/bash
# =========================================================
# Author: Tanav Malhotra
# License: GNU General Public License v3.0
# Copyright (c) 2024 Tanav Malhotra
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

RESOLUTION="1920x1080"
OUTPUT=$(xrandr | grep " connected" | awk '{ print $1 }')
AVAILABLE_RESOLUTIONS=$(xrandr | grep "$OUTPUT" -A 10 | grep -oP "\d+x\d+")
if echo "$AVAILABLE_RESOLUTIONS" | grep -q "$RESOLUTION"; then
    echo "Resolution $RESOLUTION is already available. Applying it..."
    xrandr -s $RESOLUTION
else
    echo "Resolution $RESOLUTION is not available. Adding it now..."
    MODELINE=$(cvt 1920 1080 60 | grep -oP 'Modeline.*')
    xrandr --newmode $MODELINE
    xrandr --addmode "$OUTPUT" "$RESOLUTION"
    echo "Applying resolution $RESOLUTION..."
    xrandr -s $RESOLUTION
fi

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