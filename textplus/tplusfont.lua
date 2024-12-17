local tplusFont = {}
local tplusUtils = require("textplus/tplusutils")
local configFileReader = require("configFileReader")
local math_floor = math.floor
local math_max = math.max

local Font = {}     -- class object
local FontMT = {}   -- instance metatable

local function makeEmptyGlyph(defaultGlyphProps, glyphDefaults)
	local newGlyph = {}
	for _,key in ipairs(defaultGlyphProps) do
		newGlyph[key] = glyphDefaults[key]
	end
	return newGlyph
end

local function fontFromTable(fnt, tbl)
	-- Load image
	local fn = Misc.resolveFile(tbl.main.image)
	fnt.image = Graphics.loadImage(fn)
	fnt.imageWidth = fnt.image.width
	fnt.imageHeight = fnt.image.height
	
	-- Load other sheet information
	fnt.rows = tbl.main.rows
	fnt.cols = tbl.main.cols
	fnt.spacing = tbl.main.spacing or 0
	
	-- Add tables for storing glpyhs, and a list of character code we define
	fnt.glyphs = {}
	fnt.codes = {}
	fnt.simplecodes = {}
	
	-- Load glyphmap if present
	local glyphmap = nil
	if (tbl.glyphmap ~= nil) then
		glyphmap = {}
		local mapCols = 0
		local mapRows = 0
		local i = 1
		while (tbl.glyphmap['row' .. tostring(i)] ~= nil) do
			local s = tbl.glyphmap['row' .. tostring(i)]
			i = i + 1
			
			glyphmap[#glyphmap+1] = tplusUtils.strToCodes(s)
			mapCols = math_max(mapCols, #s)
			mapRows = mapRows + 1
		end
		
		-- If rows/cols are missing and we have a glyph map, do defaulting
		if (fnt.rows == nil) and (fnt.cols == nil) then
			fnt.cols = mapCols
			fnt.rows = mapRows
		end
	end
	
	-- Check rows/columns
	if (fnt.cols == nil) and (fnt.rows == nil) then
		error("Missing row/column count information for font sheet!")
	end
	
	-- Compute cell size
	fnt.cellWidth = math_floor(fnt.image.width / fnt.cols)
	fnt.cellHeight = math_floor(fnt.image.height / fnt.rows)
	
	-- Set up glyph defaults that are not set but we need set
	local glyphDefaults = tbl.glyphdefaults or {}
	if (glyphDefaults.baseline == nil) then
		glyphDefaults.baseline = 0
	end
	if (glyphDefaults.width == nil) then
		glyphDefaults.width = fnt.cellWidth
	end
	if (glyphDefaults.height == nil) then
		glyphDefaults.height = fnt.cellHeight
	end
	
	-- Get Ascent/Descent. Default based on cell size and baseline
	fnt.ascent = tbl.main.ascent or (fnt.cellHeight - glyphDefaults.baseline)
	fnt.descent = tbl.main.descent or (glyphDefaults.baseline)
	
	-- Make note of what properties we have defaults for
	local defaultGlyphProps = {}
	for key,_ in pairs(glyphDefaults) do
		defaultGlyphProps[#defaultGlyphProps+1] = key
	end
	
	-- Instantiate glyphs from glyphmap
	if (glyphmap ~= nil) then
		for row,seq in ipairs(glyphmap) do
			for col,code in ipairs(seq) do
				-- Create new Glyph at this row/column
				local glyph = makeEmptyGlyph(defaultGlyphProps, glyphDefaults)
				glyph.row = row
				glyph.col = col
				
				-- Insert in glyph table
				fnt.glyphs[code] = glyph
				fnt.codes[#fnt.codes + 1] = code
			end
		end
	end
	
	-- Read glyph properties
	for key,val in pairs(tbl) do
		key = tplusUtils.strToCodes(key)
		if (#key == 1) then
			-- Single character section names will be interpreted as glyph data
			local code = key[1]
			
			-- If needed, construct a new glyph
			local glyph = fnt.glyphs[code]
			if (glyph == nil) then
				glyph = makeEmptyGlyph(defaultGlyphProps, glyphDefaults)
				fnt.glyphs[code] = glyph
				fnt.codes[#fnt.codes + 1] = code
			end
			
			-- Copy properties
			for k,v in pairs(val) do
				glyph[k] = v
			end
		end
	end
	
	-- Convert glyph info to texture coordinates
	for _,code in ipairs(fnt.codes) do
		local glyph = fnt.glyphs[code]
		local x1, y1, x2, y2
		
		if not glyph.noColor then
			fnt.simplecodes[#fnt.simplecodes + 1] = code
		end
		
		if (glyph.x1 ~= nil) and (glyph.y1 ~= nil) and (glyph.x2 ~= nil) and (glyph.y2 ~= nil) then
			-- Read x1/y1/x2/y2 from glyph in terms of pixels
			x1, y1, x2, y2 = glyph.x1, glyph.y1, glyph.x2, glyph.y2
		elseif (glyph.col ~= nil) and (glyph.row ~= nil) then
			-- Compute bounding box
			x1 = (glyph.col - 1) * fnt.cellWidth
			y1 = (glyph.row - 1) * fnt.cellHeight
			x2 = x1 + glyph.width
			y2 = y1 + glyph.height
		else
			error("glyph " .. tostring(code) .. " is missing row/column!")
		end
		
		-- Convert to texture coordinates
		x1 = x1 / fnt.imageWidth
		y1 = y1 / fnt.imageHeight
		x2 = x2 / fnt.imageWidth
		y2 = y2 / fnt.imageHeight
		
		-- Store texture coordinates
		glyph.x1 = x1
		glyph.y1 = y1
		glyph.x2 = x2
		glyph.y2 = y2
		
		-- Store texture sample clipping ranges for special cases
		glyph.x1c = x1*fnt.imageWidth  + 0.5
		glyph.y1c = y1*fnt.imageHeight + 0.5
		glyph.x2c = x2*fnt.imageWidth  - 0.5
		glyph.y2c = y2*fnt.imageHeight - 0.5
	end
end

-----------------------------------------------------
-- Font Class                                    
-----------------------------------------------------
do
	FontMT.__type = "TextplusFont"
	FontMT.__index = Font
	
	-----------------------------------------------------
	-- CONSTRUCTOR                                     --
	-----------------------------------------------------
	setmetatable (Font, {__call = function (class, input)

		-- Set up the table & metatable stuff
		local newFont = {}
		
		-- Assign the metatable
		setmetatable(newFont, FontMT)

		-- Create font from input
		fontFromTable(newFont, input)
		
		-- Return
		return newFont

	end
	})
	
	----------------------------------
	-- Factory function for loading --
	----------------------------------
	function Font.load(filename)
		filename = Misc.resolveFile(filename)
		local layers = configFileReader.parseWithHeaders(filename, {})
		local tbl = {}
		for _,l in ipairs(layers) do
			tbl[l.name] = l
			l.name = nil
		end
		
		return Font(tbl)
	end
	
	--------------------------------------
	-- Method for getting width by code --
	--------------------------------------
	function Font:GetWidthByCode(code)
		local glyph = self.glyphs[code]
		if (glyph ~= nil) then
			return glyph.width
		else
			-- If no glyph... fill with cell width?
			return self.cellWidth
		end
	end
end

-- Test Font!
tplusFont.font4 = Font.load("textplus/font/4.ini")

-- TODO: Impelement font file parsing!

tplusFont.Font = Font
return tplusFont
