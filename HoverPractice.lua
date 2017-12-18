--[=[
-- Draw constants
--]=]
-- Canvas
CANVAS_HEIGHT = 256
CANVAS_WIDTH = CANVAS_HEIGHT * 2
AXIS_HEIGHT = CANVAS_HEIGHT / 2

-- Bars
ZOOM = 2 -- resize of bar
MAX_BAR = ZOOM * 40 -- max bar size drawn
BAR_THICC = ZOOM * 4-- thickness of bars
BAR_PAD = ZOOM * 1 -- distance between bars
MOST_BARS = 25 -- max number of bars drawn

-- Text
STATS_X = 50
STATS_DIFF = 15
STATS_Y = CANVAS_HEIGHT / 2 + 15
STREAK_Y = STATS_Y + (STATS_DIFF * 2)
BEST_Y = STATS_Y + (STATS_DIFF * 3)
GOOD_Y = STATS_Y + (STATS_DIFF * 4)

-- Colors
RED = 0xFFFF0000
GREEN = 0xFF00FF00
WHITE = 0xFFFFFFFF

--[=[
-- Hovering constants
--]=]
MAX_HOLD = 30 -- frames A can be held for before failing
MAX_HOLD_HEIGHT = AXIS_HEIGHT - 1 - MAX_HOLD * ZOOM
MAX_RELEASE = 1 -- frames A can be released for before failing
GOOD_STREAK = 10 -- minimum length of a streak considered good

-- checks
HP_ADDRESS = 0x04DB
STATE_HP = 0 -- done later

--[=[
-- Hover tracking
--]=]
a_held = false
current_time = 0
current_streak = 0
previous_good_streak = 0
best_streak = 0

--[=[
-- meta stuff
--]=]
RUNNING = false
CONSOLE_SEP = "----------------------------------\n"
ACCEPTED_ROM_HASHES = {
	"D487184ADE4C7FBE65C1F7657107763E912019D4"
}

-- compare hash to know practice hack hashes
function verifyPracticeHack()
	local ret = false
	local h = gameinfo.getromhash()

	for _, v in ipairs(ACCEPTED_ROM_HASHES) do
		if (h == v) then
			ret = true
			break
		end
	end

	return ret
end

function readHP()
	return memory.read_u8(HP_ADDRESS)
end

RUNNING = true
function initScript()
	RUNNING = true
	loadHoverState()
	memory.usememorydomain("WRAM")
	STATE_HP = readHP() -- load the HP you should have in the save state

	drawSpace = gui.createcanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
	drawSpace.SetTitle("Hover practice")
	drawSpace.Clear(0xFF000000)
	drawSpace.set_TopMost(true)
	drawSpace.add_FormClosing(endPractice)
end

function loadHoverState()
	savestate.load("./HoverPractice.State")
end

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

--[======================[
-- End of hover objects
--]======================]

--[=[
-- Draws the canvas
--]=]
function drawData()
	drawSpace.Clear(0xFF000000)
	drawSpace.DrawLine(0, AXIS_HEIGHT, CANVAS_WIDTH, AXIS_HEIGHT, WHITE)
	drawSpace.DrawLine(0, MAX_HOLD_HEIGHT, CANVAS_WIDTH, MAX_HOLD_HEIGHT, RED)

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

	drawSpace.DrawText(STATS_X, STREAK_Y, "Streak: " .. current_streak, WHITE)
	drawSpace.DrawText(STATS_X, BEST_Y, "Best: " .. best_streak, WHITE)
	drawSpace.DrawText(STATS_X, GOOD_Y, "Previous good: " .. previous_good_streak, WHITE)
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

function did_he_fall()
	local hp = readHP()
	if (hp ~= STATE_HP) then
		loadHoverState()
	end
end

function endPractice()
	RUNNING = false
	drawSpace.Dispose()
	print(
			"Hover Practice script terminated\n"..
			CONSOLE_SEP
		)
end

function mainLoop()
	print(
			string.gsub(CONSOLE_SEP, "%-", "=")..
			"Hover practice started\n"..
			"Press L+R to terminate\n"
		)
	while RUNNING do
		emu.frameadvance()
		pad = joypad.get(1)
		pollHover(pad.A)

		if (emu.framecount() % 20 == 0) then -- let's not overwork the emulator with memory checks
			did_he_fall()
		end

		drawSpace.Refresh()

		if (pad.L and pad.R) then -- L+R to quit
			endPractice()
		end
	end
end


if verifyPracticeHack() then
	initScript()
	mainLoop()
else
	print(
			CONSOLE_SEP..
			"-- Unwilling to run Hover Practice\n"..
			CONSOLE_SEP..
			"This is not the LTTP NMG practice hack\n"..
			"Please download this hack from https://milde.no/lttp/\n"..
			"\n"..
			"If you are indeed running the practice hack, please open an issue at:\n"..
			"https://github.com/fatmanspanda/EmuHoverPractice/issues\n"..
			"\n"..
			"This script is not expected to work on beta versions of the hack.\n"..
			"Hash:\n"..
			gameinfo.getromhash()..
			CONSOLE_SEP
		)
end