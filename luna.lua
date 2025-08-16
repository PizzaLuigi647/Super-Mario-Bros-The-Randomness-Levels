function onStart()
	Graphics.setMainFramebufferSize(960,540)
    camera.width,camera.height = Graphics.getMainFramebufferSize()

    -- Resize 600-pixel tall sections to be 540 pixels tall
    for _,section in ipairs(Section.get()) do
        local bounds = section.boundary

        if (bounds.bottom - bounds.top) == 600 then
            bounds.top = bounds.bottom - 540
            section.boundary = bounds
        end
    end
end

function onCameraUpdate()
    camera.width,camera.height = Graphics.getMainFramebufferSize()
end

local nobrokensmbxkicker = require("nobrokensmbxkicker")

local inventory = require("simpleInventory")

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

local littleDialogue = require("littleDialogue")
littleDialogue.registerStyle("smb1",{ })

-- Window name/icon
if not GameData.windowIconSet then
    Misc.setWindowIcon(Graphics.loadImageResolved("launcher/icon.png"))
    GameData.windowIconSet = true
end

Misc.setWindowTitle("SMB: The Randomness Levels!")


GameData.debugMuteMusic = GameData.debugMuteMusic or false
GameData.debugSwapControls = GameData.debugSwapControls or false