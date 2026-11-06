# 🔊 Linux Audio Setup — EPOS EXPAND 30 Surround on Ubuntu

> **Ubuntu 26.04 · PipeWire 1.6.x · WirePlumber 0.5.x**

A collection of shell scripts to set up and control a **4-speaker 5.1/7.1 virtual surround sound system** using four EPOS EXPAND 30 USB speakers on Ubuntu Linux — with full browser upmix support (YouTube, Brave, Firefox) and easy switching between surround, Bluetooth, earbuds, and built-in speakers.

---

## 🖥️ Hardware Used

| Item | Model |
|---|---|
| Laptop | ThinkPad (Ubuntu 26.04) |
| Speakers (×4) | EPOS EXPAND 30 USB Conference Speakers |
| Audio stack | PipeWire + WirePlumber |

---

## 📁 Scripts

| Script | What it does |
|---|---|
| [`activate_surround.sh`](activate_surround.sh) | Activates 5.1 virtual surround across all 4 EPOS speakers. Routes FL/FR (front pair, closest to ears) and RL/RR (rear pair). Volume differential: front 100%, rear 80% for depth illusion. |
| [`activate_default.sh`](activate_default.sh) | Switches audio back to built-in speaker, headphone, or Bluetooth. |
| [`activate_4_speakers.sh`](activate_4_speakers.sh) | Alternative 4-speaker flat (non-surround) activation. |
| [`activate_earpods_51.sh`](activate_earpods_51.sh) | Activates 5.1 binaural HRTF virtual surround for Apple EarPods. |
| [`activate_earpods_stereo.sh`](activate_earpods_stereo.sh) | Switches EarPods back to flat stereo mode. |
| [`test_surround.sh`](test_surround.sh) | Plays a spoken channel test tone through each speaker so you can verify correct placement. |

---

## ⚡ Quick Start

```bash
# Clone the repo
git clone https://github.com/saadsalmany/linux-audio-setup.git
cd linux-audio-setup

# Make all scripts executable
chmod +x *.sh

# Copy to home directory (optional, for easy access)
cp *.sh ~/
```

### Activate 4-speaker surround
```bash
~/activate_surround.sh
```

### Test each speaker (verify placement)
```bash
~/test_surround.sh once
```

### Switch to Bluetooth
```bash
~/activate_default.sh bluetooth
```

### Switch to built-in speaker
```bash
~/activate_default.sh
```

### Switch to wired headphones
```bash
~/activate_default.sh headphone
```

### Back to EarPods (stereo)
```bash
~/activate_earpods_stereo.sh
```

---

## 🗺️ Speaker Placement (Bed / Laptop-on-Stomach Setup)

```
              [YOUR FEET]

  [Rear-Left] ─────────────────── [Rear-Right]   ← screen/hinge side, further from ears
  ══════════════ LAPTOP ══════════════
  [Front-Left] ─────────────────── [Front-Right]  ← touchpad side, closest to ears

              [YOUR HEAD]
```

- **Front speakers** (FL/FR) → touchpad side, near chest/shoulders → carry dialogue
- **Rear speakers** (RL/RR) → screen/hinge side, slightly further → carry ambient surround
- Spread speakers **left-right** as far as cables allow for the widest stereo stage

---

## ⚙️ How It Works

1. **Virtual Sink** — The script creates a `surround_51_speakers` null sink with a 5.1 channel map using `pactl load-module module-null-sink`.
2. **pw-link** — Each EPOS USB speaker is then linked to its dedicated virtual channel (FL, FR, RL, RR) via `pw-link`.
3. **Stereo Upmix** — PipeWire's `channelmix` plugin is configured in `~/.config/pipewire/pipewire-pulse.conf.d/` and `client.conf.d/` to upmix stereo sources (YouTube, music) across all 4 speakers in real time.
4. **Phantom Center** — Dialogue (FC channel) is blended into both front speakers.
5. **7.1 auto-downmix** — 7.1 content is automatically folded down to 5.1 by PipeWire.

---

## 📋 Requirements

```bash
# PipeWire stack (usually pre-installed on Ubuntu 22.04+)
sudo apt install pipewire pipewire-pulse wireplumber

# PulseAudio tools (for pactl)
sudo apt install pulseaudio-utils

# PipeWire link tool
sudo apt install pipewire  # pw-link is bundled
```

---

## 🐛 Troubleshooting

**Only 3 speakers detected:**
- Make sure all 4 USB speakers are plugged in and powered on
- Each EPOS EXPAND 30 needs its own USB port (avoid cheap hubs without individual power)
- Restart PipeWire: `systemctl --user restart pipewire pipewire-pulse wireplumber`

**YouTube only plays on 2 speakers:**
- The upmix config in `~/.config/pipewire/pipewire-pulse.conf.d/99-upmix.conf` handles browser audio
- Restart PipeWire after adding config: `systemctl --user restart pipewire pipewire-pulse wireplumber`

**Rear speakers sound too quiet:**
- Edit `activate_surround.sh` and change the rear volume from `80%` to a higher value (e.g., `90%`)

---

## 📄 License

MIT — feel free to adapt for your own Linux audio setup.
