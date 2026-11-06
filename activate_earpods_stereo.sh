#!/bin/bash
echo "Deactivating Spatial Audio..."
echo "Routing sound directly to EarPods in standard Flat Stereo mode."

EARPODS="alsa_output.usb-Apple__Inc._EarPods_GRYP3W2Y73-00.analog-stereo"
pactl set-default-sink "$EARPODS"

# Move any active apps back to the physical EarPods
for app in $(pactl list sink-inputs short | awk '{print $1}'); do
    pactl move-sink-input "$app" "$EARPODS" 2>/dev/null || true
done
