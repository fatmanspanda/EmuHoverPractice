--[=[
-- Draw constants
--]=]
-- Canvas
local CANVAS_HEIGHT = 256
local CANVAS_WIDTH = CANVAS_HEIGHT * 2
local AXIS_HEIGHT = CANVAS_HEIGHT / 2

-- Bars
local ZOOM = 2 -- resize of bar
local MAX_BAR = ZOOM * 40 -- max bar size drawn
local BAR_THICC = ZOOM * 4-- thickness of bars
local BAR_PAD = ZOOM * 1 -- distance between bars
local MOST_BARS = 25 -- max number of bars drawn

-- Text
local STATS_X = 50
local STATS_DIFF = 15
local STATS_Y = CANVAS_HEIGHT / 2 + 15
local STREAK_Y = STATS_Y + (STATS_DIFF * 2)
local BEST_Y = STATS_Y + (STATS_DIFF * 3)
local GOOD_Y = STATS_Y + (STATS_DIFF * 4)

-- Colors
local RED = 0xAAC80000
local GREEN = 0xAA20C828
local WHITE = 0xFFF8F8F8

--[=[
-- Hovering constants
--]=]
local MAX_HOLD = 30 -- frames A can be held for before failing
local MAX_HOLD_HEIGHT = AXIS_HEIGHT - MAX_HOLD * ZOOM -- bar for max hold time
local MAX_RELEASE = 1 -- frames A can be released for before failing
local GOOD_STREAK = 10 -- minimum length of a streak considered good

-- Checks
local HP_ADDRESS = 0xF36D
local STATE_HP = 0x60 -- filled later; default 120

--[=[
-- Hover tracking
--]=]
local a_held = false
local current_time = 0
local current_streak = 0
local previous_good_streak = 0
local best_streak = 0

--[=[
-- meta stuff
--]=]
local RUNNING = false
local CONSOLE_SEP = "----------------------------------\n"
local ACCEPTED_ROM_HASHES = {
	"D487184ADE4C7FBE65C1F7657107763E912019D4"
}

-- compare hash to know practice hack hashes
local function verifyPracticeHack()
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

-- loads a save state
local function loadHoverState()
	-- Face down
	memory.writebyte(0x002F, 0x02)

	-- Horizontal position stuff
	memory.write_u16_be(0x0022, 0x7808)
	memory.write_u16_be(0x00E2, 0x0008)
	memory.write_u16_be(0x061C, 0x7F00)
	memory.write_u16_be(0x061E, 0x8100)

	-- Vertical position stuff
	memory.write_u16_be(0x0020, 0x4F16)
	memory.write_u16_be(0x00E8, 0x0016)
	memory.write_u16_be(0x0618, 0x7800)
	memory.write_u16_be(0x061A, 0x7A00)

	-- Set link to not falling
	memory.writebyte(0x005B, 0x00)
	memory.writebyte(0x005D, 0x00)
	memory.writebyte(0x005E, 0x00)

	-- Stop slashing
	memory.writebyte(0x0372, 0x00)

	-- advance one frame
	emu.frameadvance()

	-- Reset HP
	memory.writebyte(HP_ADDRESS, STATE_HP)
end

-- brings you to correct location by navigating the menu
local function go_to_tr()
	gui.addmessage("This is your captain speaking.")
	gui.addmessage("Please sit back while we navigate to our destination")

	-- menu cursor vram addresses and target values for trinexx preset
	local menu_cursors = {
		{ addr = 0x0648, target = 0 },
		{ addr = 0x064A, target = 22 },
		{ addr = 0x064C, target = 24 }
	}

	for _, v in ipairs(menu_cursors) do
		memory.writebyte(v.addr, 4) -- filled with random value to not be target
	end

	-- controller location
	local c = 1
	joypad.set( { R = true, Start = true }, c ) -- open hack menu

	-- wait function
	local function waitFrames(w)
		for i=0, w do
			emu.frameadvance()
		end
	end

	waitFrames(40) -- wait for menu to open
	for _, v in ipairs(menu_cursors) do -- for each menu
		memory.writebyte(v.addr, v.target) -- set cursor location
		
		waitFrames(3)
		joypad.set( { A = true }, c ) -- press A
	end

	joypad.set( { A = true }, c ) -- press A

	gui.addmessage("Ready for take off...")
	waitFrames(220) -- more waiting
	memory.write_u16_be(0xF360, 0x0000) -- set rupees to 0

	gui.addmessage("This is your captain speaking.")
	gui.addmessage("We have arrived safely.")
	gui.addmessage("You may assume control.")
end

-- reads hp from WRAM
local function readHP()
	return memory.read_u8(HP_ADDRESS)
end

local function endPracticeMessage()
	drawSpace.Dispose()
	print(
			"Hover Practice script terminated\n"..
			CONSOLE_SEP
		)
end

local function endPractice()
	RUNNING = false
	endPracticeMessage()
end

local function initScript()
	RUNNING = true
	memory.usememorydomain("WRAM")

	go_to_tr() -- we're off to see the wizard
	STATE_HP = readHP() -- load the HP you should have in the save state
	loadHoverState()

	drawSpace = gui.createcanvas(CANVAS_WIDTH, CANVAS_HEIGHT)
	drawSpace.SetTitle("Hover practice")
	drawSpace.Clear(0xFF000000)
	drawSpace.set_TopMost(true)
	drawSpace.add_FormClosing(endPractice)

	event.onexit(endPracticeMessage)
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
local function drawData()
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
				local color = (h_up < MAX_HOLD) and GREEN or RED
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
local function pollHover(held)
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

			-- prizes
			local r = memory.read_u16_le(0xF360)
			local earned = (current_streak - (current_streak % 10)) / 10 -- pls give me Lua 5.3 for int division
			memory.write_u16_le(0xF360, r + earned)
			gui.addmessage("Earned " .. earned .. " rupee" .. (earned ~= 1 and "s" or ""))
		end

		current_streak = 0
	end

	a_held = held

	drawData()
end

local function did_he_fall()
	local hp = readHP()
	if (hp ~= STATE_HP) then
		loadHoverState()
		gui.addmessage("OUCH!")
	end
end

local function mainLoop()
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