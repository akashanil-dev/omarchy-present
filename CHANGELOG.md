# Changelog

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
