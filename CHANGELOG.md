# PrecisionEdit — Changelog

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
