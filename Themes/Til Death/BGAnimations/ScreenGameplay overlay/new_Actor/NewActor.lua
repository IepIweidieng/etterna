--[[  NewActor.lua: A interface for easily dynamically adding Actors to ActorFrames on the fly.

	The file makes use of the AddChildFromPath( string sPath ) function of ActorFrame.

Usage:
	In your lua file, insert the following line:
		local addNewActor = dofile(ResolveRelativePath([path to NewActor.lua], 1));

	In an ActorCommand function of an ActorFrame:
	(assume the first parameter of the ActorCommand is named "self")
		addNewActor(self, ActorDef);
	This will call the new Actor's "Init" and "On" commands.

The default name of the new Actor is:
	"New [actor class] [number of successfully added Actors]"
	This name is used when the provided ActorDef has no Name field.
]]

local supportedList = {
	Actor = true,
	ActorFrame = true,
	BitmapText = true,
	Sprite = true,
	ActorSound = true,
	Sound = {FileName="ActorSound", DisplayName="Sound"},
	Model = true,
	BGAnimation = true,
};


local function getClassName(Class)
	local name = supportedList[Class];
	if name then
		if type(name) == "table" then
			return name.FileName, name.DisplayName;
		else
			return Class, Class;
		end
	elseif ActorUtil.IsRegisteredClass(Class) then
		return "Actor", "[unsupported Actor class] "..Class;
	else
		error(Class .. " is not a registered Actor class", 3);
	end
end


-- REFERENCE: [Actor class].cpp: void [Actor class]::LoadFromNode( const XNode* pNode )
local function setNewActor(actor, actorDef)
	local level = level or 1;
	local className, classDisplayName = getClassName(actorDef.Class);
	
	local attrs, doPreProcess =
	    loadfile(ResolveRelativePath(className..".lua", level))(true, level+1);

	doPreProcess(actor, actorDef, level+1);

	for key, value in pairs(actorDef) do
		if string.sub(key, -7) == "Command" then
			actor:addcommand(string.sub(key, 1, -8), value);
		else
			local attrsV = attrs[key];
			if attrsV then
				if type(attrsV) == "function" then
					attrsV(actor, value);
				else
					_G[actorDef.Class][string.lower(key)](actor, value);
				end
			end
		end
	end
end


local newActorCount = 0;
local function addNewActor(actorframe, actorDef, optional)
	local level = 1;
	local className, classDisplayName = getClassName(actorDef.Class);
	
	if actorDef.Condition == false then
		return nil;
	end

	loadPath = ResolveRelativePath(className..".lua", level);

	if className == "BitmapText" then
		local findFont, err =
		    loadfile(ResolveRelativePath(className..".lua", level))("path", level+1);
		local filePath = findFont(actorDef.Font)
		                 or findFont(actorDef.File);
		if ActorUtil.GetFileType(filePath) == "FileType_Bitmap" then
			loadPath = filePath;
		end
	elseif className == "Model" then
		local filePath = ResolveRelativePath(actorDef.Meshes, level+1, true)
		                 or ResolveRelativePath(actorDef.Materials, level+1, true)
		                 or ResolveRelativePath(actorDef.Bones, level+1, true);
		if ActorUtil.GetFileType(filePath) == "FileType_Model" then
			loadPath = filePath;
		end
	elseif className == "BGAnimation" then
		local filePath = ResolveRelativePath(actorDef.AniDir, level+1, true);
		if ActorUtil.GetFileType(filePath) == "FileType_Directory" then
			loadPath = filePath;
		end
	end


	if actorframe:AddChildFromPath(loadPath) then
		local newChild = actorframe:GetChild("New "..className)
		                 or actorframe:GetChild("");
		if #newChild > 0 then newChild = newChild[#newChild]; end
		newActorCount = newActorCount + 1;
		
		local newChildDefaultName = "New "..classDisplayName.." "..newActorCount;

		newChild:name(newChildDefaultName);
		setNewActor(newChild, actorDef);
		return newChild:playcommand("Init"):playcommand("On");
	else
		if optional == true then
			return nil;
		else
			error("Adding new " .. actorDef.Class .. " failed", 2);
		end
	end
end

return addNewActor;
