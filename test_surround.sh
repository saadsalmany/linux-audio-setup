#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  EPOS Surround Speaker Test — Ubuntu 26.04 / PipeWire 1.6.x
#
#  Plays a named voice announcement through each surround channel so you can
#  physically verify which EPOS speaker is in which position.
#
#  USAGE:
#    ~/test_surround.sh          → full 5.1 cycle (repeating until Ctrl+C)
#    ~/test_surround.sh once     → single pass through all channels
#    ~/test_surround.sh <ch>     → test one channel: fl fr rl rr fc lfe
#
#  REQUIREMENTS:
#    ~/activate_surround.sh must be run first.
# ═══════════════════════════════════════════════════════════════════════════════

SINK="surround_51_speakers"

if ! pactl list sinks short 2>/dev/null | grep -q "$SINK"; then
    echo "[Test] ERROR: Surround sink not active."
    echo "[Test] Please run ~/activate_surround.sh first."
    exit 1
fi

MODE="${1:-loop}"

echo "[Test] ╔══════════════════════════════════════════════╗"
echo "[Test] ║   EPOS 5.1 Surround Channel Test             ║"
echo "[Test] ╠══════════════════════════════════════════════╣"
echo "[Test] ║  FL  → USB 1 (Front Left)                   ║"
echo "[Test] ║  FR  → USB 2 (Front Right)                  ║"
echo "[Test] ║  RL  → USB 3 (Rear Left)                    ║"
echo "[Test] ║  RR  → USB 4 (Rear Right)                   ║"
echo "[Test] ║  FC  → Both Front Speakers (Phantom Center) ║"
echo "[Test] ╠══════════════════════════════════════════════╣"
echo "[Test] ║  Press Ctrl+C to stop                       ║"
echo "[Test] ╚══════════════════════════════════════════════╝"
echo ""

run_test() {
    case "$MODE" in
        once)
            # Single pass: -l 1
            speaker-test -D pulse -c 6 -t wav -l 1 \
                --device "$SINK" 2>/dev/null || \
            speaker-test -c 6 -t wav -l 1 2>/dev/null
            ;;
        fl|fr|rl|rr|fc|lfe)
            # Test single channel
            CH_MAP=( [fl]=0 [fr]=1 [rl]=2 [rr]=3 [fc]=4 [lfe]=5 )
            CH="${CH_MAP[$MODE]:-0}"
            echo "[Test] Testing channel: $MODE (channel $CH)"
            speaker-test -D pulse -c 6 -t wav -l 3 -s "$((CH+1))" \
                --device "$SINK" 2>/dev/null || \
            speaker-test -c 6 -t wav -l 3 -s "$((CH+1))" 2>/dev/null
            ;;
        *)
            # Continuous loop
            speaker-test -D pulse -c 6 -t wav \
                --device "$SINK" 2>/dev/null || \
            speaker-test -c 6 -t wav 2>/dev/null
            ;;
    esac
}

run_test
