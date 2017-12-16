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

if not race() then
	initScript()
	mainLoop()
else
	print("")
	print("Detected a race rom.") 
	print("This probably isn't allowed during races.")
	print("Did you create a race rom by mistake?")
end

function initScript()
	drawSpace = gui.createcanvas(256,256)
	drawSpace.Clear(0xFF000000)
	
	client.SetClientExtraPadding(0,20,0,20)
	client.displaymessages(true)
end

function mainLoop()
	while true do
		emu.frameadvance()
		pad = joypad.get(1)
		
		pollHover(pad.A)
	end
end

--[=[
-- Draw constants
--]=]
MAX_BAR = 40 -- max bar size drawn
ZOOM = 2 -- resize of bar

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
current_streak = 0
previous_good_streak = 0
best_streak = 0