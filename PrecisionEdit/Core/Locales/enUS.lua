--[[
	PrecisionEdit - Locale (enUS, base)
	-------------------------------------------------------------------------
	Every user-facing string lives here as L["text"] = "text". The engine's L
	table falls back to the key, so other locales can override selectively.
--]]

local _, ns = ...
local L = ns.L

-- Panel
L["Position"] = "Position"
L["Drag to move"] = "Drag to move"
L["No element selected"] = "No element selected"
L["Select a frame in Edit Mode"] = "Select a frame in Edit Mode"
L["Center X"] = "Center X"
L["Center Y"] = "Center Y"
L["Center"] = "Center"
L["Reset"] = "Reset"
L["Reset to default position"] = "Reset to default position"
L["Center horizontally on screen"] = "Center horizontally on screen"
L["Center vertically on screen"] = "Center vertically on screen"
L["Center on both axes"] = "Center on both axes"
L["Nudge up"] = "Nudge up"
L["Nudge down"] = "Nudge down"
L["Nudge left"] = "Nudge left"
L["Nudge right"] = "Nudge right"
L["Step"] = "Step"
L["Shift-nudge distance"] = "Shift-nudge distance"
L["Guide"] = "Guide"
L["Show anchor guide"] = "Show anchor guide"
L["Arrow keys nudge - hold Shift for %d"] = "Arrow keys nudge - hold Shift for %d"
L["Snap"] = "Snap"
L["Left"] = "Left"
L["Right"] = "Right"
L["Top"] = "Top"
L["Bottom"] = "Bottom"
L["Snap to left edge"] = "Snap to left edge"
L["Snap to right edge"] = "Snap to right edge"
L["Snap to top edge"] = "Snap to top edge"
L["Snap to bottom edge"] = "Snap to bottom edge"
L["Type a value and press Enter"] = "Type a value and press Enter"
L["Anchor: %s to %s of %s"] = "Anchor: %s to %s of %s"

-- Help tooltip (the gold "i" button)
L["HELP_INTRO"] = "Fine-tune the position of any frame selected in Edit Mode."
L["HELP_TYPE"] = "- Type an exact X or Y offset and press Enter."
L["HELP_NUDGE"] = "- Arrow keys or the d-pad nudge by 1; hold Shift for the Step amount."
L["HELP_SNAP"] = "- Center or Snap the frame to a screen edge."
L["HELP_RESET"] = "- Reset returns it to the layout's default position."
L["HELP_ANCHOR"] = "- X and Y are offsets from the anchor point shown above (not screen pixels); different anchors are not directly comparable."

-- Messages
L["Cannot move a frame during combat."] = "Cannot move a frame during combat."
L["Cannot move this frame while it is locked."] = "Cannot move this frame while it is locked."
L["Enter Edit Mode, then select a frame to position it precisely."] = "Enter Edit Mode, then select a frame to position it precisely."
L["Panel position reset."] = "Panel position reset."

-- Slash command help
L["Usage"] = "Usage"
L["Commands:"] = "Commands:"
L["Show this help"] = "Show this help"
L["Reset the panel's position"] = "Reset the panel's position"
L["Lock or unlock the panel"] = "Lock or unlock the panel"
L["Panel locked."] = "Panel locked."
L["Panel unlocked."] = "Panel unlocked."
