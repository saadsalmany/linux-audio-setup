#!/bin/bash
echo "Activating 5.1 Virtual Surround (Binaural HRTF) for Apple EarPods..."

# Unload the old physical 5.1 surround virtual sink to avoid conflicts
for module in $(pactl list modules short | grep "module-null-sink" | grep -E "surround_51|music_mode" | awk '{print $1}'); do
    pactl unload-module "$module" 2>/dev/null
done

# Ensure the PipeWire HRTF configuration is active
if ! pactl list sinks short | grep -q "virtual-surround-5.1-kemar"; then
    echo "Starting PipeWire Virtual Surround Daemon..."
    systemctl --user restart pipewire pipewire-pulse
    sleep 2
fi

# Set EarPods as default output
EARPODS="alsa_output.usb-Apple__Inc._EarPods_GRYP3W2Y73-00.analog-stereo"
pactl set-sink-mute "$EARPODS" 0
pactl set-sink-volume "$EARPODS" 80%

# Link the Spatializer output directly to the EarPods
pw-link "effect_output.virtual-surround-5.1-kemar:output_FL" "$EARPODS:playback_FL" 2>/dev/null
pw-link "effect_output.virtual-surround-5.1-kemar:output_FR" "$EARPODS:playback_FR" 2>/dev/null

# Set the 5.1 Virtual Surround Sink as the default system sink
pactl set-default-sink "effect_input.virtual-surround-5.1-kemar"
pactl set-sink-volume "effect_input.virtual-surround-5.1-kemar" 100%

# Move any active apps (like VLC/mpv) to the virtual sink
for app in $(pactl list sink-inputs short | awk '{print $1}'); do
    pactl move-sink-input "$app" "effect_input.virtual-surround-5.1-kemar" 2>/dev/null || true
done

echo "EarPods 5.1 Spatial Audio activated! Enjoy the movie in 3D!"
