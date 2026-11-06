#!/bin/bash
echo "Finding EPOS EXPAND 30 USB speaker sinks..."

# Get all running or suspended PipeWire/PulseAudio sinks matching EPOS_EXPAND_30
SINKS=$(pactl list sinks short | awk '{print $2}' | grep "EPOS_EXPAND_30")

if [ -z "$SINKS" ]; then
    echo "No EPOS EXPAND 30 speakers found."
    exit 1
fi

echo "Found the following speakers:"
echo "$SINKS"

echo "Creating virtual combined sink..."

# Check if it already exists and unload it
MODULE_ID=$(pactl list modules short | grep "module-null-sink" | grep "combined_4_speakers" | awk '{print $1}')
if [ ! -z "$MODULE_ID" ]; then
    echo "Unloading existing virtual sink (Module ID: $MODULE_ID)..."
    pactl unload-module "$MODULE_ID"
fi
MODULE_ID=$(pactl list modules short | grep "module-combine-sink" | grep "combined_4_speakers" | awk '{print $1}')
if [ ! -z "$MODULE_ID" ]; then
    echo "Unloading existing combined sink (Module ID: $MODULE_ID)..."
    pactl unload-module "$MODULE_ID"
fi

# Load the virtual null sink
NEW_MODULE_ID=$(pactl load-module module-null-sink sink_name=combined_4_speakers sink_properties=device.description="Combined_4_EPOS_Speakers")

if [ $? -eq 0 ]; then
    echo "Successfully created virtual sink (Module ID: $NEW_MODULE_ID)."
    
    echo "Linking physical speakers to the virtual sink..."
    # Small delay to ensure PipeWire creates the nodes
    sleep 1
    
    for sink in $SINKS; do
        # Link Left and Right channels
        pw-link combined_4_speakers:monitor_FL ${sink}:playback_FL 2>/dev/null
        pw-link combined_4_speakers:monitor_FR ${sink}:playback_FR 2>/dev/null
    done
    
    # Set as default
    pactl set-default-sink combined_4_speakers
    echo "Set combined sink as default output."
    
    # Unmute and set volume to 100% for the combined sink and all individual sinks
    pactl set-sink-mute combined_4_speakers 0
    pactl set-sink-volume combined_4_speakers 100%
    
    for s in $SINKS; do
        pactl set-sink-mute "$s" 0
        pactl set-sink-volume "$s" 100%
    done
    
    echo "Unmuted and set volume to 100% on all speakers."
    echo "Audio should now play out of all connected EPOS EXPAND 30 speakers simultaneously!"
else
    echo "Failed to create virtual sink."
fi

# Move all existing application audio streams to the new combined sink
for app in $(pactl list sink-inputs short | awk '{print $1}'); do
    pactl move-sink-input "$app" combined_4_speakers 2>/dev/null || true
done
echo "Moved active applications to the combined speakers."
