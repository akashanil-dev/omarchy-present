# Changelog

## Unreleased

- Renamed to Present the Screen. The plugin id, the `present` command and the
  saved settings are unchanged.
- Match the TV (key 5): Duplicate without black bars. The laptop's desktop
  takes the TV's shape at the bottom of the screen, and only that part is
  mirrored. Fullscreen windows stay inside it.
- Sound: the picker shows the outputs that are plugged in and the one playing,
  switches between them (changing the card profile when needed), and
  remembers the choice per display.
- Brightness: DDC/CI with ddcutil where the display takes it, otherwise a
  dimming layer, and the picker says which.
- A bar icon showing the mode: click for the picker, scroll for brightness.

- Laptop screen only keeps the projector's signal and shows a card instead: an
  optional title line, your name and site, a QR code, and the time. Set it up
  in `~/.config/io.github.akashanil-dev.present/card.json`, or the title with
  `present title "..."`.
- Fix: choosing Laptop screen only, Extend, Second screen only or Don't manage
  in the picker did nothing. The picker closed itself before running the
  command, and the shell had already unloaded it.
- Second screen only turns the laptop display off at runtime instead of with a
  config reload, which made some TVs drop off HDMI (hotplug storm, EDID lost).
- A mode is saved only once the display really ended up that way; otherwise
  the previous mode comes back with a notification.
- Displays are matched by connector, so a TV that comes up without its EDID
  still keeps its saved mode, and the laptop stays on while it has no modes.

## 1.0.0

First release.

- `SUPER + P` picker with Laptop screen only, Duplicate, Extend and Second
  screen only, plus extend direction, size and Don't manage.
- Duplicate through wl-mirror: native resolution on both displays, letterboxed,
  never stretched; restarted automatically if it exits.
- Resolution-based scaling for new displays, and a 50Hz floor for TVs that
  prefer 4K@30.
- Saved per display, restored on reconnect; unplugging and closing the lid
  return to a working screen.
- No config files edited: rules are applied at runtime and re-applied after
  config reloads.
