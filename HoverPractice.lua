--[=[
-- Draw constants
--]=]
CANVAS_HEIGHT = 256
CANVAS_WIDTH = CANVAS_HEIGHT * 2
AXIS_HEIGHT = CANVAS_HEIGHT / 2
CANVAS_PAD = 3
MAX_BAR = 40 -- max bar size drawn
BAR_THICC = 4 -- thickness of bars, affected by zoom
BAR_PAD = 2 -- distance between bars, affected by zoom
MOST_BARS = 20 -- max number of bars drawn
ZOOM = 2 -- resize of bar
RED = 0xFFFF0000
GREEN = 0xFF00FF00
WHITE = 0xFFFFFFFF

--[=[
-- This section was shamelessly borrowed from Raekuul
-- https://github.com/raekuul/Z3-Lua-Hud-BizHawk/blob/master/Z3-Rando-Hud-BizHawk.lua
--]=]

function race()
	q = memory.read_u8(0x00FFC3, "System Bus")
	if (q == 0x54) then
		return true
	else
		return false
	end
end

function initScript()
	drawSpace = gui.createcanvas(CANVAS_WIDTH + (2 * CANVAS_PAD), CANVAS_HEIGHT + (2 * CANVAS_PAD))
	drawSpace.Clear(0xFF000000)
end

--[=[
-- Hovering constants
--]=]
MAX_HOLD = 30 -- frames A can be held for before failing
MAX_RELEASE = 1 -- frames A can be released for before failing
GOOD_STREAK = 10 -- minimum length of a streak considered good

--[=[
-- Hover tracking
--]=]
a_held = false
current_time = 0
current_streak = 0
previous_good_streak = 0
best_streak = 0

--[=[
-- Object for each hover "press"
-- idk what to call it
--]=]
Boot = { up = 0, down = 0 }

function Boot:pressed()
	self.up = self.up + 1
end

function Boot:offed()
	self.down = self.down + 1
end

function Boot:new(o)
	o = o or {}   -- create object if user does not provide one
	setmetatable(o, self)
	self.__index = self
	return o
end

--[=[
-- Tracks boots actions
--]=]
boots_list = { Boot:new() }

function boots_list.shift_and_add()
	for i = MOST_BARS, 2, -1 do
		boots_list[i] = boots_list[i-1]
	end
	boots_list[1] = Boot:new()
end

-- End of hover objects

--[=[
-- Draws the canvas
--]=]
function drawData()
	drawSpace.DrawLine(0, AXIS_HEIGHT, CANVAS_WIDTH, AXIS_HEIGHT, WHITE)
	for i = 1, MOST_BARS do
		local b = boots_list[i]
		if (b) then
			local x = CANVAS_WIDTH - (i * ( ZOOM * (BAR_THICC + BAR_PAD) ))
			local h_up = b.up * ZOOM
			local h_down = b.down * ZOOM
			if (h_up > 0) then
				if (h_up > MAX_BAR) then
					h_up = MAX_BAR
				end
				drawSpace.DrawRectangle(x, AXIS_HEIGHT - 1 - h_up, BAR_THICC, h_up, GREEN, GREEN)
			end
			if (h_down > 0) then
				if (h_down > MAX_BAR) then
					h_down = MAX_BAR
				end
				drawSpace.DrawRectangle(x, AXIS_HEIGHT + 1, BAR_THICC, h_down, RED, RED)
			end
		end
	end
end

--[=[
-- Controls objects used to track hover success
--]=]
function pollHover(held)
	held = held or false
	local b = boots_list[1]

	if (held == true) then
		if (a_held == true and b) then
			b:pressed()
		else
			boots_list.shift_and_add()
			boots_list[1]:pressed()
		end
	elseif (b) then -- hmmmm
		b:offed()
	end

	a_held = held

	drawData()
end

function mainLoop()
	while true do
		emu.frameadvance()
		pad = joypad.get(1)

		pollHover(pad.A)
		drawSpace.Refresh()
	end
end

if not race() then
	initScript()
	mainLoop()
else
	print("")
	print("Detected a race rom.") 
	print("This probably isn't allowed during races.")
	print("Did you create a race rom by mistake?")
end