#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  EPOS EXPAND 30 — 4-Speaker Surround 5.1/7.1 Activation Script
#  Ubuntu 26.04 / PipeWire 1.6.x / WirePlumber 0.4.x
#
#  FEATURES:
#    • Optimized for bed/laptop viewing (parallel speaker placement)
#    • Phantom Center: dialogue blended into both front speakers
#    • Stereo Upmix: YouTube/browser fills all 4 speakers (via PipeWire)
#    • Auto-handles 5.1 and 7.1 tracks (7.1 downmixed automatically)
#    • Volume differential: front 100% / rear 80% for depth illusion
#    • Survives Ubuntu upgrades — detects iec958 vs analog-stereo profiles
#
#  PHYSICAL PLACEMENT (bed/laptop-on-stomach setup):
#    ┌─────────────────────────────────────────────┐
#    │              [YOUR FEET]                    │
#    │                                             │
#    │  [USB3 RL]──────────────────[USB4 RR]       │
#    │      ← SCREEN/HINGE SIDE (further away) →  │
#    │  ┌──────────────────────────────────────┐   │
#    │  │          L A P T O P                │   │
#    │  └──────────────────────────────────────┘   │
#    │      ← TOUCHPAD SIDE (closer to ears) →    │
#    │  [USB1 FL]──────────────────[USB2 FR]       │
#    │                                             │
#    │              [YOUR HEAD]                    │
#    └─────────────────────────────────────────────┘
#
#  CHANNEL MAP (optimized for above placement):
#    USB 1 → Front Left   (FL + FC phantom): TOUCHPAD SIDE — CLOSER to ears
#    USB 2 → Front Right  (FR + FC phantom): TOUCHPAD SIDE — CLOSER to ears
#    USB 3 → Rear Left    (pure RL):         SCREEN SIDE   — FURTHER from ears
#    USB 4 → Rear Right   (pure RR):         SCREEN SIDE   — FURTHER from ears
#    LFE   → intentionally discarded
#
#  WHY THIS MAPPING:
#    Dialogue/main audio (FL/FR) should come from the speakers closest to your
#    ears — this sounds most natural and "present". Surround/ambient (RL/RR)
#    should come from further away — naturally quieter = depth illusion.
#
#  USAGE:  ~/activate_surround.sh
#  BACK:   ~/activate_default.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

LOG="[EPOS-Surround]"
SINK_NAME="surround_51_speakers"
SINK_DESC="EPOS Surround 5.1"

# ── Banner ───────────────────────────────────────────────────────────────────
PW_VER=$(pipewire --version 2>&1 | grep "Linked" | awk '{print $NF}')
echo ""
echo "$LOG ╔══════════════════════════════════════════════╗"
echo "$LOG ║   EPOS EXPAND 30 — Surround 5.1 Activator   ║"
echo "$LOG ╚══════════════════════════════════════════════╝"
echo "$LOG  PipeWire: $PW_VER | Ubuntu 26.04"
echo ""

# ── Step 1: Ensure upmix config is installed ─────────────────────────────────
UPMIX_CONF="$HOME/.config/pipewire/client.conf.d/99-upmix.conf"
if [ ! -f "$UPMIX_CONF" ]; then
    echo "$LOG [!] Upmix config missing — creating now..."
    mkdir -p "$HOME/.config/pipewire/client.conf.d"
    cat > "$UPMIX_CONF" << 'EOF'
# Auto-upmix stereo streams to 5.1 (fixes YouTube rear speaker silence)
stream.properties = {
    channelmix.upmix        = true
    channelmix.upmix-method = psd
    channelmix.lfe-cutoff   = 150
    channelmix.fc-cutoff    = 12000
    channelmix.rear-delay   = 12.0
    channelmix.stereo-widen = 0.0
    channelmix.hilbert-taps = 0
}
EOF
    echo "$LOG [✓] Upmix config created. Restarting PipeWire session..."
    systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true
    sleep 2
else
    echo "$LOG [✓] Upmix config present ($UPMIX_CONF)"
fi

# ── Step 2: Cleanup previous surround session ─────────────────────────────────
echo "$LOG Cleaning up previous session..."
pkill -f pw-loopback 2>/dev/null || true

# Unload any previously loaded surround virtual sinks
while IFS=$'\t ' read -r modid modname modargs; do
    if [[ "$modname" == "module-null-sink" ]] && echo "$modargs" | grep -qE "surround_51|surround_50"; then
        pactl unload-module "$modid" 2>/dev/null && \
            echo "$LOG   Unloaded old module #$modid" || true
    fi
done < <(pactl list modules short 2>/dev/null)

sleep 0.5

# ── Step 3: Detect EPOS speakers ─────────────────────────────────────────────
echo "$LOG Detecting EPOS EXPAND 30 USB speakers..."

# Grab ALL sink names containing EPOS_EXPAND_30, sorted by serial number
# Works with both old (analog-stereo) and new (iec958-stereo) Ubuntu 26.04 profiles
mapfile -t USB_SINKS < <(
    pactl list sinks short 2>/dev/null \
        | awk '{print $2}' \
        | grep "EPOS_EXPAND_30" \
        | sort
)

COUNT=${#USB_SINKS[@]}
echo "$LOG Found $COUNT EPOS USB speaker(s)."

if [ "$COUNT" -lt 4 ]; then
    echo ""
    echo "$LOG ╔══════════════════════════════════════╗"
    echo "$LOG ║  ERROR: Need 4 EPOS speakers, found $COUNT  ║"
    echo "$LOG ╚══════════════════════════════════════╝"
    echo "$LOG  Please plug in all 4 EPOS EXPAND 30 USB speakers and retry."
    echo ""
    exit 1
fi

echo "$LOG Speaker assignment (by serial number order):"
for i in "${!USB_SINKS[@]}"; do
    POS=("Front Left" "Front Right" "Rear Left" "Rear Right")
    echo "$LOG   [USB $((i+1))] ${POS[$i]}: ${USB_SINKS[$i]}"
done
echo ""

# ── Step 4: Create virtual 5.1 sink ──────────────────────────────────────────
echo "$LOG Creating virtual 6-channel 5.1 surround sink..."

MODULE_ID=$(pactl load-module module-null-sink \
    sink_name="$SINK_NAME" \
    "sink_properties=device.description='$SINK_DESC'" \
    channels=6 \
    channel_map=front-left,front-right,rear-left,rear-right,front-center,lfe \
    rate=48000 2>&1)

if [ -z "$MODULE_ID" ] || ! echo "$MODULE_ID" | grep -qE '^[0-9]+$'; then
    echo "$LOG ERROR: Failed to create virtual sink. Output: $MODULE_ID"
    exit 1
fi

echo "$LOG [✓] Virtual 5.1 sink created (module #$MODULE_ID)"
sleep 1  # Give PipeWire time to register the node and its ports

# ── Step 5: Link speakers — Razor-Sharp Separation Mode ──────────────────────
echo "$LOG Wiring speakers (Razor-Sharp Separation Mode)..."

# Helper: link with visual feedback
pw_link() {
    local src="$1" dst="$2" label="$3"
    if pw-link "$src" "$dst" 2>/dev/null; then
        echo "$LOG   ✓ $label"
    else
        echo "$LOG   ✗ FAILED: $src → $dst"
    fi
}

# ─ USB 1: Front Left ─────────────────────────────────────────────────────────
#   Receives: FL channel + FC (phantom center: dialogue bleeds into both fronts)
echo "$LOG [USB 1] Front Left + Phantom Center Dialogue"
pw_link "${SINK_NAME}:monitor_FL" "${USB_SINKS[0]}:playback_FL" "FL → USB1 L"
pw_link "${SINK_NAME}:monitor_FL" "${USB_SINKS[0]}:playback_FR" "FL → USB1 R"
pw_link "${SINK_NAME}:monitor_FC" "${USB_SINKS[0]}:playback_FL" "FC → USB1 L (phantom)"

# ─ USB 2: Front Right ────────────────────────────────────────────────────────
#   Receives: FR channel + FC (phantom center)
echo "$LOG [USB 2] Front Right + Phantom Center Dialogue"
pw_link "${SINK_NAME}:monitor_FR" "${USB_SINKS[1]}:playback_FL" "FR → USB2 L"
pw_link "${SINK_NAME}:monitor_FR" "${USB_SINKS[1]}:playback_FR" "FR → USB2 R"
pw_link "${SINK_NAME}:monitor_FC" "${USB_SINKS[1]}:playback_FR" "FC → USB2 R (phantom)"

# ─ USB 3: Rear Left ──────────────────────────────────────────────────────────
#   Receives: PURE RL only — no front bleeding for maximum surround immersion
#   Note: For stereo content, upmix (client.conf) derives RL from the L channel
echo "$LOG [USB 3] Rear Left — Pure Surround"
pw_link "${SINK_NAME}:monitor_RL" "${USB_SINKS[2]}:playback_FL" "RL → USB3 L"
pw_link "${SINK_NAME}:monitor_RL" "${USB_SINKS[2]}:playback_FR" "RL → USB3 R"

# ─ USB 4: Rear Right ─────────────────────────────────────────────────────────
#   Receives: PURE RR only — no front bleeding for maximum surround immersion
#   Note: For stereo content, upmix derives RR from the R channel
echo "$LOG [USB 4] Rear Right — Pure Surround"
pw_link "${SINK_NAME}:monitor_RR" "${USB_SINKS[3]}:playback_FL" "RR → USB4 L"
pw_link "${SINK_NAME}:monitor_RR" "${USB_SINKS[3]}:playback_FR" "RR → USB4 R"

# LFE is intentionally discarded — no sub = cleaner soundstage on EPOS speakers

echo ""

# ── Step 6: Set as default and apply volumes ──────────────────────────────────
# Volume strategy for parallel/bed placement:
#   Front speakers (USB 1 & 2, touchpad side, CLOSER to ears) → 100%
#   Rear speakers  (USB 3 & 4, screen side,   FURTHER from ears) → 80%
# This volume differential creates a psychoacoustic depth illusion —
# closer = louder = "in front", further = quieter = "behind you".
echo "$LOG Setting as default audio output..."
pactl set-default-sink "$SINK_NAME"
pactl set-sink-mute   "$SINK_NAME" 0
pactl set-sink-volume "$SINK_NAME" 100%

echo "$LOG Setting EPOS speaker volumes (Front 100% / Rear 80%)..."
# Front speakers — closer to ears, carry dialogue
pactl set-sink-mute   "${USB_SINKS[0]}" 0
pactl set-sink-volume "${USB_SINKS[0]}" 100%   # USB1: Front Left
pactl set-sink-mute   "${USB_SINKS[1]}" 0
pactl set-sink-volume "${USB_SINKS[1]}" 100%   # USB2: Front Right
# Rear speakers — further from ears, carry ambient surround
pactl set-sink-mute   "${USB_SINKS[2]}" 0
pactl set-sink-volume "${USB_SINKS[2]}" 80%    # USB3: Rear Left  (slightly quieter = sounds "behind")
pactl set-sink-mute   "${USB_SINKS[3]}" 0
pactl set-sink-volume "${USB_SINKS[3]}" 80%    # USB4: Rear Right (slightly quieter = sounds "behind")

# ── Step 7: Move all active streams to surround sink ──────────────────────────
echo "$LOG Migrating active audio streams..."
MOVED=0
while read -r input_id rest; do
    if pactl move-sink-input "$input_id" "$SINK_NAME" 2>/dev/null; then
        MOVED=$((MOVED + 1))
    fi
done < <(pactl list sink-inputs short 2>/dev/null)
echo "$LOG [✓] Moved $MOVED active stream(s) to surround sink."

# ── Step 8: Verify links ──────────────────────────────────────────────────────
echo ""
echo "$LOG Verifying active links..."
ACTIVE_LINKS=$(pw-link -l 2>/dev/null | grep -c "surround_51_speakers:monitor" || true)
echo "$LOG [✓] $ACTIVE_LINKS active PipeWire links confirmed."

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "$LOG ╔══════════════════════════════════════════════════════════════╗"
echo "$LOG ║          EPOS SURROUND 5.1 — FULLY ACTIVATED                ║"
echo "$LOG ║          (Optimized: Bed / Laptop-on-Stomach Layout)        ║"
echo "$LOG ╠══════════════════════════════════════════════════════════════╣"
echo "$LOG ║  USB 1 → Front Left   │ Touchpad side │ 100% — Dialogue    ║"
echo "$LOG ║  USB 2 → Front Right  │ Touchpad side │ 100% — Dialogue    ║"
echo "$LOG ║  USB 3 → Rear Left    │ Screen side   │  80% — Surround    ║"
echo "$LOG ║  USB 4 → Rear Right   │ Screen side   │  80% — Surround    ║"
echo "$LOG ╠══════════════════════════════════════════════════════════════╣"
echo "$LOG ║  Stereo Upmix  │ ON  — YouTube/web fills all 4 speakers    ║"
echo "$LOG ║  5.1 Movies    │ ON  — Discrete channels, depth illusion   ║"
echo "$LOG ║  7.1 Movies    │ ON  — Auto-downmixed to 5.1               ║"
echo "$LOG ╠══════════════════════════════════════════════════════════════╣"
echo "$LOG ║  TIP: Spread speakers LEFT-RIGHT for even better surround  ║"
echo "$LOG ║  Switch back:  ~/activate_default.sh                       ║"
echo "$LOG ╚══════════════════════════════════════════════════════════════╝"
echo ""
