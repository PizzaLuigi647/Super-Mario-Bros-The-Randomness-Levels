local nobrokensmbxkicker = require("nobrokensmbxkicker")
local furyinventory = require("furyinventory")
local health = require("customHealth")
require('minHUD')
local pauseMenu = require("pauseMenu")
local aw = require("anotherwalljump")
aw.registerAllPlayersDefault()
local charnames = require("charnames")
dive = require("dive")
local warpTransition = require("warpTransition")
local ppp = require('playerphysicspatch')
_G.extrasounds = require("extrasounds")
twirl = require("twirl")
local fakeblocks = require("blocks/ai/fakeblocks")
local areaNames = require("areaNames")

areaNames.sectionNames = {
    [0] = "The Frontyard",
    [1] = "The Main Foyer",
    [2] = "The room of that SMB1 themed level",
    [3] = "The room of a lot of things.",
    [4] = "The Stairs To Doors",
    [5] = "The Room Of Something",
    [6] = "The Grassy Beginnings",
    [7] = "The Room Of A King Or A Queen",
    [8] = "The Good Ol' Backyard!",
    [9] = "The Room Of The Under Grounds 'n' Waters",
    [10] = "The Random Grassy Extras"
}
function areanames.show(name)
    timer = 0
    currentName = The Main Foyer
    currentName = The room of that SMB1 themed level
    currentName = The room of a lot of things
    currentName = The Stairs To Doors
    currentName = The Room Of Something
    currentName = The Grassy Beginnings
    currentName = The Room Of A King Or A Queen
    currentName = The Good Ol' Backyard!
    currentName = The Room Of The Under Grounds 'n' Waters
    currentName = The Random Grassy Extras
end

    
local littleDialogue = require("littleDialogue")
littleDialogue.registerStyle("smb1",{ })

-- Register questions
littleDialogue.registerAnswer("YesNoDaredevil",{text = "Yes Bud...",addText = "Good Luck...<page>Watch Out For Trouble tho.",health.dareActive = true, end})
littleDialogue.registerAnswer("YesNoDaredevil",{text = "No Thanks!",addText = "Alrighty then.",health.dareActive = false, end})
