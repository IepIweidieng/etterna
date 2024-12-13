local returnFunction, level = ...;
if not returnFunction then
	return Def.Sprite{
		Name = "New Sprite",
	};
end


local baseAttrs, baseDoPreProcess =
	loadfile(ResolveRelativePath("Actor.lua", 1))(true, level+1);

local aStates = {};
local function doPreProcess(actor, actorDef, level)
	baseDoPreProcess(actor, actorDef, level+1);

	for i in function(s, var) return var + 1; end, nil, 0 do
		local sFrameKey = string.format("Frame%04d", i);
		local sDelayKey = string.format("Delay%04d", i);
		if actorDef[sFrameKey] ~= nil and actorDef[sDelayKey] ~= nil then
			local newState = {};

			newState.Frame = actorDef[sFrameKey];
			newState.Delay = actorDef[sDelayKey];

			aStates[#aStates+1] = newState;
		else
			break;
		end
	end
	
	if next(aStates) ~= nil then
		actor:SetStateProperties(aStates)
	end
end

local function loadTexture(actor, texture)
		if type(texture) == "string" then
			local texturePath = ResolveRelativePath(texture, level+1, true);
			if not texturePath then
				texturePath = THEME:GetPathG("", texture);
			end
			if texturePath == "" then
				return false;
			end
			actor:Load(texturePath);
			return true;
		else
			actor:SetTexture(texture);
		end
end

local attrs = {
	Texture = loadTexture,
	Frames = Sprite.SetStateProperties,
} .. baseAttrs;

return attrs, doPreProcess;
