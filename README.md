# Present

Windows-style projector modes for [Omarchy](https://omarchy.org). Plug in a
projector or TV, press `SUPER + P`, pick a mode.

![The Present picker](preview.png)

| Mode | What you get |
|---|---|
| **1 Laptop screen only** | The external display is turned off. |
| **2 Duplicate** | The external shows your laptop screen, scaled to fit with black bars. Nothing is stretched, and neither screen changes resolution. |
| **3 Extend** | A second desktop to the left, right, above or below. |
| **4 Second screen only** | The laptop screen is turned off. |

## Why

Presenting from Hyprland usually goes wrong in two ways:

- **Mirroring stretches.** Hyprland's `mirror` copies your laptop's pixels onto
  the other display as they are, so a 16:10 laptop on a 16:9 projector comes out
  squashed. Present's Duplicate keeps each display at its own native resolution
  and letterboxes your screen instead, the way Windows does.
- **Text is tiny or huge.** A catch-all monitor rule gives every new display the
  same scale, and Hyprland's `auto` scale guesses from the physical size the
  display reports, which TVs and projectors often get wrong. Present scales every
  display so it looks like a 1080p screen: 4K → 2, 1440p → 1.33, 1080p or lower → 1.

![Duplicate: the laptop screen fits the projector with black bars](docs/duplicate.png)

## What happens when you plug in

- **A display seen before** gets its saved mode, position and size back.
- **A new display** starts in Duplicate and the picker opens.
- **Unplugging** returns everything to the laptop screen, including turning it
  back on after Second screen only.
- **Closing the lid** in Duplicate makes the external your main screen; opening
  it goes back to Duplicate.

While Duplicate is on, the system doesn't idle, lock or sleep on its own, so a
talk isn't interrupted. `SUPER + L` still locks, and the projector then shows
the lock screen rather than your desktop.

A display whose native mode is below 50Hz (a TV's 4K@30, for example) is driven
at its largest mode of 50Hz or more instead.

## Install

```bash
omarchy plugin add https://github.com/akashanil-dev/omarchy-present.git --enable
sudo pacman -S wl-mirror
```

Then bind the picker to a key in `~/.config/hypr/bindings.lua`. Present doesn't
add the binding for you. `SUPER + P` matches Windows; Omarchy uses it for
"Pseudo window", which only does something in the dwindle layout:

```lua
hl.unbind("SUPER + P")
o.bind("SUPER + P", "Project to a second screen", "omarchy-shell shell toggle io.github.akashanil-dev.present")
```

## Using it

`SUPER + P` opens the picker.

| Key | Action |
|---|---|
| `←` `→`, or `P` | Choose a mode |
| `Enter` | Apply it |
| `1`–`4` | Apply a mode directly |
| `+` `−` | Bigger or smaller (Extend and Second screen only) |
| `0` | Back to the automatic size |
| `Esc` | Close |

The bottom row sets where an extended display sits and how big things are on
it. **Don't manage** hands the display back to your own Hyprland config, for a
desk monitor you have already set up in `monitors.lua`.

Everything is also available from a terminal:

```bash
P=~/.config/omarchy/plugins/io.github.akashanil-dev.present/bin/present
$P status                       # JSON: the display and its saved mode
$P set duplicate                # duplicate | extend | external | internal | ignore
$P position up                  # right | left | up | down
$P scale up                     # up | down | reset
```

## How it works

- **No config files are edited.** Display rules are applied at runtime with
  `hyprctl eval`, the way Omarchy's own `SUPER + /` scaling key works. A config
  reload drops them, and the plugin applies them again right after.
- **Duplicate** uses [wl-mirror](https://github.com/Ferdi265/wl-mirror). The
  external display runs at its native mode, placed far away from the laptop
  display so the cursor and new windows can't land on it, and wl-mirror fills it
  on a workspace of its own (`present`), so `SUPER + 1`–`9` stay on the laptop.
  If wl-mirror exits unexpectedly, it is restarted.
- **The laptop screen** is only turned off through Omarchy's own toggle
  (`omarchy-hyprland-monitor-internal`), so Omarchy's lid and docking watcher
  agrees with Present.

Files it writes:

| Path | Contents |
|---|---|
| `~/.local/state/io.github.akashanil-dev.present/displays.json` | The saved mode, position and size of each display |
| `~/.local/state/io.github.akashanil-dev.present/present.log` | What happened and when, trimmed to a few hundred lines |
| `$XDG_RUNTIME_DIR/io.github.akashanil-dev.present/` | A lock file and the rules applied in this session |

Nothing runs as root, and nothing reaches the network.

## Requirements

- Omarchy 4 (Hyprland with the Lua config, and the Quickshell-based
  `omarchy-shell`)
- [`wl-mirror`](https://archlinux.org/packages/extra/x86_64/wl-mirror/) for
  Duplicate, from Arch's `extra` repository. The other modes work without it,
  and the picker says when it is missing.
- `jq` and `hyprctl`, both part of Omarchy

Tested on Omarchy 4.0.0 alpha with Hyprland 0.56.2, Quickshell 0.3.1 and
wl-mirror 0.18.5.

## Troubleshooting

- **Something looks wrong on a projector.** Look at `present.log` (see above)
  and include it in an issue.
- **"Process crashed: wl-mirror".** wl-mirror can crash when a display is
  reconfigured under it. Present restarts it within about a second, but
  Omarchy's crash watcher still reports the crash. To silence those reports for
  wl-mirror only, run `systemctl --user edit omarchy-crash-watch`, add
  `Environment=OMARCHY_CRASH_IGNORE=wl-mirror` under `[Service]`, and restart it
  with `systemctl --user restart omarchy-crash-watch`.
- **A desk monitor lost its custom layout.** Open the picker with that monitor
  connected and choose **Don't manage**.

## Remove

```bash
omarchy plugin remove io.github.akashanil-dev.present
rm -rf ~/.local/state/io.github.akashanil-dev.present
hyprctl reload
```

Then delete the `SUPER + P` lines from `~/.config/hypr/bindings.lua`. The reload
drops any display rules Present applied.

## Development

`bin/present` holds all the logic; `Service.qml` reacts to Hyprland's
`monitoradded`, `monitorremoved` and `configreloaded` events, and `Picker.qml` is
the picker. To try it without a second display, create a virtual one and let
Present count it:

```bash
touch ~/.local/state/io.github.akashanil-dev.present/include-headless
hyprctl output create headless HDMI-A-1
# ...
hyprctl output remove HDMI-A-1
rm ~/.local/state/io.github.akashanil-dev.present/include-headless
```

## License

[MIT](LICENSE)
