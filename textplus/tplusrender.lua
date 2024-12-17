local tplusRender = {}

-- Imports
local tplusFont = require("textplus/tplusfont")

-- Aliases
local math_sin = math.sin
local math_ceil = math.ceil
local math_max = math.max
local lunatime_drawtime = lunatime.drawtime
local lunatime_drawtick = lunatime.drawtick
local vector_randomInCircle = require("vectr").randomInCircle
local Font_GetWidthByCode = tplusFont.Font.GetWidthByCode
local rng = require("rng")
local rng_random = rng.random
local rng_irandomEntry = rng.irandomEntry

local rng_glitch = rng.new(0)

local crispShader = Shader()
crispShader:compileFromFile("scripts/shaders/crisptext.vert", "scripts/shaders/crisptext.frag")

local settings

local function outArgsByTexture(out, tex, haveVertexColors, crispScaling, smooth)
	local argMap = out.args
	if smooth then
		argMap = out.smoothArgs
	end
	local args = argMap[tex]
	
	if args == nil then
		args = {
			texture = tex,
			vertexCoords = {},
			textureCoords = {},
			-- Maybe only add vertex colors when text is not a single color?
		}
		
		if haveVertexColors then
			args.vertexColors = {}
		end
		
		if crispScaling then
			args.linearFiltered = true
			args.attributes = { crispScale = {}, glyphRange = {} }
			args.uniforms = { inputSize = {tex.width, tex.height} }
		end
		
		if smooth then
			args.linearFiltered = true
		end
		
		argMap[tex] = args
		out.argLists[#out.argLists + 1] = args
	end
	
	return args
end

local function queueSeg(x, y, seg, startIdx, endIdx, out, cursor, limit, crisp)
	local pFilter = seg.fmt.posFilter
	local vFilter = seg.fmt.vertFilter
	
	-- Handle image/icon tags
	if seg.img then
		local args = outArgsByTexture(out, seg.img, false, false, seg.smooth)
		local vCoords = args.vertexCoords
		local tCoords = args.textureCoords
		
		do
			-- Apply position filter		
			local x1 = x
			local y2 = y
			if  type(pFilter) == "function"  then
				x1,y2 = pFilter(x,y, seg.fmt,seg.img, seg.width,seg.height)
			end
			
			-- Write vertex coords
			local x2 = x1 + seg.width
			local y1 = y2 - seg.height		

			local i = #vCoords
			vCoords[i+1], vCoords[i+2] = x1, y2
			vCoords[i+3], vCoords[i+4] = x1, y1
			vCoords[i+5], vCoords[i+6] = x2, y1
			vCoords[i+7], vCoords[i+8] = x2, y1
			vCoords[i+9], vCoords[i+10] = x2, y2
			vCoords[i+11], vCoords[i+12] = x1, y2
			
			-- Apply vertex filter
			if  type(vFilter) == "function"  then
				vCoords = vFilter(vCoords,x,y, seg.fmt,seg.img, seg.width,seg.height)
			end
		end

		do
			-- Write texture coords
			local x1 = 0
			local x2 = 1
			local y1 = 0
			local y2 = 1
			
			-- TODO: Consider supporting image subsets?
			
			local i = #tCoords
			tCoords[i+1], tCoords[i+2] = x1, y2
			tCoords[i+3], tCoords[i+4] = x1, y1
			tCoords[i+5], tCoords[i+6] = x2, y1
			tCoords[i+7], tCoords[i+8] = x2, y1
			tCoords[i+9], tCoords[i+10] = x2, y2
			tCoords[i+11], tCoords[i+12] = x1, y2
		end
		
		return cursor + 1
	end
	
	-- Get font related information
	local font = seg.fmt.font
	local glyphs = font.glyphs
	local spacing = seg.fmt.spacing or font.spacing
	local color = seg.fmt.color or Color.white
	local xscale = seg.fmt.xscale
	local yscale = seg.fmt.yscale
	local wave = (seg.fmt.wave or 0) * settings.effectScale
	local tremble = (seg.fmt.tremble or 0) * settings.effectScale
	local glitch = seg.fmt.glitch
	local glitchdelay = 0
	
	if glitch ~= nil then
		if settings.effectScale <= 0 then
			glitchdelay = math.huge
		else
			glitchdelay = math.floor(glitch.delay/settings.effectScale)
		end
		--glitch = glitch * ((settings.effectScale * 0.9) + 0.1)
	end
	
	
	-- Get glDraw args table
	local args = outArgsByTexture(out, font.image, true, crisp)
	local vCoords = args.vertexCoords
	local tCoords = args.textureCoords
	local attr = args.attributes
	local vCol = args.vertexColors
	
	local basex = x
	
	-- Wavelength for motion effects such as rainbow or waving
	local wavelength = 6*xscale*font.imageWidth/font.rows
	
	
	
	-- Iterate characters
	for idx = startIdx, endIdx do
		local code = seg[idx]
		local glyph = glyphs[code]
		if glyph then
			-- TODO: implement various other modifiers to position/color based on seg.fmt data!
		
			do
				-- Apply position filter
				local x0 = x
				local y0 = y
				
				if  type(pFilter) == "function"  then
					x0,y0 = pFilter(x,y, seg.fmt,glyph, glyph.width*xscale,font.cellHeight*yscale)
				end
			
				-- Write vertex coords
				local x1 = x0
				local x2 = x1 + xscale * glyph.width
				local y2 = y0 + yscale * glyph.baseline
				local y1 = y2 - yscale * font.cellHeight

				if (wave ~= 0) or (tremble ~= 0) then
					local xoffset = 0
					local yoffset = 0
					
					if wave ~= 0 then
						yoffset = yoffset + wave*math_sin(((x + x2)/(2*wavelength) + lunatime_drawtime() * 2)*6.28318530718)
					end
					
					if tremble ~= 0 then
						local v = vector_randomInCircle(tremble)
						xoffset = xoffset + v[1]
						yoffset = yoffset + v[2]
					end
					
					x1 = x1 + xoffset
					x2 = x2 + xoffset
					y1 = y1 + yoffset
					y2 = y2 + yoffset
				end
				
				local i = #vCoords
				vCoords[i+1], vCoords[i+2] = x1, y2
				vCoords[i+3], vCoords[i+4] = x1, y1
				vCoords[i+5], vCoords[i+6] = x2, y1
				vCoords[i+7], vCoords[i+8] = x2, y1
				vCoords[i+9], vCoords[i+10] = x2, y2
				vCoords[i+11], vCoords[i+12] = x1, y2

				-- Apply vertex filter
				if  type(vFilter) == "function"  then
					vCoords = vFilter(vCoords,x,y, seg.fmt,glyph, glyph.width*xscale,font.cellHeight*yscale)
				end

			end

			-- For glitch effect, randomly change glyph only for texturing purposes
			local texGlyph = glyph
			if (glitch) then
				-- seed based on position and time
				rng_glitch.seed = ((idx * 138490097)%784287617 + (cursor * 423883417)%298487429 + math_ceil(lunatime_drawtick()/math_max(glitchdelay,1)) * 9472636727)%378878723
				
				-- step the seed forward a couple of times
				rng_glitch:random()
				rng_glitch:random()
				
				if (rng_glitch:random() < glitch.chance) then
					if glitch.useemoji then
						texGlyph = font.glyphs[rng_glitch:irandomEntry(font.codes)]
					else
						texGlyph = font.glyphs[rng_glitch:irandomEntry(font.simplecodes)]
					end
				end
			end

			do
				-- Write texture coords
				local texGlyph = texGlyph

				local x1 = texGlyph.x1
				local x2 = texGlyph.x2
				local y1 = texGlyph.y1
				local y2 = texGlyph.y2
				
				-- For glitch effect, randomly change glyph only for texturing purposes
				if (glitch) then
					if (texGlyph ~= glyph) then
						-- Horizontal flip
						if (rng_glitch:random() > 0.5) then
							x1, x2 = x2, x1
						end
					end
				end
				
				local i = #tCoords
				tCoords[i+1], tCoords[i+2] = x1, y2
				tCoords[i+3], tCoords[i+4] = x1, y1
				tCoords[i+5], tCoords[i+6] = x2, y1
				tCoords[i+7], tCoords[i+8] = x2, y1
				tCoords[i+9], tCoords[i+10] = x2, y2
				tCoords[i+11], tCoords[i+12] = x1, y2
			end
			
			do
				-- Write attribute values
				if attr then
					local i = #attr.crispScale
					attr.crispScale[i+1], attr.crispScale[i+2] = xscale, yscale
					attr.crispScale[i+3], attr.crispScale[i+4] = xscale, yscale
					attr.crispScale[i+5], attr.crispScale[i+6] = xscale, yscale
					attr.crispScale[i+7], attr.crispScale[i+8] = xscale, yscale
					attr.crispScale[i+9], attr.crispScale[i+10] = xscale, yscale
					attr.crispScale[i+11], attr.crispScale[i+12] = xscale, yscale
					
					local texGlyph = texGlyph
					local x1c = texGlyph.x1c
					local x2c = texGlyph.x2c
					local y1c = texGlyph.y1c
					local y2c = texGlyph.y2c
					i = #attr.glyphRange
					attr.glyphRange[i+1], attr.glyphRange[i+2], attr.glyphRange[i+3], attr.glyphRange[i+4] = x1c, y1c, x2c, y2c
					attr.glyphRange[i+5], attr.glyphRange[i+6], attr.glyphRange[i+7], attr.glyphRange[i+8] = x1c, y1c, x2c, y2c
					attr.glyphRange[i+9], attr.glyphRange[i+10], attr.glyphRange[i+11], attr.glyphRange[i+12] = x1c, y1c, x2c, y2c
					attr.glyphRange[i+13], attr.glyphRange[i+14], attr.glyphRange[i+15], attr.glyphRange[i+16] = x1c, y1c, x2c, y2c
					attr.glyphRange[i+17], attr.glyphRange[i+18], attr.glyphRange[i+19], attr.glyphRange[i+20] = x1c, y1c, x2c, y2c
					attr.glyphRange[i+21], attr.glyphRange[i+22], attr.glyphRange[i+23], attr.glyphRange[i+24] = x1c, y1c, x2c, y2c
				end
			end
			
			do
				-- Write texture coords
				local r, g, b, a
				local r2, g2, b2, a2
				if (texGlyph.noColor) then
					r = 1.0
					g = 1.0
					b = 1.0
					a = 1.0
					r2 = r
					g2 = g
					b2 = b
					a2 = a
				elseif color == "rainbow" then
					local colx = (x-basex)
					colx2 = colx + xscale * glyph.width
					
					local t = lunatime.drawtime()*0.75*settings.effectScale
					
					colx = colx/wavelength + t
					colx2 = colx2/wavelength + t
					
					local col 	= Color.fromHSV(colx %1.0, 0.8, 0.9)
					local col2 	= Color.fromHSV(colx2%1.0, 0.8, 0.9)
					r = col[1]
					g = col[2]
					b = col[3]
					a = col[4]
					r2 = col2[1]
					g2 = col2[2]
					b2 = col2[3]
					a2 = col2[4]
				else
					r = color[1]
					g = color[2]
					b = color[3]
					a = color[4]
					r2 = r
					g2 = g
					b2 = b
					a2 = a
				end
				
				local i = #vCol
				vCol[i+1], vCol[i+2], vCol[i+3], vCol[i+4] = r, g, b, a
				vCol[i+5], vCol[i+6], vCol[i+7], vCol[i+8] = r, g, b, a
				vCol[i+9], vCol[i+10], vCol[i+11], vCol[i+12] = r2, g2, b2, a2
				vCol[i+13], vCol[i+14], vCol[i+15], vCol[i+16] = r2, g2, b2, a2
				vCol[i+17], vCol[i+18], vCol[i+19], vCol[i+20] = r2, g2, b2, a2
				vCol[i+21], vCol[i+22], vCol[i+23], vCol[i+24] = r, g, b, a
			end
			
			-- Increment x by width and spacing
			x = x + xscale * (glyph.width + spacing)
		else
			-- For unknown glyphs, move along by cell width
			x = x + xscale * (font.cellWidth + spacing)
		end
		
		cursor = cursor + 1
		if (limit ~= nil) and (cursor >= limit) then
			break
		end
	end
	return cursor
end

local function queueLine(x, y, line, out, cursor, limit, crisp)
	x = x + line.startX

	local i, elemCount = 1, #line
	while (i <= elemCount) do
		local seg = line[i+0]
		local startIdx = line[i+1]
		local endIdx = line[i+2]
		local segWidth = line[i+3]
		
		cursor = queueSeg(x, y, seg, startIdx, endIdx, out, cursor, limit, crisp)
		if (limit ~= nil) and (cursor >= limit) then
			break
		end
		
		x = x + segWidth
		
		i = i + 4
	end
	return cursor
end

-- Heuristic to decide default usage of crisp scaler
local function crispHeuristic(x, y, layout)
	-- Check based on non-integer render location
	if ((x % 1) ~= 0) or ((y % 1) ~= 0) then
		return true
	end

	for _,line in ipairs(layout) do
		local i, elemCount = 1, #line
		while (i <= elemCount) do
			local seg = line[i+0]
			
			-- Decide based on presence of non-integer text size?
			if ((seg.fmt.xscale % 1) ~= 0) or ((seg.fmt.yscale % 1) ~= 0) then
				return true
			end
			
			-- Also if there is a wave effect, make it smoother
			if (seg.fmt.wave ~= nil) and (seg.fmt.wave ~= 0) then
				return true
			end
			i = i + 4
		end
	end
	return false
end

function tplusRender.renderLayout(x, y, layout, limit, sceneCoords, priority, target, shader, uniforms, color, smooth)
	if (limit ~= nil) and (limit <= 0) then
		return
	end
	
	local out = {args={}, smoothArgs={}, argLists={}}
	local cursor = 0	
	
	local crisp
	if (smooth == nil) then
		-- Decide based on presence of non-integer text size?
		crisp = crispHeuristic(x, y, layout)
	else
		-- Value was specified
		crisp = (smooth ~= false)
	end
	
	
	-- Get global text settings
	settings = tplusRender.getSettings()
	
	-- Process the lines
	for _,line in ipairs(layout) do
		-- Set y to baseline
		y = y + line.ascent
		
		-- Prepare to render line
		cursor = queueLine(x, y, line, out, cursor, limit, crisp)
		cursor = cursor + 1 -- Consider a line break an extra character
		if (limit ~= nil) and (cursor >= limit) then
			break
		end
		
		-- Set y after decent
		y = y + line.descent
	end
	
	-- Consider: Is the above computationally heavy enough to be worth having a
	--           method of caching even if the x/y coordinates we start are
	--           going to change and thus require updating? I suspect not.
	
	-- Consider: Would it be worth using a vertex shader to apply the absolute
	--           position offset? This would allow efficient caching even for
	--           when things don't move. Is it worth the complexity? Unsure.
	
	-- Run each glDraw command
	for _,args in ipairs(out.argLists) do
		if (#args.vertexCoords > 0) then
			-- Set target/shader based on optional parameters
			args.sceneCoords = sceneCoords
			args.target = target
			args.priority = priority
			args.color = color
			if args.shader == nil then
				args.shader = shader
			end
			if args.shader == nil and args.linearFiltered and args.attributes then
				args.shader = crispShader
			else
				args.uniforms = uniforms
			end
			
			Graphics.glDraw(args)
		end
	end
end


return tplusRender
