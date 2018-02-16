__HOVER_VERSION = "1.5"

-- canvas
local CANVAS_HEIGHT = 256
local CANVAS_WIDTH = CANVAS_HEIGHT * 2
local AXIS_HEIGHT = CANVAS_HEIGHT / 2 - 20

-- bars
local ZOOM = 2 -- resize of bar
local MAX_BAR = ZOOM * 40 -- max bar size drawn
local BAR_THICC = ZOOM * 4-- thickness of bars
local BAR_PAD = ZOOM * 1 -- distance between bars
local MOST_BARS = 25 -- max number of bars drawn

-- text
local STATS_X = 2
local STATS_DIFF = 15
local STATS_Y = CANVAS_HEIGHT / 2 - 20
local STREAK_Y = STATS_Y + (STATS_DIFF * 2)
local BEST_Y = STATS_Y + (STATS_DIFF * 3)
local GOOD_Y = STATS_Y + (STATS_DIFF * 4)

-- colors
local BAD = 0xAAC80000
local GOOD = 0xAA00F0F8
local PERFECT = 0xFFF0F000
local WHITE = 0xFFF8F8F8

-- hovering
local MAX_HOLD = 29 -- frames A can be held for before failing
local MAX_RELEASE = 1 -- frames A can be released for before failing
local GOOD_STREAK = 10 -- minimum length of a streak considered good
local MAX_HOLD_HEIGHT = AXIS_HEIGHT - MAX_HOLD * ZOOM - 1 -- axis for max hold time
local BEST_OFFSET = 22

-- prizes
local LOST_RUPEES = 10
local LOST_MESSAGE = string.format("OUCH! Lost %s rupees", LOST_RUPEES)

-- checks
local HP_ADDR = 0xF36D
local Y_POS_ADDR = 0x0020
local STATUS_ADDR = 0x005B
local RUPEE_ADDR = 0xF360

-- default values
local STATE_HP = 0x60 -- redefined later
local STATE_Y_POS = 0x164F
local FELL_Y_POS = 0x161D
local RELOAD_THRESHOLD = FELL_Y_POS + 20
local DEFAULT_CAMERA = 0x78
local ROOM_ID = 0xB4 -- outside trinexx

-- meta stuff
local HR_LENGTH = 35;
local CONSOLE_SEP = string.rep("-", HR_LENGTH) .. "\n"
local CONSOLE_SEP_BIG = string.rep("=", HR_LENGTH) .. "\n"

local ACCEPTED_ROM_HASHES = {
	V8 = {
			"D487184ADE4C7FBE65C1F7657107763E912019D4",
		},
	V9 = {
			"DE609C29B49B5904EEECFC3232422698664A9942",
			"B246AB3217FF6095166E1D074C91D640B767F713",
			"65F08E3D942C33203CED2CBE36A74BEF8E72AAF6",
			"45F097A40AD477253D15E6EA3DB21EC62BE910F8",
		},
	V9_SD2SNES = {
			"35EB77FF5E78BBF29D560443BE77660A2D6D5CA9",
			"4CBC01D01D701D9399849A29EB4AA34EE99324BE",
		},
	}

--[=[
-- hover tracking
--]=]
local running = false
local a_held = false
local current_time = 0
local current_streak = 0
local previous_good_streak = 0
local best_streak = 0
local ballsy_streak = 0 -- your streak while over a pit
local best_diff = 25
local best_distance = bit.band(STATE_Y_POS, 0x01FF) + BEST_OFFSET + best_diff

-- compare hash to known practice hack hashes
local function verify_practice_rom()
	local h = gameinfo.getromhash()

	for k, l in pairs(ACCEPTED_ROM_HASHES) do
		for _, v in ipairs(l) do
			if h == v then return true end
		end
	end

	return false
end -- verify_practice_rom

-- resets position and status
local function load_hover_position()
	memory.writebyte(0x002F, 0x02) -- face down

	-- horizontal stuff
	memory.write_u16_le(0x0022, 0x0878) -- position
	memory.write_u16_le(0x00E2, 0x0800) -- camera
	memory.write_u16_le(0x061C, 0x007F) -- camera
	memory.write_u16_le(0x061E, 0x0081) -- camera

	--vertical stuff
	memory.write_u16_le(Y_POS_ADDR, STATE_Y_POS) -- position
	memory.write_u16_le(0x00E8, 0x1600) -- camera
	memory.write_u16_le(0x0618, 0x0078) -- camera
	memory.write_u16_le(0x061A, 0x007A) -- camera

	-- set link to not falling
	memory.writebyte(STATUS_ADDR, 0x00)
	memory.writebyte(0x005D, 0x00)
	memory.writebyte(0x005E, 0x00)

	memory.writebyte(HP_ADDR, STATE_HP) -- reset HP
end -- load_hover_position

-- the tin
local function wait_some_frames(w)
	for i = 0, w do emu.frameadvance() end
end -- wait_some_frames

-- brings you to correct location by navigating the menu
local function go_to_tr()
	gui.addmessage("This is your captain speaking:")
	gui.addmessage("Please sit back while we navigate to our destination.")

	-- unpause and super speed
	client.unpause()
	client.speedmode(1000)
	
	-- menu cursor wram addresses and target values for trinexx preset
	local menu_cursors = {
			{ addr = 0x0648, target = 0 },
			{ addr = 0x064A, target = 22 },
			{ addr = 0x064C, target = 24 }
		}

	local c = 1 -- controller id

	joypad.set({ Start = true }, c) -- open item menu, which can also close hack menu
	wait_some_frames(15) -- wait for menu

	joypad.set({ R = true, Start = true }, c) -- open hack menu
	wait_some_frames(40) -- wait for menu to open

	for _, v in ipairs(menu_cursors) do -- for each menu
		memory.writebyte(v.addr, v.target) -- set cursor location to desired option
		wait_some_frames(3) -- just in case
		joypad.set( { A = true }, c ) -- select next menu
	end

	joypad.set({ A = true }, c ) -- press A

	gui.addmessage("Ready for take off...")
	wait_some_frames(200) -- wait for area to load
	memory.write_u16_le(RUPEE_ADDR, 0x0000) -- set rupees to 0
	memory.writebyte(0xF36E, 0x00) -- drain magic
	memory.writebyte(0x037F, 0x00) -- turn off walk through walls

	wait_some_frames(80) -- rupee drain
	client.speedmode(100)
	gui.addmessage("This is your captain speaking:")
	gui.addmessage("We have arrived safely.")
	gui.addmessage("You may assume control.")
end -- go_to_tr

local function read_hp()
	return memory.readbyte(HP_ADDR)
end -- read_hp

local function read_y_pos()
	return memory.readbyte(LOCATION_ADDRESS)
end -- read_y_pos

local function stop_running()
	running = false
end -- stop_running

local function end_practice()
	the_canvas.DrawNew("native") -- effectively clears the canvas
	the_canvas.DrawFinish()
	client.SetClientExtraPadding(0, 0, 0, 0)

	print(
			"Hover Practice script terminated.\n" ..
			CONSOLE_SEP_BIG
		)
	stop_running()
end -- end practice

local function initialize()
	running = true

	client.SetClientExtraPadding(0, 0, CANVAS_WIDTH, 0)
	the_canvas = gui

	memory.usememorydomain("WRAM") -- everything we need is in WRAM
	go_to_tr() -- we're off to see the wizard
	STATE_HP = read_hp() -- load the HP you should have in the preset
	load_hover_position()

	event.onexit(end_practice)

	print(
			"Hover Practice started\n" ..
			"Press L+R to terminate\n"
		)
end -- initialize

--[=[
-- object for each hover "press"
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

	function self.up() return up end
	function self.down() return down end

	return self
end -- boot.new

-- tracks boots actions
boots_list = {}

function boots_list.shift_and_add()
	for i = MOST_BARS, 2, -1 do
		boots_list[i] = boots_list[i-1]
	end

	boots_list[1] = boot.new()
end -- shift_and_add

--[=[
-- draws the canvas
--]=]
local function draw_data()
	the_canvas.DrawNew("native")
	local offset = client.bufferwidth() * client.getwindowsize()
	local text_y_offset = client.bufferwidth() > 1 and 30 or 0
	local max_height = client.bufferheight() * client.getwindowsize() - 2

	the_canvas.drawLine(offset + 0, AXIS_HEIGHT, offset + CANVAS_WIDTH, AXIS_HEIGHT, WHITE) -- axis
	the_canvas.drawLine(offset + 0, MAX_HOLD_HEIGHT, offset + CANVAS_WIDTH, MAX_HOLD_HEIGHT, BAD) -- max hold threshold
	the_canvas.drawLine(offset + 0, AXIS_HEIGHT + ZOOM * 2, offset + CANVAS_WIDTH, AXIS_HEIGHT + ZOOM * 2, BAD) -- max release threshold

	local camera_position = memory.read_u16_le(0x0618)
	local best_marker = (DEFAULT_CAMERA + best_distance - camera_position) * client.getwindowsize()
	local best_color = PERFECT

	if best_marker > max_height then
		best_marker = max_height - 2
		best_color = GOOD
	end

	the_canvas.drawText(0, best_marker - 16, "BEST: " .. best_diff, best_color)
	the_canvas.drawLine(0, best_marker, offset, best_marker, best_color) -- best distance

	for i = 1, MOST_BARS do
		local b_test = boots_list[i]

		if b_test then
			local x = offset + CANVAS_WIDTH - (i * ( ZOOM * (BAR_THICC + BAR_PAD) ))
			local h_up = b_test.up()
			local h_down = b_test.down()

			if h_up >= 0 then
				local h_up_draw = h_up * ZOOM

				if h_up_draw > MAX_BAR then
					h_up_draw = MAX_BAR
				end

				local color = (h_up <= MAX_HOLD) and ((h_up == 1) and PERFECT or GOOD) or BAD
				the_canvas.drawRectangle(x, AXIS_HEIGHT - 1 - h_up_draw, BAR_THICC * ZOOM, h_up_draw, color, color)
			end -- hold bar

			if h_down >= 0 then
				local h_down_draw = h_down * ZOOM

				if h_down_draw > MAX_BAR then
					h_down_draw = MAX_BAR
				end

				local color = (h_down <= MAX_RELEASE) and GOOD or BAD
				the_canvas.drawRectangle(x, AXIS_HEIGHT + 1, BAR_THICC * ZOOM, h_down_draw, color, color)
			end -- release bar
		end -- bar check
	end -- bar loop

	the_canvas.drawText(offset + STATS_X, text_y_offset + STREAK_Y, "Streak: " .. current_streak, WHITE)
	the_canvas.drawText(offset + STATS_X, text_y_offset + BEST_Y, "Best: " .. best_streak, WHITE)
	the_canvas.drawText(offset + STATS_X, text_y_offset + GOOD_Y, "Previous good: " .. previous_good_streak, WHITE)
end -- draw_data

-- checks to see if Link's status is set to default
local function in_control()
	local falling = memory.readbyte(STATUS_ADDR)
	return falling == 0x00 or falling == 0x01
end -- in_control

-- checks if we've gone farther than the default position and are controllable to decide rupee eligibility
local function is_eligible()
	local ret = false
	local y_pos = memory.read_u16_le(Y_POS_ADDR)
	local diff = y_pos - STATE_Y_POS
	if diff > 0 then
		ret = true
		if diff > best_diff then
			best_diff = diff
			best_distance = bit.band(y_pos, 0x01FF) + BEST_OFFSET
		end
	end

	return ret
end -- is_eligible

-- reset streaks to 0 and award rupees
local function reset_streak()
	if current_streak >= GOOD_STREAK then
		previous_good_streak = current_streak

		if ballsy_streak > 0 then -- prizes
			local r = memory.read_u16_le(RUPEE_ADDR)
			local earned = 0
			earned = earned + ballsy_streak / 2


			earned = math.floor(earned) -- kill decimals

			r = r + earned
			if r > 999 then r = 999 end -- don't go above max rupees

			memory.write_u16_le(RUPEE_ADDR, r)
			gui.addmessage("Earned " .. earned .. " rupee" .. (earned ~= 1 and "s" or ""))
		end -- ballsy check
	end -- good streak check

	current_streak = 0
	ballsy_streak = 0
end -- reset_streak

--[=[
-- controls objects used to track hover success
--]=]
local function analyze_hover(held)
	held = held or false
	local b_test = boots_list[1]

	if held then
		if a_held and b_test then
			b_test.pressed()
			current_time = current_time + 1

			if current_time > MAX_HOLD then
				reset_streak()
			end
		else
			current_streak = current_streak + 1

			if is_eligible() then
				ballsy_streak = ballsy_streak + 1
			end

			if current_streak > best_streak then
				best_streak = current_streak
			end

			current_time = 1
			boots_list.shift_and_add()
			boots_list[1].pressed()
		end -- a_held test
	elseif b_test then
		b_test.offed()

		if a_held then
			current_time = -1
		else
			current_time = current_time - 1

			if current_time < -1 then
				reset_streak()
			end
		end -- a_held test
	end -- held / b_test check

	a_held = held
end -- analyze_hover

local function did_he_fall()
	local hp = read_hp()
	if hp ~= STATE_HP and in_control() and memory.read_u16_le(Y_POS_ADDR) <= RELOAD_THRESHOLD then
		load_hover_position()

		local r = memory.read_u16_le(RUPEE_ADDR)
		local lost = r > 0

		if lost then
			r = r - LOST_RUPEES
			if r < 0 then r = 0 end
			memory.write_u16_le(RUPEE_ADDR, r)
			gui.addmessage(LOST_MESSAGE)
		else
			gui.addmessage("OUCH!")
		end -- lost

		ballsy_streak = 0 -- position is confused while falling
	end -- hp check
end -- did_he_fall

--[=[
-- stuff gets glitchy trying to move Link in other rooms
-- so just kill the script if we leave the room before Trinexx
--]=]
local function validate_room()
	if memory.readbyte(0x00A0) ~= ROOM_ID then
		gui.addmessage("You have left the practice area.")
		stop_running()
	end
end

local function do_main()
	while running do
		emu.frameadvance()

		pad = joypad.get(1)
		analyze_hover(pad.A)
		draw_data()

		if emu.framecount() % 20 == 0 then -- let's not overwork the emulator with memory checks
			did_he_fall()
			if emu.framecount() % 60 == 0 then
				validate_room()
			end
		end

		the_canvas.DrawFinish()

		if pad.L and pad.R then -- L+R to quit
			stop_running()
		end
	end -- running loop
end -- do_main

print(
		CONSOLE_SEP_BIG ..
		"= Hover Practice " .. __HOVER_VERSION .. "\n" ..
		CONSOLE_SEP_BIG
	)
if verify_practice_rom() then
	initialize()
	do_main()
else
	print(
			CONSOLE_SEP..
			"Unwilling to run Hover Practice\n" ..
			CONSOLE_SEP ..
			"This is not the LTTP NMG practice hack\n" ..
			"Please download this hack from https://milde.no/lttp/\n" ..
			"\n" ..
			"If you are indeed running the practice hack, please open an issue at:\n" ..
			"https://github.com/fatmanspanda/EmuHoverPractice/issues\n" ..
			"\n" ..
			"This script is not expected to work on beta versions of the hack.\n" ..
			"Hash:\n" ..
			gameinfo.getromhash() ..
			"\n" ..
			"The following versions are expected to work:\n"
		)
	for k, _ in pairs(ACCEPTED_ROM_HASHES) do
		print(k)
	end
	print(CONSOLE_SEP_BIG)
end