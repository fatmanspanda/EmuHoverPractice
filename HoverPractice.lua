--[=[
-- Draw constants
--]=]
CANVAS_HEIGHT = 256
CANVAS_WIDTH = CANVAS_HEIGHT * 2
AXIS_HEIGHT = CANVAS_HEIGHT / 2
CANVAS_PAD = 3
ZOOM = 2 -- resize of bar
MAX_BAR = ZOOM * 40 -- max bar size drawn
BAR_THICC = ZOOM * 4-- thickness of bars
BAR_PAD = ZOOM * 1-- distance between bars
MOST_BARS = 20 -- max number of bars drawn
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
boot = {}

function boot.new()
	local self = {}

	local up = 0
	local down = 0
	function self.pressed()
		up = up + 1
	end

	function self.offed()
		down = down + 1
	end

	function self.up()
		return up
	end

	function self.down()
		return down
	end

	return self
end

--[=[
-- Tracks boots actions
--]=]
boots_list = {}

function boots_list.shift_and_add()
	for i = MOST_BARS, 2, -1 do
		boots_list[i] = boots_list[i-1]
	end

	boots_list[1] = boot.new()
end

-- End of hover objects

--[=[
-- Draws the canvas
--]=]
function drawData()
	drawSpace.Clear(0xFF000000)
	drawSpace.DrawLine(0, AXIS_HEIGHT, CANVAS_WIDTH, AXIS_HEIGHT, WHITE)

	for i = 1, MOST_BARS do
		local b = boots_list[i]
		if (b) then
			local x = CANVAS_WIDTH - (i * ( ZOOM * (BAR_THICC + BAR_PAD) ))
			local h_up = b.up()
			local h_down = b.down()
			if (h_up >= 0) then
				local h_up_draw = h_up * ZOOM
				if (h_up_draw > MAX_BAR) then
					h_up_draw = MAX_BAR
				end
				local color = (h_up <= MAX_HOLD) and GREEN or RED
				drawSpace.DrawRectangle(x, AXIS_HEIGHT - 1 - h_up_draw, BAR_THICC * ZOOM, h_up_draw, color, color)
			end
			if (h_down >= 0) then
				local h_down_draw = h_down * ZOOM
				if (h_down_draw > MAX_BAR) then
					h_down_draw = MAX_BAR
				end
				local color = (h_down <= MAX_RELEASE) and GREEN or RED
				drawSpace.DrawRectangle(x, AXIS_HEIGHT + 1, BAR_THICC * ZOOM, h_down_draw, color, color)
			end
		end
	end

	drawSpace.DrawText(100, AXIS_HEIGHT + 30, "Streak: " .. current_streak, WHITE)
	drawSpace.DrawText(100, AXIS_HEIGHT + 45, "Best: " .. best_streak, WHITE)
	drawSpace.DrawText(100, AXIS_HEIGHT + 60, "Previous good: " .. previous_good_streak, WHITE)
end

--[=[
-- Controls objects used to track hover success
--]=]
function pollHover(held)
	held = held or false
	local b = boots_list[1]
	local reset_streak = false

	if (held == true) then
		if (a_held and b) then
			b.pressed()
			current_time = current_time + 1
			if (current_time > MAX_HOLD) then
				reset_streak = true
			end
		else
			current_streak = current_streak + 1
			if (current_streak > best_streak) then
				best_streak = current_streak
			end
			current_time = 1
			boots_list.shift_and_add()
			boots_list[1].pressed()
		end
	elseif (b) then -- hmmmm
		b.offed()
		if (a_held) then
			current_time = -1
		else
			current_time = current_time - 1
			if (current_time < -1) then
				reset_streak = true
			end
		end
	end

	if (reset_streak) then
		if (current_streak >= GOOD_STREAK) then
			previous_good_streak = current_streak
		end
		current_streak = 0
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