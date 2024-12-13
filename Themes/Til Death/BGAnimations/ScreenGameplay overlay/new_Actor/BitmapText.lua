local returnFunction, level = ...;
if not returnFunction then
	return Def.BitmapText{
		Name = "New BitmapText",
		Font = "Common Normal",
	};
end


local baseAttrs, baseDoPreProcess =
	loadfile(ResolveRelativePath("Actor.lua", 1))(true, level+1);

local function doPreProcess(actor, actorDef, level)
	baseDoPreProcess(actor, actorDef, level+1);
end

local fontUsed = "";
local findFont = {}
findFont = function (font, lvl)
	local lvl = lvl or level;
	local fontPath = ResolveRelativePath(font, lvl+1, true);
	if not fontPath then
		fontPath = THEME:GetPathF("", font);
	end
	if not fontPath then
		if string.lower(font) ~= "common normal" then
			return findFont("Common Normal", lvl+1);
		end
		return nil;
	end
	return fontPath;
end

if returnFunction == "path" then return findFont; end


local function loadFont(actor, font, lvl)  -- Can't use this function by now.
	local fontPath = findFont(font, lvl+1);
	if fontPath ~= nil then
		actor:LoadFromFont(fontPath);  -- currently a commented-out C function in BitmapText.cpp
		return true;
	end
	return false;
end

local text = "";
local altText = "";
local attrs = {
	Font = function(actor, font)
		if loadFont(actor, font) then fontUsed = font; end
	end and nil,
	File = function(actor, font)
		if fontUsed == "" then loadFont(actor, font); end
	end and nil,

	Text = function(actor, str) text = str; actor:settext(text, altText); end,
	AltText = function(actor, str) altText = str; actor:settext(text, altText); end,
} .. baseAttrs;

return attrs, doPreProcess;
