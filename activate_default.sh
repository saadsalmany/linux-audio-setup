#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  Switch Audio to Default Laptop Output
#  Ubuntu 26.04 / PipeWire 1.6.x
#
#  Deactivates the EPOS surround setup and routes all audio to the
#  built-in laptop speaker or headphones (auto-detected).
#
#  USAGE:
#    ~/activate_default.sh              → auto-detect best output
#    ~/activate_default.sh speaker      → force built-in laptop speaker
#    ~/activate_default.sh headphone    → force headphone port
#    ~/activate_default.sh bluetooth    → route to connected Bluetooth device
#    ~/activate_default.sh list         → show available outputs
#
#  TO SWITCH BACK TO EPOS SURROUND:
#    ~/activate_surround.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

LOG="[Audio-Default]"
MODE="${1:-auto}"

echo ""
echo "$LOG ╔══════════════════════════════════════════╗"
echo "$LOG ║    Switch to Default Audio Output        ║"
echo "$LOG ╚══════════════════════════════════════════╝"
echo ""

# ── List mode ────────────────────────────────────────────────────────────────
if [ "$MODE" = "list" ]; then
    echo "$LOG Available audio outputs:"
    pactl list sinks short | while read -r id name rest; do
        desc=$(pactl list sinks | grep -A3 "Name: $name" | grep "Description:" | sed 's/.*Description: //')
        port=$(pactl list sinks | grep -A8 "Name: $name" | grep "Active Port:" | sed 's/.*Active Port: //')
        echo "$LOG   [$id] $desc — port: $port"
    done
    echo ""
    exit 0
fi

# ── Find the internal audio card sink ────────────────────────────────────────
# Matches all known ThinkPad T14 internal audio sink name patterns
# Works across Ubuntu 24.04 → 26.04 (sink naming changed between versions)
SPEAKER_SINK=$(pactl list sinks short 2>/dev/null \
    | awk '{print $2}' \
    | grep -E "pci.*HiFi__(Speaker|hw_sofhdadsp)(_[0-9]+)?__sink" \
    | grep -v "HDMI\|hdmi" \
    | head -1)

if [ -z "$SPEAKER_SINK" ]; then
    # Broader fallback — any non-USB, non-HDMI, non-virtual sink
    SPEAKER_SINK=$(pactl list sinks short 2>/dev/null \
        | awk '{print $2}' \
        | grep -v "EPOS\|hdmi\|HDMI\|surround\|virtual\|combined\|kemar\|bluez" \
        | grep "pci" \
        | head -1)
fi

if [ -z "$SPEAKER_SINK" ]; then
    echo "$LOG ERROR: Cannot find internal speaker sink."
    echo "$LOG Run:  ~/activate_default.sh list  — to see all available outputs."
    exit 1
fi

# ── Determine target based on mode ───────────────────────────────────────────
TARGET="$SPEAKER_SINK"
PORT_LABEL="Speaker"

# Check active port to see if headphones are already plugged in
ACTIVE_PORT=$(pactl list sinks 2>/dev/null \
    | grep -A15 "Name: $SPEAKER_SINK" \
    | grep "Active Port:" \
    | sed 's/.*Active Port: //' \
    | tr -d ' ')

case "$MODE" in
    headphone|headphones)
        PORT_LABEL="Headphone"
        # Headphone port is on the same sink — WirePlumber auto-switches port
        # when headphones are physically inserted. Just set the sink as default.
        TARGET="$SPEAKER_SINK"
        ;;
    bluetooth)
        PORT_LABEL="Bluetooth"
        # Find the first active Bluetooth (bluez) audio sink
        BT_SINK=$(pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -i 'bluez' | head -1)
        if [ -z "$BT_SINK" ]; then
            echo "$LOG ERROR: No active Bluetooth sink found."
            echo "$LOG  → Pair and connect your Bluetooth device first, then retry."
            echo "$LOG  → Run:  ~/activate_default.sh list   — to see all available outputs."
            exit 1
        fi
        TARGET="$BT_SINK"
        SPEAKER_SINK="$BT_SINK"   # so volume/migrate logic below works unchanged
        ;;
    speaker|auto)
        PORT_LABEL="Speaker"
        TARGET="$SPEAKER_SINK"
        ;;
esac

echo "$LOG Target sink  : $TARGET"
echo "$LOG Current port : ${ACTIVE_PORT:-unknown}"
echo ""

# ── Set as default output ─────────────────────────────────────────────────────
echo "$LOG Setting as default audio output..."
pactl set-default-sink "$TARGET"
pactl set-sink-mute   "$TARGET" 0

# Restore a sane volume (70% — not jarring after surround loudness)
CURRENT_VOL=$(pactl list sinks 2>/dev/null \
    | grep -A4 "Name: $TARGET" \
    | grep "Volume:" \
    | head -1 \
    | grep -oP '[0-9]+%' \
    | head -1 \
    | tr -d '%')

if [ -z "$CURRENT_VOL" ] || [ "$CURRENT_VOL" -lt 10 ]; then
    pactl set-sink-volume "$TARGET" 70%
    echo "$LOG [✓] Volume set to 70% (was very low or unknown)"
else
    echo "$LOG [✓] Volume kept at ${CURRENT_VOL}%"
fi

# ── Migrate all active audio streams ─────────────────────────────────────────
echo "$LOG Migrating all active audio streams..."
MOVED=0
while read -r input_id rest; do
    if pactl move-sink-input "$input_id" "$TARGET" 2>/dev/null; then
        MOVED=$((MOVED + 1))
    fi
done < <(pactl list sink-inputs short 2>/dev/null)
echo "$LOG [✓] Moved $MOVED stream(s) to default output."

# ── Optionally clean up surround sink ────────────────────────────────────────
# Unload the surround virtual sink if it exists and is now unused
SURROUND_MOD=$(pactl list modules short 2>/dev/null \
    | awk '{print $1" "$2" "$3}' \
    | grep "module-null-sink" \
    | grep "surround_51_speakers" \
    | awk '{print $1}' \
    | head -1)

if [ -n "$SURROUND_MOD" ]; then
    pactl unload-module "$SURROUND_MOD" 2>/dev/null && \
        echo "$LOG [✓] Unloaded surround_51_speakers virtual sink (module #$SURROUND_MOD)" || \
        echo "$LOG [!] Could not unload surround module (may still be in use)"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
FINAL_DESC=$(pactl list sinks 2>/dev/null \
    | grep -A2 "Name: $TARGET" \
    | grep "Description:" \
    | sed 's/.*Description: //')

echo ""
echo "$LOG ╔════════════════════════════════════════════════════╗"
echo "$LOG ║         DEFAULT AUDIO OUTPUT ACTIVATED             ║"
echo "$LOG ╠════════════════════════════════════════════════════╣"
printf  "$LOG ║  Output : %-40s║\n" "${FINAL_DESC:-$TARGET}"
printf  "$LOG ║  Port   : %-40s║\n" "${PORT_LABEL}"
echo "$LOG ╠════════════════════════════════════════════════════╣"
echo "$LOG ║  Bluetooth:   ~/activate_default.sh bluetooth     ║"
echo "$LOG ║  Headphone:   ~/activate_default.sh headphone     ║"
echo "$LOG ║  Back to EPOS: ~/activate_surround.sh            ║"
echo "$LOG ╚════════════════════════════════════════════════════╝"
echo ""
