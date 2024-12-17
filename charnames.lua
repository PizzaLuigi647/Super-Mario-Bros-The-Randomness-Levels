-- charnames.lua by AndrewPixel

local charnames = {}

charnames.printMyCharacter = false

-- edit this array to change the names if you're using custom characters, the number sets their gender (1 = he/him, 2 = she/her, 3 = they/them)
local base_chars = {
	{"Mario", 1},
	{"Luigi", 1},
	{"Peach", 2},
	{"Toad", 1},
	{"Link", 1},
	{"Megaman", 1},
	{"Wario", 1},
	{"Bowser", 1},
	{"Klonoa", 1},
	{"Ninja Bomberman", 1},
	{"Rosalina", 2},
	{"Snake",  1},
	{"Zelda", 2},
	{"Ultimate Rinka", 3},
	{"Uncle Broadsword", 1},
	{"Samus", 2},
}

local pronouns = {
	["they"] = {"he", "she", "they"},
	["them"] = {"him", "her", "them"},
	["their"] = {"his", "her", "their"},	
	["are"] = {"is", "is", "are"},
	["They"] = {"He", "She", "They"},
	["Them"] = {"Him", "Her", "Them"},
	["Their"] = {"His", "Her", "Their"},
	["Are"] = {"Is", "Is", "Are"}
}

function charnames.onInitAPI()
	registerEvent(charnames, "onTick")
	registerEvent(charnames, "onMessageBox")
end


function charnames.onMessageBox(event, content, player, npc)
	local msg = content

	if msg:find("<player>") or msg:find("<they>") or msg:find("<them>") or msg:find("<their>") or msg:find("<are>") then
		msg = msg:gsub("<player>", base_chars[player.character][1])
		for k,v in pairs(pronouns) do
			msg = msg:gsub(("<" .. k .. ">"), v[base_chars[player.character][2]])
		end

		event.cancelled = true
		Text.showMessageBox(msg)
	end
end

function charnames.onTick()
	-- set charnames.printMyCharacter = true to display the current character's name and pronouns.
	if charnames.printMyCharacter then
		Text.print((base_chars[player.character][1] .. " (" .. pronouns["they"][base_chars[player.character][2]] .. "/" .. pronouns["them"][base_chars[player.character][2]] .. ")"), 20, 60)
	end
end


return charnames