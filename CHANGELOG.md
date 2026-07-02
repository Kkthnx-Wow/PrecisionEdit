# PrecisionEdit — Changelog

---

## [1.2.0] — 2026-06-30

### Fixed

- **Panel close:** closing the precision panel with the X now also hides the anchor
  guide and disables arrow-key nudging until you select a frame again (or open the
  panel on a fresh selection). The guide no longer reappears on lib-frame dialog
  refreshes while the panel stays closed.
- **LibEditMode late load:** if an addon embedding LibEditMode loads after
  PrecisionEdit at login, the library is now picked up via an `ADDON_LOADED`
  retry instead of being missed for the whole session.
- **Arrow-key double nudge:** the key catcher only runs while the precision panel
  is visible, and sits above Edit Mode dialogs so arrow keys are handled once —
  avoiding duplicate moves from Blizzard's or LibEditMode's own keyboard handlers.

### Changed

- **Locked frames:** attempting to move a locked Edit Mode system now prints a
  clear chat message instead of failing silently.
- **Coordinate display:** negative-zero offsets (e.g. cast bar X ≈ 0) show as `0`
  instead of `-0`.

### Added

- **Help — anchor offsets:** the help tooltip explains that X and Y are offsets
  from the frame's anchor point, not absolute screen pixels.

---

## [1.1.0] — 2026-06-13

### Added

- **LibEditMode support:** the precision panel now appears for frames that other
  addons register with [LibEditMode](https://github.com/p3lim-wow/LibEditMode),
  not just Blizzard's own systems. Selecting such a frame in Edit Mode brings up
  the same panel — type exact coordinates, nudge, snap, center and reset — and
  moves save through the owning addon's own callback so they persist in that
  addon's layout. The library is detected automatically through LibStub; if no
  installed addon embeds it, nothing changes. The anchor point is kept fixed
  (rather than re-normalised) so typed coordinates stay exact, matching how
  PrecisionEdit treats Blizzard frames.

---

## [0.1.0] — 2026-06-12

Initial release. Adds a precision panel to Blizzard's Edit Mode for pixel-level
positioning — type exact coordinates, nudge with the arrow keys or a d-pad, snap to
screen edges, center and reset — all written through Blizzard's own position-change
path so changes save into the active layout. Fully event-driven, combat-safe and
Midnight secret-value hardened.

### Added

- **Positioning — Exact Coordinates:** type an absolute X / Y offset and apply it
  with Enter. Offsets are kept in Blizzard's normalised 1.0-scale "stored" units,
  so the numbers match what Edit Mode persists; multi-point frames move rigidly.
- **Positioning — Nudge:** a d-pad and global arrow keys move the selected frame
  one unit at a time, holding **Shift** to move by a configurable Step. The key
  catcher only consumes the arrows (chat and other bindings keep working) and steps
  aside while you're typing in the panel's boxes.
- **Positioning — Snap to Edge:** snap the selected frame to the left, right, top
  or bottom of the screen, converted through effective scale so alignment stays
  correct when a frame is scaled differently from UIParent.
- **Positioning — Center:** center the frame on the X axis, Y axis or both, correct
  regardless of the frame's own scale.
- **Positioning — Reset:** return the selected system to its layout default position.
- **Panel — Anchor Guide:** an optional on-screen crosshair marking the selected
  frame's anchor point, labelled with the anchor and kept live as the frame moves.
- **Panel — Live Readout & Styling:** the panel shows the system name and live
  anchor (updating for our nudges and normal Blizzard drags), matches Blizzard's
  Edit Mode dialog look, and carries a close button and a help (ℹ) button.
- **Panel — Movable & Lockable:** drag the panel anywhere; `/pe lock` keeps it put.
  Position and behaviour are saved account-wide in `PrecisionEditDB`.
- **Slash Commands:** `/pe` (`help`, `reset`, `lock`), with `/precisionedit` as an alias.
- **Addon Icon:** a gold precision-reticle icon shown in the AddOns list.

### Notes

- Frame movement is gated on combat and on the geometry being readable, so secret
  values in combat/instances never cause errors — the panel simply defers.
