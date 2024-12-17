--[[

FakeBlocks

Adds the "fake wall" effect from NSMBW to SMBX2
Successor to the old "NSMBWalls" library
- Easier to use
- Has an improved look
- Doesn't rely on deprecated libraries
Created by Sambo, March 2022

-- Standard Settings:
---------------------------

fakeblocks.revealRadius (Default=160): The maximum radius of the X-ray effect

fakeblocks.revealRate (Default=6): The rate, in pixels per tick, at which the radius of the X-ray effect grows when entering an area
    hidden by fake blocks and shrinks when exiting

fakeblocks.revealSoftness (Default=16): The size, in pixels, of the soft edge on the X-ray effect. Set to 0 for a hard edge

fakeblocks.showBlockSilhouettes: (Default=true): If true, semitransparent silhouettes of all blocks inside the X-ray effect will be
    rendered

fakeblocks.silhouetteColor (Default=0x2050a0): The color of the block silhouettes that will be drawn inside the X-ray effect. Accepts
    an RGB color encoded as a 3-byte hexadecimal number or an RGB Color object. The default color is a dark blue

-- NSMBWalls Compatibility Settings (for old levels that use the NSMBWalls library)
-------------------------------------------------------------------------------------------

fakeblocks.useNSMBWallsLayer (Default=false): If true, blocks on the "nsmbwalls" layer will be converted into fake blocks

fakeblocks.additionalNSMBWallsLayers (Default={}): List of additional NSMBWalls layer names. All blocks on these layers will be
    converted into fake blocks. This replaces the nsmbwalls.layers feature. Has no effect if fakeblocks.useNSMBWallsLayer is not set

]]

local blockmanager = require("blockmanager")
local blockutils = require("blocks/blockutils")
local darkness = require("darkness")
local sizable = require("base/game/sizable")

local fakeblocks = {}

local fakeblockIDKeys = {"fakeblockID", "capturerTLID", "capturerBRID", "spawnerID"}

local init
local function initSettings()
    fakeblocks.revealRadius = fakeblocks.revealRadius or 160
    fakeblocks.revealRate = math.max(fakeblocks.revealRate or 6, 1)
    fakeblocks.revealSoftness = fakeblocks.revealSoftness or 16
    if fakeblocks.showBlockSilhouettes == nil then
        fakeblocks.showBlockSilhouettes = true
    end
    if type(fakeblocks.silhouetteColor) ~= "Color" then
        fakeblocks.silhouetteColor = Color.fromHexRGB(fakeblocks.silhouetteColor or 0x2050a0)
    end
    init = true
end

local function setPassthrough(id)
    blockmanager.setBlockSettings{
        id = id,
        passthrough = true,
    }
end

local nullTex = Graphics.loadImage(Misc.resolveFile("blocks/null.png"))

--------------------------
-- Fake Block
--------------------------

function fakeblocks.registerFakeBlock(id)
    if not fakeblocks.fakeblockID then
        fakeblocks.fakeblockID = id
        setPassthrough(id)
        blockmanager.registerEvent(id, fakeblocks, "onStartBlock", "onStartFakeBlock")
        darkness.shadowMaps[id] = nullTex
    else
        Misc.warn("Attempt to register multiple Fake Block IDs")
    end
end

local function initFakeBlock(block, w, h)
    local data = block.data

    if data.init then return end

    data.mimickedID = data.mimickedID or block.data._settings.id
    data.init = true

    local cfg = Block.config[data.mimickedID]
    block.width = w or cfg.width
    block.height = h or cfg.height
end

function fakeblocks.onStartFakeBlock(block)
    initFakeBlock(block)
end

registerEvent(fakeblocks, "onTickEnd")
registerEvent(fakeblocks, "onCameraDraw")

local maskShader, solidShader, xRayCapture, xRays

function fakeblocks.onTickEnd()
    if not init then
        initSettings()
    end

    for _,p in ipairs(Player.get()) do
        xRays = xRays or {}
        xRays[p] = xRays[p] or 0
        local collidingFakeBlock

        if (p.forcedState ~= FORCEDSTATE_PIPE or p.forcedTimer > 0)
        and (p.forcedState ~= FORCEDSTATE_DOOR or p.forcedTimer <= 2) then
            for _,v in ipairs(Colliders.getColliding{a=p, b=fakeblocks.fakeblockID, btype=Colliders.BLOCK}) do
                if not v.isHidden then
                    collidingFakeBlock = true
                    break
                end
            end        
        end

        if collidingFakeBlock then
            xRays[p] = math.min(xRays[p] + fakeblocks.revealRate, fakeblocks.revealRadius)
        else
            xRays[p] = math.max(xRays[p] - fakeblocks.revealRate, 0)
        end
    end
end

local causticsShader
local causticsVertShader = Misc.resolveFile("shaders/effects/screeneffect.vert")
local causticsFragShader = Misc.resolveFile("shaders/effects/caustics.frag")
local screenEffectUniforms = {tex1=Graphics.sprites.hardcoded["53-2"].img, intensity=1, }
local silhouetteTarget = CaptureBuffer(800, 600)
local masktarget = CaptureBuffer(800, 600)
local screeneffectbuffer = CaptureBuffer(800, 600)

function fakeblocks.onCameraDraw(idx)

    local c = Camera(idx)
    local verts = {}
    local uvs = {}

    masktarget:clear(10)
    if fakeblocks.showBlockSilhouettes then
        silhouetteTarget:clear(10)
        local mask = blockutils.getMask(c, false)
        Graphics.drawScreen{texture=mask, target=silhouetteTarget, priority=-10}
    end

    for _,block in Block.iterateIntersecting(c.x, c.y, c.x + c.width, c.y + c.height) do
        if block.id == fakeblocks.fakeblockID and not block.isHidden then

            if not maskShader then
                maskShader = Shader()
                maskShader:compileFromFile(nil, Misc.resolveFile("shaders/effects/mask.frag"))
                xRayCapture = CaptureBuffer(800, 600)
                softCircleShader = Shader()
                softCircleShader:compileFromFile(nil, Misc.resolveFile("shaders/effects/softCircle.frag"))
                solidShader = Shader()
                solidShader:compileFromFile(nil, Misc.resolveFile("shaders/effects/solidColor.frag"))
            end

            local id = block.data.mimickedID

            if Block.config[id].sizable then
                block.id = id
                sizable.drawSizable(block, c, -100, masktarget, nil, maskShader)
                sizable.drawSizable(block, c, -9.9)
                block.id = fakeblocks.fakeblockID
            else
                verts[id] = verts[id] or {}
                local currVerts = verts[id]
                local vertsCt = #verts[id]
                local x1 = block.x - c.x
                local y1 = block.y - c.y
                local x2 = x1 + block.width
                local y2 = y1 + block.height

                currVerts[vertsCt +  1] = x1
                currVerts[vertsCt +  2] = y1
                currVerts[vertsCt +  3] = x1
                currVerts[vertsCt +  4] = y2
                currVerts[vertsCt +  5] = x2
                currVerts[vertsCt +  6] = y1

                currVerts[vertsCt +  7] = x2
                currVerts[vertsCt +  8] = y1
                currVerts[vertsCt +  9] = x2
                currVerts[vertsCt + 10] = y2
                currVerts[vertsCt + 11] = x1
                currVerts[vertsCt + 12] = y2

                uvs[id] = uvs[id] or {}
                local currUVs = uvs[id]
                local frame = blockutils.getBlockFrame(id)
                local frames = Block.config[id].frames
                local y1 = frame / frames
                local y2 = (frame + 1) / frames

                currUVs[vertsCt +  1] = 0
                currUVs[vertsCt +  2] = y1
                currUVs[vertsCt +  3] = 0
                currUVs[vertsCt +  4] = y2
                currUVs[vertsCt +  5] = 1
                currUVs[vertsCt +  6] = y1

                currUVs[vertsCt +  7] = 1
                currUVs[vertsCt +  8] = y1
                currUVs[vertsCt +  9] = 1
                currUVs[vertsCt + 10] = y2
                currUVs[vertsCt + 11] = 0
                currUVs[vertsCt + 12] = y2
            end
        end
    end

    if not maskShader then return end

    local vertsKeys = table.unmap(verts)
    local uvsKeys = table.unmap(uvs)
    for i = 1, #vertsKeys do
        local id = vertsKeys[i]
        Graphics.glDraw{
            primitive = Graphics.GL_TRIANGLES,
            texture = Graphics.sprites.block[id].img,
            shader = maskShader,
            color = 0xff0000ff,
            vertexCoords = verts[id],
            textureCoords = uvs[id],
            target = masktarget,
            priority = -100,
        }
        Graphics.glDraw{
            primitive = Graphics.GL_TRIANGLES,
            texture = Graphics.sprites.block[id].img,
            vertexCoords = verts[id],
            textureCoords = uvs[id],
            priority = -9.9,
        }
    end

    xRayCapture:captureAt(-10)
    if fakeblocks.showBlockSilhouettes then
        Graphics.drawScreen{texture=masktarget, priority=-100, target=silhouetteTarget}
        Graphics.drawScreen{
            texture=silhouetteTarget, shader=solidShader, color=fakeblocks.silhouetteColor..(.35), priority=-9.9, target=xRayCapture
        }
    end

    for _,p in ipairs(Player.get()) do
        local radius = xRays[p]
        if radius > 0 then
            local playerCenter = vector.v2(p.x + p.width * .5 - c.x, p.y + p.height * .5 - c.y)
            Graphics.drawCircle{
                texture = xRayCapture,
                shader = softCircleShader,
                uniforms = {
                    center = playerCenter,
                    totalRadius = radius,
                    softness = math.clamp(fakeblocks.revealSoftness, 0, radius - 1),
                },
                sourceX = playerCenter.x - radius,
                sourceY = playerCenter.y - radius,
                sourceWidth = 2 * radius,
                sourceHeight = 2 * radius,
                x = playerCenter.x,
                y = playerCenter.y,
                radius = radius,
                priority = -9.8,
            }
        end
    end

    local p = Player(idx)
    if p.isValid then
        local seffect = p.sectionObj.settings.effects.screenEffects
        if seffect == SEFFECT_CAUSTICS or seffect == SEFFECT_UNDERWATER then
            if not causticsShader then
                causticsShader = Shader()
                causticsShader:compileFromFile(causticsVertShader, causticsFragShader)
            end

            local u = screenEffectUniforms

            u.time = lunatime.tick()

            -- _, u.mask = blockutils.getMask(c, false)  -- first return value is the mask for real blocks
            u.mask = masktarget

            screeneffectbuffer:captureAt(-9.9)
            Graphics.drawScreen{texture=screeneffectbuffer, shader=causticsShader, uniforms=u, camera=c, priority=-9.9}
            -- Graphics.drawScreen{texture=masktarget, camera=c}
            -- local t = blockutils.getMask(c, false)
            -- Graphics.drawScreen{texture=t, camera=c}
        end
    end
end

----------------------------
-- Fake Block Capturers
----------------------------

function fakeblocks.registerCapturerTL(id)
    if not fakeblocks.capturerTLID then
        fakeblocks.capturerTLID = id
        setPassthrough(id)
        darkness.shadowMaps[id] = nullTex
    else
        Misc.warn("Attempt to register multiple top-left fake block capturer IDs")
    end
end

function fakeblocks.registerCapturerBR(id)
    if not fakeblocks.capturerBRID then
        fakeblocks.capturerBRID = id
        setPassthrough(id)
        darkness.shadowMaps[id] = nullTex
    else
        Misc.warn("Attempt to register multiple bottom-right fake block capturer IDs")
    end
end

registerEvent(fakeblocks, "onStart")

function transformToFakeBlock(b, dx, dy)
    local id = b.id
    local w, h = b.width, b.height
    b:transform(fakeblocks.fakeblockID, false)
    b.data.mimickedID = id
    b:translate(dx, dy)
    initFakeBlock(b, w, h)
end

function fakeblocks.onStart()
    local ids = {fakeblocks.capturerTLID, fakeblocks.capturerBRID, fakeblocks.spawnerID}
    local idToType = {
        [fakeblocks.capturerTLID] = "capturerTL",
        [fakeblocks.capturerBRID] = "capturerBR",
        [fakeblocks.spawnerID] = "spawner"
    }

    -- Collect Capturer/Spawner sets
    local spawnerSets = {}
    for _,v in Block.iterate(ids) do
        local id = v.data._settings.id
        spawnerSets[id] = spawnerSets[id] or {}
        if not spawnerSets[id][idToType[v.id]] then
            spawnerSets[id][idToType[v.id]] = v
        else
            Misc.warn("Too many fake block "..idToType[v.id].." blocks with ID "..id)
        end
    end

    -- Create fake blocks
    for k,v in pairs(spawnerSets) do -- needs to be pairs because there could be gaps
        if v.capturerTL and v.capturerBR and v.spawner then
            local tlx = v.capturerTL.x + v.capturerTL.width
            local tly = v.capturerTL.y + v.capturerTL.height
            local brx = v.capturerBR.x
            local bry = v.capturerBR.y
            local dx = v.spawner.x - v.capturerTL.x
            local dy = v.spawner.y - v.capturerTL.y
            for _,b in Block.iterateIntersecting(tlx, tly, brx, bry) do
                transformToFakeBlock(b, dx, dy)
            end
        else
            Misc.warn("Incomplete Fake Block Spawner / Capturer group with ID "..k)
        end
    end

    -- NSMBWalls compatibility stuff
    if fakeblocks.useNSMBWallsLayer then
        local layerMap = {nsmbwalls=true}
        for _,v in ipairs(fakeblocks.additionalNSMBWallsLayers or {}) do
            layerMap[v] = true
        end
        for _,v in Block.iterate() do
            if v.id ~= fakeblocks.fakeblockID and layerMap[v.layerName] then
                transformToFakeBlock(v, 0, 0)
            end
        end
    end

end

-------------------------------
-- Fake Block Spawners
-------------------------------

function fakeblocks.registerSpawner(id)
    if not fakeblocks.spawnerID then
        fakeblocks.spawnerID = id
        setPassthrough(id)
        darkness.shadowMaps[id] = nullTex
    else
        Misc.warn("Attempt to register multiple fake block spawner IDs")
    end
end

return fakeblocks
