--[[
	Simple (Bowser's Fury-Styled) Inventory
	Originally based on Coldcolor's Fury Inventory, with a complete overhaul done by me (with some coding help from cool people like Marioman2007 and KBM-Quine)
	Please credit both Coldcolor and myself (Lurrae) if you use this inventory system!
	
	Changes that I made:
	1. By default, all powerups have a max supply of 99, rather than 10 for Super Mushrooms and 5 for everything else
	2. Powerup images are loaded dynamically, which leads into the next change...
	3. Support was added for powerups made using customPowerups.lua! This means that powerups from The Rip Lair's Powerup Pack can be added to this inventory!
		3.1. Support was also added for the Starman and Mega Mushroom, though both are disabled by default in the library's settings, as allowing the player to bring either of those wherever they want would be pretty OP
		3.2. The Cloud Flower has special behavior that ensures it doesn't get added to the inventory when the player collects one with less than a full number of cloud followers. This can be disabled with the settings!
	4. The sound effects are loaded in the same way as the images, making them much easier to rename/replace if you so desire
	5. Tons of new functions were added! For example, instead of doing SaveData.inventory.shroom = SaveData.inventory.shroom + 5 to add 5 Super Mushrooms to the player's inventory, you can call inventory.addItem("mushroom", 5)! This and all the other functions are detailed below
		5.1. On top of the new functions, I added several custom events! These should make it super easy to interact with the inventory without having to modify the library itself
		5.2. In addition to functions and events, I also added settings so that most things with the inventory are fully configurable!
	6. Added several cheats, documented in more detail below. So far I have added four cheats: "emptypockets", "stockpile", "imgreedy"/"fullpockets", and "creativemode"
	7. Made it so that any vanilla cheat that adds an item to the player's reserve box (such as "needaflower") now adds it to the inventory!
]]--

local inventory = {}

-- Tracks the order in which slots should be displayed
-- Anything not here will be added at the end in whatever order it was loaded initially!
-- Note that this IS publicly accessible, it just has to be in the file above the internal methods in which it's used, so I put it way up here
inventory.slotOrder = {
	"mushroom",
	"fire",
	"ice",
	"leaf",
	"tanooki",
	"hammer"
}

--------------------------------------------------
--				Internal Variables				--
--		These need to be loaded up here,		--
-- but you shouldn't mess with them in any way! --
--------------------------------------------------

local npcutils = require("npcs/npcutils")
local hudoverride = require("hudoverride")
local textplus = require("textplus")
local modernReserveItems = require("modernReserveItems")

-- Load customPowerups if it exists
-- Unlike ModernReserveItems, customPowerups is not required for this library to function!
local customPowerups
pcall(function() customPowerups = require("customPowerups") end)

local selection = "mushroom"
local selectionID = 1
local page = 1
local activateInventory = true
local inventoryOpen = false
local selectX
local selectY
local originalInventory = {}
local creativeMode = false
local numFollowers = nil
local ignoreThisItem = false
local oldMusicVolume = 64

-- A list of aliases for every powerup, basically only used by inventory.getAlias()
-- This is not publicly accessible, since you're meant to call inventory.getAlias() instead
-- You can add to this with inventory.addAlias() though!
local aliasMap = {
	-- Super Mushroom aliases
	["shroom"] = "mushroom",
	["mushroom"] = "mushroom",
	["supershroom"] = "mushroom",
	["supermushroom"] = "mushroom",
	
	-- Fire Flower aliases
	["fire"] = "fire",
	["fireflower"] = "fire",
	
	-- Ice Flower aliases
	["ice"] = "ice",
	["iceflower"] = "ice",
	
	-- Super Leaf aliases
	["leaf"] = "leaf",
	["coonleaf"] = "leaf",
	["superleaf"] = "leaf",
	["raccoonleaf"] = "leaf",
	
	-- Tanooki Suit aliases
	["tanooki"] = "tanooki",
	["coonsuit"] = "tanooki",
	["tanookisuit"] = "tanooki",
	["raccoonsuit"] = "tanooki",
	
	-- Hammer Suit aliases
	["hammer"] = "hammer",
	["hammersuit"] = "hammer",
	["hammerbros"] = "hammer",
	["hammerbrossuit"] = "hammer",
}

-- A list of states that correspond to different powerups, only used to make the code that replicates reserve slot behavior for heart characters easier to work with
-- Custom powerups are not included here for obvious reasons
local stateMap = {
	[PLAYER_BIG] = "mushroom",
	[PLAYER_FIREFLOWER] = "fire",
	[PLAYER_ICE] = "ice",
	[PLAYER_LEAF] = "leaf",
	[PLAYER_TANOOKI] = "tanooki",
	[PLAYER_HAMMER] = "hammer"
}

local function loadOptionalSlots()
	-- Add a slot for the Starman if that is enabled
	if inventory.settings.starmanSlot then
		-- Generate a Starman slot
		-- This function does nothing and returns the existing slot's index if a slot of this name already exists, so no need to check for an existing slot!
		local starmanIdx = inventory.newSlot{name="starman", defaultPowerup=293, aliases={ "star", "superstar", "invstar", "invulnstar", "invincibilitystar", "invulnerabilitystar", }, linkedPowerups={ 559 }, overwriteMRI=true}
		
		-- Make sure to set the min storage if using the creativeMode cheat
		if creativeMode then
			SaveData.inventory[starmanIdx].minStorage = SaveData.inventory[starmanIdx].maxStorage
		end
	elseif inventory.getSlot("starman") then -- Delete the Starman slot if it exists and the config is disabled
		inventory.removeSlot("starman")
	end
	
	-- Add another slot for the Mega Mushroom if that's enabled
	if inventory.settings.megaSlot then
		-- Generate a Mega Mushroom slot
		-- This function does nothing and returns the existing slot's index if a slot of this name already exists, so no need to check for an existing slot!
		local megaIdx = inventory.newSlot{name="mega", defaultPowerup=425, aliases={ "megashroom", "megamushroom", }, overwriteMRI=true}
		
		-- Make sure to set the min storage if using the creativeMode cheat
		if creativeMode then
			SaveData.inventory[megaIdx].minStorage = SaveData.inventory[megaIdx].maxStorage
		end
	elseif inventory.getSlot("mega") then -- Delete the Mega Mushroom slot if it exists and the config is disabled
		inventory.removeSlot("mega")
	end

	-- Call the custom "onInventorySlotsGenerate" event
	EventManager.callEvent("onInventorySlotsGenerate")
end

local function loadCustomPowerups()
	-- Check if customPowerups is installed, and generate slots for its powerups if it is
	if customPowerups then
		for _,powerup in ipairs(customPowerups.getNames()) do
			local defPowerup = customPowerups.getPowerupByName(powerup).items[1]
			local newIdx = inventory.newSlot{name=powerup, defaultPowerup=defPowerup, overwriteMRI=true}

			-- Make sure to set the min storage if using the creativeMode cheat
			if creativeMode then
				SaveData.inventory[newIdx].minStorage = SaveData.inventory[newIdx].maxStorage
			end
		end
	end
end

local function drawDebug()
	local tplusFont = textplus.loadFont("textplus/font/11.ini")
	
	textplus.print{
		x = 0,
		y = 0,
		text = ""..player.reservePowerup,
		font = tplusFont
	}
	
	local offset = 20
	
	for i,v in pairs(inventory.itemMap) do
		textplus.print{
			x = 0,
			y = offset,
			text = i..": "..v,
			font = tplusFont
		}
		
		offset = offset + 20
	end
end

local function loadMissingSlots()
	inventory.newSlot{ name="mushroom", defaultPowerup=9, givenState=PLAYER_BIG, minStorage=0, maxStorage=99, quantity=0 }
	inventory.newSlot{ name="fire", defaultPowerup=14, givenState=PLAYER_FIREFLOWER, minStorage=0, maxStorage=99, quantity=0 }
	inventory.newSlot{ name="ice", defaultPowerup=264, givenState=PLAYER_ICE, minStorage=0, maxStorage=99, quantity=0 }
	inventory.newSlot{ name="leaf", defaultPowerup=34, givenState=PLAYER_LEAF, minStorage=0, maxStorage=99, quantity=0 }
	inventory.newSlot{ name="tanooki", defaultPowerup=169, givenState=PLAYER_TANOOKI, minStorage=0, maxStorage=99, quantity=0 }
	inventory.newSlot{ name="hammer", defaultPowerup=170, givenState=PLAYER_HAMMER, minStorage=0, maxStorage=99, quantity=0 }
end

local function updateSlotOrder()
	originalInventory = table.ideepclone(SaveData.inventory) -- Store the original inventory data since we'll be resetting it
	SaveData.inventory = {}
	local newSlot = 1
	
	for i,v in ipairs(inventory.slotOrder) do
		local slot = inventory.getSlot(v, originalInventory)
		--Misc.dialog(slot)
		if originalInventory[slot] then
			SaveData.inventory[newSlot] = originalInventory[slot]
			SaveData.inventory = table.ideepclone(SaveData.inventory)
			table.remove(originalInventory, slot)
			newSlot = newSlot + 1
		end
	end
	
	-- Add any remaining slots that weren't added already
	SaveData.inventory = table.append(SaveData.inventory, originalInventory)
	
	originalInventory = {}
end

local function initializeInventory()
	-- Add any and all slots we may not already have
	loadMissingSlots() -- Main six
	loadOptionalSlots() -- Mega Mushroom, Starman, and any custom slots
	loadCustomPowerups() -- Powerups from customPowerups.lua
	
	-- Use the slotOrder array to update the order the slots appear in
	updateSlotOrder()
end

-----------------------------------------
--	  Publicly Accessible Features!    --
-- You can access these from your code --
-----------------------------------------

-- All of the settings for this library are right here!
inventory.settings = {
	-- Whether or not the player should be allowed to spawn an item from their inventory when they're already in that state
	-- For example, taking a Fire Flower out of their inventory while already in Fire Flower state
	-- Default: false
	disableRepeatSpawning = false,
	
	-- Whether or not to automatically close the inventory when the player spawns a powerup
	-- Default: true
	closeOnSpawn = true,
	
	-- How many powerups are displayed per page?
	-- You can set this to any number you want, but I wouldn't recommend setting it any higher than about 12, because beyond that point the slots begin to draw offscreen
	-- Default: 10
	powerupsPerPage = 10,
	
	-- If set to true, the inventory will show icons for twice as many powerups when closed, since there's more room
	-- Default: true
	showTwoPagesWhenClosed = true,
	
	-- If set to true, the inventory will continue displaying the quantities of each item even while it's closed
	-- Default: true
	showCountsWhenClosed = true,
	
	-- At what position should the inventory HUD be displayed?
	-- The height of the HUD will control whether the full-sized inventory expands up, down, or centered from the closed HUD's position
	-- If given a height of 0-100 pixels, the inventory opens downwards. If given a height of 500+ pixels, the inventory opens upwards. Otherwise, it opens centered
	-- Note that the HUD will always draw left-to-right
	-- Default: vector(20, 536); this places the HUD at the bottom-right of the screen
	hudPosition = vector(20, 536),
	
	-- Adds an additional inventory slot for the Starman
	-- Unless "collectableStarmans" is also true, the only way to put a Starman in the player's inventory is to manually call inventory.addItem("starman") from your own code
	-- Default: false
	starmanSlot = false,
	
	-- Replaces the behavior when a player touches a Starman; instead of immediately entering the invulnerable star state, the Starman is put into the player's inventory
	-- This is disabled by default for a reason- this is a VERY dangerous feature to allow, as if you don't design your levels with having access to a Starman in mind, the levels may get broken by players smuggling Starmans from other levels
	-- Default: false
	collectableStarmans = false,
	
	-- Adds an additional inventory slot for the Mega Mushroom
	-- Unless "collectableMegas" is also true, the only way to put a Mega Mushroom in the player's inventory is to manually call inventory.addItem("mega") from your own code
	-- Default: false
	megaSlot = false,
	
	-- Replaces the behavior when a player touches a Mega Mushroom; instead of immediately entering the mega state, the Mega Mushroom is put into the player's inventory
	-- As with collectableStarmans, it's not recommended that you enable this unless you intend to design every level with the Mega Mushroom in mind
	-- Default: false
	collectableMegas = false,
	
	-- Are the custom cheats added by this library allowed for general player use?
	-- Detailed documentation on these cheats is included below! The names of the current cheats are "emptypockets", "stockpile", "imgreedy"/"fullpockets", and "creativemode"
	-- Default: true
	enableCheats = true,
	
	-- Where is each image file stored?
	-- To use a vanilla graphic, you should be able to do Graphics.sprite.type[id].img, replacing "type" with the type of graphic you want (npc, for example) and "id" with the ID of the thing (like 9 for a Super Mushroom sprite)
	images = {
		panel = Graphics.loadImage(Misc.resolveFile("inventory/panel.png")),
		selector = Graphics.loadImage(Misc.resolveFile("inventory/selector.png"))
	},
	
	-- Where is each audio file stored?
	-- If you want to use a vanilla sound, I think you can set these to a number instead of a "Misc.resolveFile" thing
	sounds = {
		errorSFX = Misc.resolveFile("inventory/error.wav"),
		closeSFX = Misc.resolveFile("inventory/invclose.wav"),
		openSFX = Misc.resolveFile("inventory/invopen.wav"),
		menuSFX = Misc.resolveFile("inventory/menuselect.wav"),
		selectSFX = Misc.resolveFile("inventory/powerupselect.wav")
	},
	
	-- What color should be used to tint the item sprite in slots with 0 items?
	-- By default, this makes all powerups a pitch-black silhouette
	noItemsTint = Color.black,
	
	-- Whether or not characters with hearts (i.e, Peach, Toad, and Link) must have full hearts before items for their current state can be sent into their inventory
	-- For example, if Fire Peach collects a Fire Flower while at 2 hearts, she gains a third heart. With this set to true, the collected Fire Flower will not enter Peach's inventory,
	-- but if this is false it WILL enter her inventory despite being "consumed" to add an extra heart
	-- Default: true
	needsFullHearts = true,
	
	-- If customPowerups.lua is enabled, setting this to true prevents Cloud Flowers from entering the player's inventory unless the powerup is collected while the player has three mini-clouds following them
	-- This is more or less the same type of setting as "needsFullHearts", but is a separate setting in case you want to disable one but not the other!
	-- Default: true
	needsFullClouds = true,
	
	-- If enabled, powerups will be "unlocked" the first time they're collected and become permanently reusable, rather than storing a limited quantity of them
	-- This allows for episodes styled after games like Metroid, Kirby Super Star's Milky Way Wishes, or Hollow Knight, where powerups are used as permanent upgrades in some way
	-- Default: false
	metroidvaniaMode = false
}

-- Store all of the important inventory information in SaveData, so it can be easily loaded later
SaveData.inventory = SaveData.inventory or {
	{ name="mushroom", defaultPowerup=9, givenState=PLAYER_BIG, minStorage=0, maxStorage=99, quantity=0 },
	{ name="fire", defaultPowerup=14, givenState=PLAYER_FIREFLOWER, minStorage=0, maxStorage=99, quantity=0 },
	{ name="ice", defaultPowerup=264, givenState=PLAYER_ICE, minStorage=0, maxStorage=99, quantity=0 },
	{ name="leaf", defaultPowerup=34, givenState=PLAYER_LEAF, minStorage=0, maxStorage=99, quantity=0 },
	{ name="tanooki", defaultPowerup=169, givenState=PLAYER_TANOOKI, minStorage=0, maxStorage=99, quantity=0 },
	{ name="hammer", defaultPowerup=170, givenState=PLAYER_HAMMER, minStorage=0, maxStorage=99, quantity=0 }
}

-- This table, more or less taken from Marioman2007 and Emral's customPowerups.lua, maps item IDs to inventory slots, so we can easily determine which slot to add to when an item is collected
inventory.itemMap = {
	[9]   = "mushroom", -- SMB3 Super Mushroom
	[184] = "mushroom", -- SMB1 Super Mushroom
	[185] = "mushroom", -- SMW Super Mushroom
	[249] = "mushroom", -- SMB2 Super Mushroom
	[250] = "mushroom", -- Zelda Heart

	[14]  = "fire", -- SMB3 Fire Flower
	[182] = "fire", -- SMB1 Fire Flower
	[183] = "fire", -- SMW Fire Flower

	[264] = "ice", -- SMB3 Ice Flower
	[277] = "ice", -- SMW Ice Flower

	[34]  = "leaf", -- Super Leaf
	[169] = "tanooki", -- Tanooki Suit
	[170] = "hammer" -- Hammer Suit
}

-- Maps NPC IDs to Yoshi color IDs, used to determine the frame of yoshi egg to use
-- You can add more NPC IDs to this if you want to map other NPCs to specific colored Yoshi eggs, but other than that you probably shouldn't edit this
inventory.yoshiID = {
	[95] = 0, -- Green Yoshi, green egg
	[98] = 1, -- Blue Yoshi, blue egg
	[99] = 2, -- Yellow Yoshi, yellow egg
	[100] = 3, -- Red Yoshi, red egg
	[148] = 4, -- Black Yoshi, black egg
	[149] = 5, -- Purple Yoshi, purple egg
	[150] = 6, -- Pink Yoshi, pink egg
	[228] = 7, -- Cyan Yoshi, cyan egg
}

---Given a string, converts it to lowercase with some characters removed (i.e, converts "Super Mushroom" or "Super-Mushroom" to "supermushroom").
---This is mostly just here for use internally (it's automatically called by any method that checks for powerup slot names), but maybe it could be useful to other code?
---@param str string The input string
---@return string -- Returns the input string in all lowercase, and with spaces, hyphens, and underscores removed
function inventory.convertString(str)
	str = string.lower(str) -- Convert to lowercase
	str = str:gsub(" ", ""):gsub("-", ""):gsub("_", "") -- Remove spaces, hyphens, and underscores
	str = str:gsub("tanookie", "tanooki") -- Make sure "tanookie" is counted as "tanooki"

	return str
end

---Given an alias, returns the "official" name of a powerup slot (or nil if nothing was found).
---For example, "Super Mushroom", "Mushroom", and "shroom" would all return "mushroom".
---inventory.getAlias() is case-insensitive and removes spaces, hyphens (-), and underscores (_) from input names, so you can input a lot of things and still get a valid output!
---@param name string The alias you want to search with
---@return string? -- Returns the "official" name of a powerup slot, or nil if none was found
function inventory.getAlias(name)
	name = inventory.convertString(name) -- Converts it to lowercase and removes a few special characters
	
	return aliasMap[name]
end

---Given a name (or alias) of a powerup slot, returns its numerical index.
---This can be used to access inventory data like this:
---local slot = inventory.getSlot("mushroom") -- Could also be "Super Mushroom", "shroom", etc.
---Misc.dialog(SaveData.inventory[slot].quantity) -- Creates a debug popup stating the current quantity of the Super Mushroom slot
---@param name string The name (or alias) of the slot to search for
---@param inv? table The table to search through, defaults to SaveData.inventory and should generally always be SaveData.inventory
---@return number? -- The index of the slot found, or nil if none was found
function inventory.getSlot(name, inv)
	name = inventory.getAlias(name)
	inv = inv or SaveData.inventory
	
	for i,v in ipairs(inv) do
		if v.name == name then
			return i
		end
	end
	
	-- Didn't find a slot with that name, return nil to clarify that
	return nil
end

---Given an official powerup name (or existing alias) and new alias (or list of aliases), adds the new alias(es) to the aliasMap, allowing you to use the new alias in inventory.getAlias()!
---This is mostly useful for custom powerups, which by default do not have any special aliases.
---For example, if you call cp.addPowerup("Bee Mushroom") in your luna.lua file, anything that requires a slot name/alias would only accept "beemushroom", not "beeshroom" or even just "bee".
---However, if you call inventory.addAlias("beemushroom", { "beeshroom", "bee" }), you can then use either of those aliases just fine!
---@param name string An existing name/alias
---@param alias string | table A new alias or list of new aliases
function inventory.addAlias(name, alias)
	name = inventory.convertString(name) -- Convert to lowercase, and make sure to remove any unnecessary stuff
	
	if type(alias) == "table" then -- List of aliases, iterate through them and add each one
		for _,v in ipairs(alias) do
			aliasMap[v] = name
		end
	else
		aliasMap[alias] = name
	end
end

---Function to add (or remove if "num" is negative) an item from the player's inventory
---@param slot string | number The name (or alias) of the item to add, or the slot's numerical index
---@param num? number The amount of the item to add
function inventory.addItem(slot, num)
	if type(slot) == "string" then
		slot = inventory.getSlot(slot)
	end
	num = num or 1
	
	-- Call the custom "onInventoryItemAdded" event
	local eventObj = {cancelled = false}
	EventManager.callEvent("onInventoryItemAdded", eventObj, SaveData.inventory[slot].name, num)
	if eventObj.cancelled then return end
	
	-- Update the slot's quantity
	SaveData.inventory[slot].quantity = SaveData.inventory[slot].quantity + num
	
	-- Clamp the value of the slot now that we've changed it
	SaveData.inventory[slot].quantity = math.clamp(SaveData.inventory[slot].quantity, SaveData.inventory[slot].minStorage, SaveData.inventory[slot].maxStorage)
	
	-- Call the custom "onPostInventoryItemAdded" event
	EventManager.callEvent("onPostInventoryItemAdded", SaveData.inventory[slot].name, num)
end

---Function to set the count of an item in the player's inventory
---@param slot string | number The name (or alias) of the item to add, or the slot's numerical index
---@param num number The amount of the item the player should have after this function runs
function inventory.setItemCount(slot, num)
	if type(slot) == "string" then
		slot = inventory.getSlot(slot)
	end
	
	-- Call inventory.addItem to automatically handle clamping and calling onInventoryItemAdded and everything
	inventory.addItem(slot, num - SaveData.inventory[slot].quantity)
end

---Given at least a name and default powerup (and any optional arguments), generates a new inventory slot that can store any NPC you like
---@param args table A table of named arguments, which can be any of the params below (name and defaultPowerup are required, all others are optional):
---@param name string The name of the slot to create. Will be automatically converted to lowercase and have unusual characters removed
---@param defaultPowerup number The NPC ID of the "default" powerup (the one used as the slot icon and spawned when the player takes an item out of this slot)
---@param givenState? number The player state (such as PLAYER_BIG) associated with this powerup. This should be nil for anything that's not a vanilla powerup
---@param minStorage? number The minimum number of items that can be stored in this slot
---@param maxStorage? number The maximum number of items that can be stored in this slot
---@param quantity? number The number of items the player starts with in this slot the first time it's generated
---@param aliases? string | table Any aliases for this powerup
---@param linkedPowerups? table A list of NPC IDs that are associated with this powerup slot but are not the default powerup
---@param overwriteMRI? boolean If true, ModernReserveItems' default settings for this NPC ID will be replaced, either with the settings given in mriSettings, or with a default table shared by all powerups
---@param mriSettings? table A table of configuration settings for modernReserveItems.lua, only used if overwriteMRI is true
---@return number -- Returns the index of the newly created slot (or of an existing slot if a slot of the given name existed already)
function inventory.newSlot(args)
	local name = inventory.convertString(args.name) -- Convert to lowercase, and make sure to remove any unnecessary stuff
	local defaultPowerup = args.defaultPowerup
	local givenState = args.givenState or nil
	local minStorage = args.minStorage or 0
	local maxStorage = args.maxStorage or 99
	local quantity = args.quantity or 0
	local aliases = args.aliases
	local linkedPowerups = args.linkedPowerups
	local overwriteMRI = args.overwriteMRI
	local mriSettings = args.mriSettings
	local idx = #SaveData.inventory + 1
	
	-- Aliases need to be loaded first, otherwise we can't call getSlot
	-- Set up a default alias because otherwise things will break
	inventory.addAlias(name, name)

	-- Apply any additional aliases if we have any
	if aliases then
		inventory.addAlias(name, aliases)
	end
	
	-- Set up the itemMap with the default powerup
	inventory.itemMap[defaultPowerup] = name
	--Misc.dialog(defaultPowerup..":"..inventory.itemMap[defaultPowerup])
	
	-- Set up the itemMap with any additional linked powerups if we have any
	if linkedPowerups then
		for i,v in ipairs(linkedPowerups) do
			inventory.itemMap[v] = name
		end
	end
	
	-- Overwrite MRI's configs for the default powerup if need be
	if overwriteMRI then
		modernReserveItems.setConfigs(defaultPowerup, mriSettings or {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
	end

	-- If this slot already exists, return the existing slot's index
	if inventory.getSlot(name) then return inventory.getSlot(name) end
	
	-- Otherwise, initialize the slot in the SaveData table and use the new index
	SaveData.inventory[idx] = {
		name = name,
		defaultPowerup = defaultPowerup,
		givenState = givenState,
		minStorage = minStorage,
		maxStorage = maxStorage,
		quantity = quantity
	}
	
	return idx
end

---Given the name (or alias) of a slot, removes it from SaveData.
---Useful if you add a slot then later decide you want to get rid of it, but don't want to clear everything in SaveData.inventory
---@param name string The name of the slot to be removed
function inventory.removeSlot(name)
	local idx = inventory.getSlot(name)
	if idx then
		table.remove(SaveData.inventory, idx)
	end
end

---Completely deletes the entire SaveData.inventory table and then regenerates it.
---Probably not all too useful unless you add a dozen slots and don't want to call inventory.removeSlot() on each one manually
function inventory.regenerateSaveData()
	-- Reset the SaveData table to its default values
	SaveData.inventory = {
		{ name="mushroom", defaultPowerup=9, givenState=PLAYER_BIG, minStorage=0, maxStorage=99, quantity=0 },
		{ name="fire", defaultPowerup=14, givenState=PLAYER_FIREFLOWER, minStorage=0, maxStorage=99, quantity=0 },
		{ name="ice", defaultPowerup=264, givenState=PLAYER_ICE, minStorage=0, maxStorage=99, quantity=0 },
		{ name="leaf", defaultPowerup=34, givenState=PLAYER_LEAF, minStorage=0, maxStorage=99, quantity=0 },
		{ name="tanooki", defaultPowerup=169, givenState=PLAYER_TANOOKI, minStorage=0, maxStorage=99, quantity=0 },
		{ name="hammer", defaultPowerup=170, givenState=PLAYER_HAMMER, minStorage=0, maxStorage=99, quantity=0 }
	}

	-- Load all of the extra slots as needed, and sort them
	initializeInventory()
end

---Entirely clears the player's inventory of all items
function inventory.clear()
	for i,v in ipairs(SaveData.inventory) do
		SaveData.inventory[i].quantity = SaveData.inventory[i].minStorage
	end
end

---Opens the inventory, in case you want to do that in your own code.
---Will do nothing if the inventory is already open, or if the game is paused through some other library
function inventory.open()
	if Misc.isPausedByLua() then return end
	
	-- Call the custom "onInventoryOpen" event
	local eventObj = {cancelled = false}
	EventManager.callEvent("onInventoryOpen", eventObj)
	if eventObj.cancelled then return end
	
	inventoryOpen = true
	
	-- Play a sound and pause the game
	Audio.playSFX(inventory.settings.sounds.openSFX)
	Misc.pause()
	
	-- Get the current volume, store it so we can reset it later, and then set the volume to 1/4th of the original value
	-- Storing the current volume like this ensures that the inventory system works fine with other scripts that adjust the music volume
	oldMusicVolume = Audio.MusicVolume()
	Audio.MusicVolume(oldMusicVolume / 4)
	
	-- Call the custom "onPostInventoryOpen" event
	EventManager.callEvent("onPostInventoryOpen")
end

---Closes the inventory, in case you want to do that in your own code.
---Will do nothing if the inventory isn't already open, or if the game isn't paused
function inventory.close()
	if not Misc.isPausedByLua() then return end
	
	-- Call the custom "onInventoryClose" event
	local eventObj = {cancelled = false}
	EventManager.callEvent("onInventoryClose", eventObj)
	if eventObj.cancelled then return end
	
	inventoryOpen = false
	
	-- Play a sound and unpause the game
	Audio.playSFX(inventory.settings.sounds.closeSFX)
	Misc.unpause()
	
	-- Reset the music volume to its value before we opened the inventory
	-- This ensures compatibility with other scripts that raise/lower the volume
	Audio.MusicVolume(oldMusicVolume)
	
	-- Reset the page to 1
	page = 1
	
	-- Call the custom "onPostInventoryClose" event
	EventManager.callEvent("onPostInventoryClose")
end

-------------------------------------------------------------------
-- Internal functions, you probably shouldn't mess with these... --
--		Unless you really know what you're doing, that is.		 --
-------------------------------------------------------------------

function inventory.onInitAPI()
	registerEvent(inventory, "onStart")
	registerEvent(inventory, "onTick")
	registerEvent(inventory, "onDraw")
	registerEvent(inventory, "onNPCCollect")
	registerEvent(inventory, "onInputUpdate")
	registerEvent(inventory, "onPostReserveUse") -- This event is part of modernReserveItems.lua, not basegame!
	
	--------------------------------------------------------------------------------------------------------
	-- Registering custom events; you can use these like any other event to do things with the inventory! --
	--------------------------------------------------------------------------------------------------------
	
	-- "onInventoryOpen(eventObj)" and "onInventoryClose(eventObj)" - Triggers when the inventory is opened or closed respectively
	-- Both have one extra argument: eventObj, a token which can be used to cancel opening/closing the inventory if you so desire
	registerCustomEvent(inventory, "onInventoryOpen")
	registerCustomEvent(inventory, "onInventoryClose")
	
	-- "onPostInventoryOpen()" and "onPostInventoryClose()" - Triggers when the inventory is opened or closed respectively, but only if the corresponding event is not cancelled
	-- No extra arguments
	registerCustomEvent(inventory, "onPostInventoryOpen")
	registerCustomEvent(inventory, "onPostInventoryClose")
	
	-- "onInventoryItemAdded(eventObj, slot, quantityAdded)" - Triggers when any item is added to the inventory
	-- Has three extra arguments: eventObj, a token which can be used to cancel adding the item, slot, a string specifying what item was added, and quantityAdded, a number specifying how many items were added (adjusted to account for clamping)
	registerCustomEvent(inventory, "onInventoryItemAdded")
	
	-- "onPostInventoryItemAdded(slot, quantityAdded)" - Triggers when any item is added to the inventory, but only if onInventoryItemAdded is not cancelled
	-- Has two extra arguments: slot, a string specifying what item was added, and quantityAdded, a number specifying how many items were added (adjusted to account for clamping)
	registerCustomEvent(inventory, "onPostInventoryItemAdded")
	
	-- "onInventorySlotsGenerate()" - Triggers when the inventory is generating slots, used to ensure that things load in the same order every time
	-- No extra arguments
	registerCustomEvent(inventory, "onInventorySlotsGenerate")
	
	--------------------------------------
	-- Registering all three new cheats --
	--------------------------------------
	
	-- "emptypockets" - Clears the player's inventory completely. Does not disable your ability to save the game, unlike most cheats
	Cheats.register("emptypockets", {
		isCheat = false,
		toggleSFX=34, -- Super Leaf "poof" sound
		onActivate = function() inventory.clear() return true end
	})
	
	-- 
	if not inventory.settings.enableCheats then return end
	
	-- "stockpile" - Adds one of every item to the player's inventory
	Cheats.register("stockpile", {
		isCheat = true,
		toggleSFX=12, -- Sound for putting an item in the reserve box
		onActivate = function()
			if not inventory.settings.enableCheats then return true end
			for i,v in ipairs(SaveData.inventory) do
				v.quantity = v.quantity + 1
			end
			return true
		end
	})
	
	-- "imgreedy"/"fullpockets" - Sets the quantity of every item in the player's inventory to the max value
	Cheats.register("imgreedy", {
		aliases = { "fullpockets" },
		isCheat = true,
		toggleSFX=12, -- Sound for putting an item in the reserve box
		onActivate = function()
			if not inventory.settings.enableCheats then return true end
			for i,v in ipairs(SaveData.inventory) do
				v.quantity = v.maxStorage
			end
			return true
		end
	})
	
	-- "creativemode"/"journeymode" - Gives the player an infinite supply of every powerup for as long as the cheat is active
	Cheats.register("creativemode", {
		aliases = { "journeymode" },
		isCheat = true,
		activateSFX=12, -- Sound for putting an item in the reserve box
		deactivateSFX=34, -- Super Leaf "poof" sound
		onActivate = function()
			if not inventory.settings.enableCheats then return end
			creativeMode = true
			originalInventory = table.ideepclone(SaveData.inventory) -- Store all of the inventory data so it can be restored when disabled
			for _,v in ipairs(SaveData.inventory) do
				v.minStorage = v.maxStorage
			end
		end,
		onDeactivate = function()
			if not inventory.settings.enableCheats then return end
			creativeMode = false
			SaveData.inventory = table.ideepclone(originalInventory)
		end
	})
end

function inventory.onStart()
	-- Set the starting position of the cursor based on the HUD position
	selectX = inventory.settings.hudPosition.x
	selectY = inventory.settings.hudPosition.y
	
	-- Loads all of the slots and sets their order from slotOrder
	initializeInventory()
	
	-- Add MRI configs for the six standard powerups (mushroom, fire, leaf, tanooki, hammer, and ice)
	modernReserveItems.setConfigs(9, {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
	modernReserveItems.setConfigs(14, {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
	modernReserveItems.setConfigs(34, {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
	modernReserveItems.setConfigs(169, {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
	modernReserveItems.setConfigs(170, {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
	modernReserveItems.setConfigs(264, {speedX = 3, speedY = -3, isHeld = false, isThrown = true, forcedState = 0, doesntMove = true, sfx = 11})
end

function inventory.onDraw()
	-- Make the player retain their powerups when they gain a Mega Mushroom
	player.keepPowerOnMega = true
	
	-- Stop the reserve itembox from drawing, but only for characters that use the reserve itembox
	if Graphics.getHUDType(player.character) == Graphics.HUD_ITEMBOX then
		hudoverride.visible.itembox = false
	end
	
	-- Clamp the item storage amount at the max and min values
	for i,v in ipairs(SaveData.inventory) do
		v.quantity = math.clamp(v.quantity, v.minStorage, v.maxStorage)
	end
	
	-- ...Now comes the hard part... Actually drawing the HUD (I did this last despite it being one of the first things in this function)
	-- Because of the way I've set this up, I can't use the same system Coldcolor used, since they just had two images for the whole HUD (one big, one small)
	-- I have to manually assemble the whole thing myself, and I'll be scaling the images with code since I'm gonna be autoloading the graphics for each powerup icon, and as such I can't use smaller sprites created by hand
	local panelX = inventory.settings.hudPosition.x
	local panelY = inventory.settings.hudPosition.y
	local panelTex = inventory.settings.images.panel
	local selectorTex = inventory.settings.images.selector
	local padding = selectorTex.width - panelTex.width -- By default: 64 - 56 = 8
	
	local numPowerups = inventory.settings.powerupsPerPage
	if not activateInventory and inventory.settings.showTwoPagesWhenClosed then numPowerups = numPowerups * 2 end
	
	local startingValue = numPowerups * (page - 1)
	local endingValue = startingValue + numPowerups
	
	-- Load what we can early to try and minimize lag
	local tplusFont = textplus.loadFont("textplus/font/11.ini")
	
	-- ipairs ensures that we always get things in the same order every time, and since SaveData is an ordered list iterating through it is easy!
	for i,v in ipairs(SaveData.inventory) do
		if i > startingValue and i <= endingValue then -- Only draw one page's worth of powerups (10 powerups by default)
			local itemQuantity = v.quantity
			local size = vector(panelTex.width, panelTex.height)
			local offset = 0
			
			if not activateInventory then
				size = size / 2
				
				if inventory.settings.hudPosition.y > 500 then -- If HUD is near the bottom of the screen, shift it down a lot when shrunken
					offset = 24
				elseif inventory.settings.hudPosition.y > 100 then -- If HUD is not near the bottom or top of the screen, shift it down a little when shrunken
					offset = 12
				end
			end
			
			-- Draw the panel first, so it should be behind everything
			Graphics.drawBox{
				texture=panelTex,
				x=panelX,
				y=panelY + offset,
				w=size.x,
				h=size.y
			}
			
			-- Load all of the sprite data for the powerup (texture, width, and height, and number of frames)
			local powerupID = v.defaultPowerup
			local overrideID = modernReserveItems.config[powerupID].idOverwrite
			if overrideID ~= 0 then powerupID = overrideID end -- Replace the texture with an override texture if one is specified, such as using the Yoshi Egg texture for Yoshis
			local powerupTexture = Graphics.sprites.npc[powerupID].img
			local missingTexture = false
			
			-- Default to the texture of the Random Powerups NPC (npc-287) if none could be found
			if powerupTexture == nil then
				powerupTexture = Graphics.sprites.npc[287].img
				missingTexture = true
			end
			
			local powerupW = powerupTexture.width
			local powerupH = powerupTexture.height
			local numFrames = 1
			
			if not missingTexture then
				numFrames = npcutils.frames(powerupID)
				
				-- Account for powerups with a non-default framestyle, like the Cape Feather
				if npcutils.framestyle(powerupID) > 0 then
					numFrames = numFrames * (npcutils.framestyle(powerupID) * 2)
				end
			end
			
			-- Mega Mushroom has six frames because of its spawning animation, so that needs to be accounted for
			if v.name == inventory.getAlias("mega") then
				numFrames = numFrames * 3
			end
			
			-- Center the powerup sprite in the panel
			local offX = (panelTex.width - powerupW) / 2
			local offY = (panelTex.height - powerupH / numFrames) / 2
			
			if not activateInventory then
				offX = offX / 2
				offY = offY / 2
			end
			
			-- Special handling for Yoshi Egg texture; draw the correct variant for the Yoshi stored inside
			local srcY = 0

			if powerupID == 96 and inventory.yoshiID[v.defaultPowerup] then
				srcY = (powerupH / numFrames) * inventory.yoshiID[v.defaultPowerup]
			end
			
			-- Mega Mushroom will also use a different frame, that being the first frame of its spawning animation
			-- This way, it won't be needlessly massive in the inventory
			-- It also needs to be shifted up a fair bit though- about 1/4 of its usual frame size (half that when the inventory is shrunken down due to being closed)
			if v.name == inventory.getAlias("mega") then
				srcY = (powerupH / numFrames) * 3
				offY = offY - (((powerupH / numFrames) / 4) * (size.y / panelTex.height))
			end

			-- Draw the powerup icon, using the provided color tint if needed
			if itemQuantity <= 0 then
				Graphics.drawBox{
					texture=powerupTexture,
					x=panelX + offX,
					y=panelY + offY + offset,
					w=powerupW * (size.x / panelTex.width),
					h=powerupH * (size.y / panelTex.height) / numFrames,
					sourceHeight=powerupH / numFrames,
					sourceY=srcY,
					color=inventory.settings.noItemsTint
				}
			else
				Graphics.drawBox{
					texture=powerupTexture,
					x=panelX + offX,
					y=panelY + offY + offset,
					w=powerupW * (size.x / panelTex.width),
					h=powerupH * (size.y / panelTex.width) / numFrames,
					sourceHeight=powerupH / numFrames,
					sourceY=srcY
				}
			end
			
			-- Each panel is 56x56 px, and they need to have 8 pixels spacing, so we move them by 64 pixels each time (30 px if the inventory is closed)
			if activateInventory then
				panelX = panelX + size.x + padding
			else
				-- Don't draw the text if Metroidvania Mode is enabled (also skips some of the calculations that are no longer needed to save performance)
				if not inventory.settings.metroidvaniaMode then
					-- Draw smaller numbers before incrementing panelX, if that option's enabled
					-- This is done here since the normal text drawing code is within the "if activateInventory" check, meaning it won't run if the inventory is closed
					if inventory.settings.showCountsWhenClosed then
						local digitOff = 0
						
						if itemQuantity >= 100 then -- Three digits take up a lot of extra space, so we need to account for that (this won't ever be a problem unless someone sets the max above 99 but-)
							digitOff = -9
						elseif itemQuantity >= 10 then -- Two digits take up some extra space, so we need to account for that
							digitOff = -4
						end
						
						local textOff = vector(16, 32)
						
						-- Text offset needs to change if the HUD is near the top/bottom of the screen
						if inventory.settings.hudPosition.y < 100 then
							textOff = vector(16, 20)
						elseif inventory.settings.hudPosition.y >= 500 then
							textOff = vector(16, 44)
						end
						
						textplus.print{
							x = panelX + textOff.x + digitOff,
							y = panelY + textOff.y,
							text = ""..itemQuantity,
							font = tplusFont
						}
					end
				end
				
				panelX = panelX + size.x + (padding / 2)
			end
		end
	end
	
	-- Handle things that happen when the inventory is opened
	if activateInventory then
		if Misc.isPausedByLua() then
			-- Draw the selector
			Graphics.drawBox{
				texture=selectorTex,
				x=selectX - (padding / 2),
				y=selectY - (padding / 2),
				w=selectorTex.width,
				h=selectorTex.height
			}
			
			-- Don't draw the text if Metroidvania Mode is enabled (also skips some of the calculations that are no longer needed to save performance)
			if not inventory.settings.metroidvaniaMode then
				-- Draw the numbers beneath each item
				local targetX = inventory.settings.hudPosition.x + 32
				local targetY = inventory.settings.hudPosition.y + 40
				local tplusFont = textplus.loadFont("textplus/font/11.ini")
				
				for i,v in ipairs(SaveData.inventory) do
					if i > startingValue and i <= startingValue + inventory.settings.powerupsPerPage then -- Only draw numbers for one page's worth of powerups (10 powerups by default)
						local itemQuantity = v.quantity
						local offset = 0
						
						if itemQuantity >= 100 then -- Three digits take up a lot of extra space, so we need to account for that (this won't ever be a problem unless someone sets the max above 99 but-)
							offset = -18
						elseif itemQuantity >= 10 then -- Two digits take up some extra space, so we need to account for that
							offset = -12
						end
						
						--Text.print(itemQuantity, targetX + offset, targetY)
						textplus.print{
							x = targetX + offset,
							y = targetY,
							text = "<size 2>"..itemQuantity.."</size>",
							font = tplusFont
						}
						
						targetX = targetX + selectorTex.width
					end
				end
			end
			
			-- Handle player input
			if player.rawKeys.jump == KEYS_PRESSED then -- Jump pressed, player selected an item
				local soundToPlay = inventory.settings.sounds.selectSFX
				
				-- Make sure the player doesn't already have this powerup (if the config option is set to disallow that)
				if inventory.settings.disableRepeatSpawning then
					local idx = inventory.getSlot(selection)
					
					if SaveData.inventory[idx].givenState then
						if player.powerup == SaveData.inventory[idx].givenState then
							soundToPlay = inventory.settings.sounds.errorSFX
						end
					elseif customPowerups then -- We don't have a vanilla powerup, so we need to consult customPowerups' API to see what powerup we've got
						if customPowerups.getCurrentName(player) == selection then
							soundToPlay = inventory.settings.sounds.errorSFX
						end
					end
				end
				
				if not inventory.getSlot(selection) then
					soundToPlay = inventory.settings.sounds.errorSFX
				end

				-- If we didn't get told to play an error sound yet, we should be good to move on to the next step
				if soundToPlay ~= inventory.settings.sounds.errorSFX then
					-- First, we check if the inventory slot we've selected has an item available for use
					-- If not, prepare to play an error sound
					local idx = inventory.getSlot(selection)
					local powerupID = SaveData.inventory[idx].defaultPowerup
					
					if SaveData.inventory[idx].quantity <= 0 then
						soundToPlay = inventory.settings.sounds.errorSFX
					else
						-- Now we know we've got a valid powerup to apply! Let's spawn a new item in front of the player
						-- Doing this requires KBM-Quine's ModernReserveItems.lua, so make sure you have that installed!
						-- Quine's library is nice because it plays a sound for us (which can be disabled if you wish) and has a validity check to make sure we can actually spawn an item
						if modernReserveItems.validityCheck(powerupID, player) then
							modernReserveItems.drop(powerupID, player)
							if not inventory.settings.metroidvaniaMode then
								inventory.addItem(selection, -1) -- Lower the number of this item that we have, but only if Metroidvania Mode is disabled
							end
							
							-- Close the inventory once we've spawned a powerup if the setting is enabled
							if inventory.settings.closeOnSpawn then
								inventory.close()
								
								-- Stop the player from jumping this frame (thankfully we don't need to do any extra work to make sure this doesn't PERMANENTLY disable jumping...)
								player:mem(0x11E, FIELD_BOOL, false)
							end
						else -- Validity check failed, the powerup couldn't spawn
							soundToPlay = inventory.settings.sounds.errorSFX
						end
					end
				end
				
				-- Play either the error sound or select sound, depending on what we were told to play
				Audio.playSFX(soundToPlay)
			end
		end
	end
	
	--drawDebug()
end

function inventory.onTick()
	numFollowers = nil
	
	if customPowerups and player.data.cloudFlower then
		numFollowers = 0
		
		for i,v in ipairs(player.data.cloudFlower.followers) do
			if v.canShow then
				numFollowers = numFollowers + 1
			end
		end
	end
	
	-- Player gained a reserve item this frame, add it to the inventory!
	if player.reservePowerup ~= 0 and inventory.itemMap[player.reservePowerup] then
		local slot = inventory.itemMap[player.reservePowerup]
		
		if inventory.getSlot(slot) and not ignoreThisItem then
			inventory.addItem(slot)
		end
		
		-- Empty the reserve box and reset the "ignoreThisItem" flag
		player.reservePowerup = 0
		ignoreThisItem = false
	end
end

function inventory.onNPCCollect(token, n, p)
	-- Collecting any item in Metroidvania Mode automatically sets its count in the inventory to 1, even if it is consumed to give the player a new powerup state
	-- This allows it to be permanently reusable
	if inventory.itemMap[n.id] and inventory.settings.metroidvaniaMode then
		inventory.setItemCount(inventory.itemMap[n.id], 1)
	end
	
	-- Add Starmans to the reserve when collected, if that setting is enabled
	if inventory.itemMap[n.id] and inventory.itemMap[n.id] == "starman" and inventory.settings.starmanSlot and inventory.settings.collectableStarmans and not n.data.spawnedFromReserve then
		token.cancelled = true -- Prevents any code that uses "onPostNPCCollect" from being run, including starting the Starman effect and obviously the inventory's usual code
		
		-- Add the Starman to the inventory, and play a sound effect
		-- The Starman normally doesn't play a sound effect on collected, which is why this is needed
		inventory.addItem("starman")
		SFX.play(12)
		
		-- Since we cancelled the collection event, we have to manually delete the starman
		n:kill(HARM_TYPE_OFFSCREEN)
	end
	
	-- Ditto the Starman stuff above, but for Mega Mushrooms
	if inventory.itemMap[n.id] and inventory.itemMap[n.id] == "mega" and inventory.settings.megaSlot and inventory.settings.collectableMegas and not n.data.spawnedFromReserve then
		token.cancelled = true -- Prevents any code that uses "onPostNPCCollect" from being run, which I assume stops the Mega Mushroom embiggening code from running?
		
		-- Add the Mega Mushroom to the inventory, and play a sound effect
		-- Like the Starman, the Mega Mushroom typically doesn't play a sound upon being collected
		inventory.addItem("mega")
		SFX.play(12)
		
		-- Since we cancelled the collection event, we have to manually delete the Mega Mushroom
		n:kill(HARM_TYPE_OFFSCREEN)
	end
	
	-- If customPowerups is installed, check if the player collected a Cloud Flower while having less than the max number of platforms left to place
	-- If so, tell the code to not add the item to the inventory
	-- This is the best way I could figure out how to do this, since it can't be done in onTick due to the player's followers data already being updated by then
	if inventory.settings.needsFullClouds and customPowerups and inventory.itemMap[n.id] then
		-- This will detect cloud flowers no matter what they're named, so long as they have "cloud" (case-insensitive) somewhere in the name
		if string.find(string.lower(inventory.itemMap[n.id]), "cloud") then
			if numFollowers and numFollowers < p.data.cloudFlower.limit then
				ignoreThisItem = true
			end
		end
	end
	
	-- If the player has less than max HP (3 hearts) they consume the powerup to gain an extra heart
	-- In this case, the powerup shouldn't be added to the inventory, though there is an option to disable this feature
	if inventory.settings.needsFullHearts and Graphics.getHUDType(p.character) == Graphics.HUD_HEARTS and player:mem(0x16, FIELD_WORD) < 3 then
		-- Will this powerup give us the same state as what we have right now?
		if stateMap[p.powerup] == inventory.itemMap[n.id] then
			-- If so, it will be used to give us an extra hit point and shouldn't be put in the inventory
			-- Since we already added an item, we can just subtract it back out!
			ignoreThisItem = true
		end
	end
	
	-- If customPowerups is NOT installed (because it already handles this) and the player is playing a character without a reserve itembox,
	-- we need to add items to the inventory manually, essentially replicating the reserve box behavior
	if not customPowerups and not ignoreThisItem and Graphics.getHUDType(p.character) == Graphics.HUD_HEARTS and inventory.itemMap[n.id] then
		-- Small characters don't have anything to add to the reserve box, and Starmans and Mega Mushrooms aren't powerups that we should be worrying about
		if p.powerup > PLAYER_SMALL and inventory.itemMap[n.id] ~= "starman" and inventory.itemMap[n.id] ~= "mega" then
			-- Any powerup mapped to the Super Mushroom should go into the inventory as a mushroom when collected, regardless of state
			if inventory.itemMap[n.id] == "mushroom" then
				inventory.addItem("mushroom")
			-- If we collected a non-mushroom powerup while in any non-small powerup state, add the item that got us to our current state to our inventory
			-- Luckily, this runs before our powerup state is changed, so we can check the stateMap!
			elseif stateMap[p.powerup] then
				inventory.addItem(stateMap[p.powerup])
			end
		end
	end
end

-- Specify when a Starman or Mega Mushroom is spawned from the inventory, so we know to actually consume them on collection
function inventory.onPostReserveUse(n, p)
	if inventory.itemMap[n.id] == "starman" or inventory.itemMap[n.id] == "mega" then
		n.data.spawnedFromReserve = true	
	end
end

function inventory.onInputUpdate()
	activateInventory = true
	
	-- Hold the inventory open until the player lets go of the drop item button
	if not inventoryOpen then
		if player.keys.dropItem ~= KEYS_PRESSED then
			activateInventory = false
		end
	end
	
	if player.rawKeys.dropItem == KEYS_PRESSED then -- Pressing the drop item button toggles the inventory open/closed
		if Misc.isPausedByLua() then -- Inventory is currently open, close it
			inventory.close()
		else -- Inventory is closed, open it
			inventory.open()
		end
	end
	
	-- Handle moving the cursor around while the inventory is open
	if activateInventory then
		if Misc.isPausedByLua() then
			-- Left/right movement (selects another powerup from this page)
			if player.rawKeys.right == KEYS_PRESSED then -- Move the cursor right (takes priority if both are pressed at once)
				Audio.playSFX(inventory.settings.sounds.menuSFX)
				selectionID = selectionID + 1
				if SaveData.inventory[selectionID] then selection = SaveData.inventory[selectionID].name end
				selectX = selectX + 64
			elseif player.rawKeys.left == KEYS_PRESSED then -- Move the cursor left
				Audio.playSFX(inventory.settings.sounds.menuSFX)
				selectionID = selectionID - 1
				if SaveData.inventory[selectionID] then selection = SaveData.inventory[selectionID].name end
				selectX = selectX - 64
			end
			
			local numSlots = #SaveData.inventory
			local numPages = math.ceil(numSlots / inventory.settings.powerupsPerPage)
			local startingValue = inventory.settings.powerupsPerPage * (page - 1)
			local endingValue = math.min(startingValue + inventory.settings.powerupsPerPage, numSlots)
			local numSlotsForThisPage = endingValue - startingValue
			
			-- Up/down movement (cycles to the next/previous page, only works if more than 1 page's worth of powerups are loaded)
			if numSlots > inventory.settings.powerupsPerPage then
				if player.rawKeys.up == KEYS_PRESSED then -- Select the previous page
					Audio.playSFX(inventory.settings.sounds.menuSFX)
					page = page - 1
					local distance = inventory.settings.powerupsPerPage
					if page <= 0 then
						page = numPages
						distance = -inventory.settings.powerupsPerPage * (numPages - 1)
					end
					
					-- Update the number of slots this page has
					startingValue = inventory.settings.powerupsPerPage * (page - 1)
					endingValue = math.min(startingValue + inventory.settings.powerupsPerPage, numSlots)
					numSlotsForThisPage = endingValue - startingValue
					
					-- Update the selector's position
					if selectionID - distance > endingValue then -- Selector can't remain at its current position, since it'd go off the grid
						selectX = inventory.settings.hudPosition.x + (64 * (numSlotsForThisPage - 1))
					end
					selectionID = math.min(selectionID - distance, endingValue)
					if SaveData.inventory[selectionID] then selection = SaveData.inventory[selectionID].name end
				elseif player.rawKeys.down == KEYS_PRESSED then -- Select the next page
					Audio.playSFX(inventory.settings.sounds.menuSFX)
					page = page + 1
					local distance = inventory.settings.powerupsPerPage
					if page > numPages then
						page = 1
						distance = -inventory.settings.powerupsPerPage * (numPages - 1)
					end
					
					-- Update the number of slots this page has
					startingValue = inventory.settings.powerupsPerPage * (page - 1)
					endingValue = math.min(startingValue + inventory.settings.powerupsPerPage, numSlots)
					numSlotsForThisPage = endingValue - startingValue
					
					-- Update the selector's position
					if selectionID + distance > endingValue then -- Selector can't remain at its current position, since it'd go off the grid
						selectX = inventory.settings.hudPosition.x + (64 * (numSlotsForThisPage - 1))
					end
					selectionID = math.min(selectionID + distance, endingValue)
					if SaveData.inventory[selectionID] then selection = SaveData.inventory[selectionID].name end
				end
			end
			
			-- Wrap the cursor around if it goes past the edges of this page
			if selectionID <= startingValue then
				selectionID = endingValue
				selection = SaveData.inventory[selectionID].name
				selectX = inventory.settings.hudPosition.x + (64 * (numSlotsForThisPage - 1))
			elseif selectionID > endingValue then -- TODO: This apparently can cause an "attempt to index a nil value" error, I don't know what causes it or how to reproduce it though
				selectionID = startingValue + 1
				selection = SaveData.inventory[selectionID].name
				selectX = inventory.settings.hudPosition.x
			end
			
			--local textW, textH = Text.getSize(selection, 3)
			--Text.print(selection, math.max(selectX + 32 - (textW / 2), 0), selectY - textH)
		end
	end
end

return inventory