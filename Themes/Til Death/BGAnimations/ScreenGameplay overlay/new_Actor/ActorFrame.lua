local returnFunction, level = ...;
if not returnFunction then
	return Def.ActorFrame{
		Name = "New ActorFrame",
	};
end


local baseAttrs, baseDoPreProcess =
	loadfile(ResolveRelativePath("Actor.lua", 1))(true, level+1);

local addNewActor = dofile(ResolveRelativePath("new_Actor/NewActor.lua", 1));
local function doPreProcess(actor, actorDef, level)
	baseDoPreProcess(actor, actorDef, level+1);
	
	local pChildren = actorDef["children"];
	local bArrayOnly = false;
	if pChildren == nil then
		bArrayOnly = true;
		pChildren = actorDef;
	end

	for k, pChild in pairs(pChildren) do
		if not (bArrayOnly and not (type(k) == "number" and k%1 == 0)) then
			addNewActor(actor, pChild);
		end
	end
end

local function toColor(c)
	if type(c) == "string" then
		return color(c);
	end
	return c;
end

local function toVec3(vec3)
	if type(vec3) == table then
		return vec3;
	end

	local ret = {};
	string.gsub(vec3, function(num) ret[#ret+1] = tonumber(num); end);
	return ret;
end


local VanishX = SCREEN_CENTER_X;
local VanishY = SCREEN_CENTER_Y;
local attrs = baseAttrs .. {
	UpdateRate = ActorFrame.SetUpdateRate,
	FOV = 0,
	VanishX = function(actor, x) VanishX = x; actor:vanishpoint(VanishX, VanishY); end,
	VanishY = function(actor, y) VanishY = y; actor:vanishpoint(VanishX, VanishY); end,
	-- ActorFrame.CustomLighting is currently commented out in ActorFrame.cpp; can't use this function.
	Lighting = function(actor) actor:CustomLighting(true); end and nil,
	AmbientColor = function(actor, c) actor:SetAmbientLightColor(toColor(c)); end,
	DiffuseColor = function(actor, c) actor:SetDiffuseLightColor(toColor(c)); end,
	SpecularColor = function(actor, c) actor:SetSpecularLightColor(toColor(c)); end,
	LightDirection = function(actor, vec3) actor:SetLightDirection(toVec3(vec3)); end,
};

return attrs, doPreProcess;
