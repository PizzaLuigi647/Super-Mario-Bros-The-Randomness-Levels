-- Imports
local tplusUtils = require("textplus/tplusutils")
local tplusFont = require("textplus/tplusfont")

-- Aliases
local math_max = math.max
local Font_GetWidthByCode = tplusFont.Font.GetWidthByCode


-- Maps of characters to behave differently for
local newlineCode = tplusUtils.strToCodes("\n")[1]
local wordSplitCodeMap = tplusUtils.strToCodeMap(" \t")
local removableCodeMap = tplusUtils.strToCodeMap(" \t\n")

-----------------------------
-- Local Utility Functions --
-----------------------------

local function getSegmentAscentDescent(seg)
	-- Handle image/icon tags
	if seg.img then
		-- TODO: support vertical image alignment maybe?
		return seg.height, 0
	end
	
	local font = seg.fmt.font
	local yscale = seg.fmt.yscale
	
	return yscale*font.ascent, yscale*(font.descent + 1)
end

local function getSegmentWidth(seg, startIdx, maxWidth, splitAtWords)
	-- Handle image/icon tags
	if seg.img then
		if (maxWidth ~= nil) and (seg.width > maxWidth) then
			return 0, 1
		end
		return seg.width, nil
	end
	
	-- Compute width for this segment
	local font = seg.fmt.font
	local spacing = seg.fmt.spacing or font.spacing
	local xscale = seg.fmt.xscale
	
	local width = 0
	local splitwidth = nil
	local splitPoint = 1
	
	-- Iterate characters
	for idx = startIdx,#seg do
		local code = seg[idx]
		local glypyWidth = Font_GetWidthByCode(font, code)
		
		if (code == newlineCode) then
			return width, idx
		end
		
		-- Make note of where we might split
		if (splitAtWords == false) or (wordSplitCodeMap[code]) then
			splitWidth = width
			splitPoint = idx
		end
		
		width = width + xscale * (glypyWidth + spacing)
		
		-- If width is exceeded, return with note of split point
		if (maxWidth ~= nil) and (width > maxWidth) then
			return splitWidth, splitPoint
		end
	end
	splitPoint = nil
	
	return width, splitPoint
end

local function addSegToLine(line, seg, startCharIdx, endCharIdx, segWidth)
	-- Add to line, 4 elements per seg
	local i = #line
	line[i+1] = seg
	line[i+2] = startCharIdx
	line[i+3] = endCharIdx
	line[i+4] = segWidth
	
	-- Update line metadata
	local ascent, descent = getSegmentAscentDescent(seg)
	line.width = line.width + segWidth
	line.ascent = math_max(line.ascent, ascent)
	line.descent = math_max(line.descent, descent)
end

local function addLineToLayout(layout, line)
	layout[#layout+1] = line
end

local function parseSize(val, maxWidth, fmt)
	if val == nil then
		return nil
	elseif type(val) == 'number' then
		return val
	elseif (type(val) == 'string') and (string.sub(val, -1) == "%") then
		return (maxWidth or 800) * tonumber(string.sub(val, 1, -2)) / 100.0
	elseif (type(val) == 'string') and (string.sub(val, -2) == "em") then
		local font = fmt.font
		return tonumber(string.sub(val, 1, -3)) * fmt.yscale * (font.ascent + font.descent + 1)
	elseif (type(val) == 'string') and (string.sub(val, -2) == "px") then
		return tonumber(string.sub(val, 1, -3))
	else
		return tonumber(val)
	end
end

-----------------------------
-- Layout running function --
-----------------------------

local function runLayout(formattedText, maxWidth)
	local layout = {}
	
	-- Iteration
	local segCount = #formattedText
	local idx = 1
	local startCharIdx = 1
	
	-- State
	local line = {width=0, ascent=0, descent=0}
	
	while idx <= segCount do
		local seg = formattedText[idx]
		local segWidth, splitPoint
		
		-- If the segment is an image, process width
		if seg.img then
			local w = parseSize(seg.argWidth, maxWidth, seg.fmt)
			local h = parseSize(seg.argHeight, maxWidth, seg.fmt)
			
			if w and h then
				-- Both specified, we're good
			elseif w then
				-- Only width specified, infer h
				h = (w / seg.img.width) * seg.img.height
			elseif h then
				-- Only height specified, infer w
				w = (h / seg.img.height) * seg.img.height
			else
				-- None specified, take from image
				w = seg.img.width
				h = seg.img.height
			end
			
			-- Handle maximum dimensions
			local maxW = parseSize(seg.maxWidth, maxWidth, seg.fmt)
			local maxH = parseSize(seg.maxHeight, maxWidth, seg.fmt)
			if maxW and (maxW < w) then
				h = h * maxW / w
				w = maxW
			end
			if maxH and (maxH < h) then
				w = w * maxH / h
				h = maxH
			end
			
			seg.width = w
			seg.height = h
		end
		
		-- TODO: Do something here to not include spacing at end of line. A few
		--       ways to perhaps go about it
		
		-- Get remaining width
		local remainingWidth
		if (maxWidth ~= nil) then
			-- If width is limited
			remainingWidth = maxWidth - line.width
		else
			-- If width is not limited
			remainingWidth = nil
		end
		
		-- Get width and split point
		segWidth, splitPoint = getSegmentWidth(seg, startCharIdx, remainingWidth, true)
		
		-- If the line was empty and we couldn't fit any, try again without caring about the splitting upon words
		if (splitPoint == 1) and (#line == 0) then
			segWidth, splitPoint = getSegmentWidth(seg, startCharIdx, remainingWidth, false)
		end	
		
		-- If the line was empty and we still couldn't fit any, force the line to fit
		if (splitPoint == 1) and (#line == 0) then
			segWidth, splitPoint = getSegmentWidth(seg, startCharIdx, nil, false)		
		end
		
		local doneLine = false
		if splitPoint == nil then
			-- Add segment
			addSegToLine(line, seg, startCharIdx, #seg, segWidth)
			
			-- If line met of equaled the split length, we're done with the line
			if (maxWidth ~= nil) and (line.width >= maxWidth) then
				doneLine = true
			end
			
			-- Iterate segment
			idx = idx + 1
			startCharIdx = 1
		else
			-- The segment did not (fully) fit
			if (splitPoint > 1) or (#line == 0) then
				-- But part of it fit, so put that on the line
				-- (or the line was empty and well... let's add an empty segment subset to give the line appropriate height and such)
				addSegToLine(line, seg, startCharIdx, splitPoint-1, segWidth)
			end
			
			-- Start character should be index of the split point unless the
			-- character at the split point is 'removable', in which case skip
			-- that.
			if removableCodeMap[seg[splitPoint]] then
				startCharIdx = splitPoint + 1
			else
				startCharIdx = splitPoint
			end
			doneLine = true
		end
		
		-- Check if we're done reading input
		local doneInput = (idx > segCount)
		
		-- If we've concluded a line, store it and start a new line
		if doneLine or doneInput then
			addLineToLayout(layout, line)
		end
		
		-- If we're not done reading yet, start a new line
		if doneLine and not doneInput then
			line = {width=0, ascent=0, descent=0}
		end
	end
	
	-- Compute total dimensions of the layout
	local layoutWidth = 0
	local layoutHeight = 0
	for _,line in ipairs(layout) do
		layoutHeight = layoutHeight + (line.ascent + line.descent)
		layoutWidth = math_max(layoutWidth, line.width)
	end
	layout.width = layoutWidth
	layout.height = layoutHeight
	
	-- Compute alignment
	for _,line in ipairs(layout) do
		-- Default to 0
		line.startX = 0.0
		
		-- Find the first formatting in a line that specified alignment
		for segIdx = 1,#line,4 do
			local seg = line[segIdx]
			local fmt = seg.fmt
			if (fmt ~= nil) then
				local align = fmt.align 
				
				if align ~= nil then
					if align == "left" then
						line.startX = 0.0
					elseif align == "center" then
						line.startX = 0.5 * (layout.width - line.width)
					elseif align == "right" then
						line.startX = layout.width - line.width
					end
					break
				end
			end
		end
	end
	
	return layout
end

----------------------
-- Class Definition --
----------------------

local Layout = {}
local LayoutMT = {__index=Layout, __type="TexplusLayout"}

-- Constructor
setmetatable(Layout, {__call=function(Layout, formattedText, maxWidth)
	local obj = runLayout(formattedText, maxWidth)
	setmetatable(obj, LayoutMT)
	
	return obj
end})

-- Function to return iterator usable for typewriter purporses and such
function Layout:iter()
	local lineIdx = 1
	local segIdx = 1
	local charIdx = nil
	local layout = self
	local curfmt = nil
	local i = 0

	local function it(_, _)
		local line = layout[lineIdx]
		if (line == nil) then
			return nil
		end
		
		-- Newline
		local seg = line[segIdx+0]
		if (seg == nil) then
			lineIdx = lineIdx + 1
			segIdx = 1
			charIdx = nil
			i = i + 1
			return i, 0x0A, curfmt
		end
		curfmt = seg.fmt or curfmt
		
		if (charIdx == nil) then
			-- Image tag
			if (charIdx == nil) and (seg.img ~= nil) then
				segIdx = segIdx + 4
				charIdx = nil
				i = i + 1
				return i, seg, seg.fmt
			end
			
			-- Unknown tag
			if (charIdx == nil) and (seg[1] == nil) then
				segIdx = segIdx + 4
				charIdx = nil
				return i, seg, seg.fmt
			end
			
			-- Populate starting index
			charIdx = line[segIdx+1]
		end
		
		-- The value to return will be the code
		local code = seg[charIdx]
		charIdx = charIdx + 1
		
		-- End of segment, continue after
		local endIdx = line[segIdx+2]
		if (charIdx > endIdx) then
			segIdx = segIdx + 4
			charIdx = nil
		end
		
		i = i + 1
		return i, code, seg.fmt
	end
	return it, self, 0
end

-------------
-- Exports --
-------------

return {Layout=Layout}
