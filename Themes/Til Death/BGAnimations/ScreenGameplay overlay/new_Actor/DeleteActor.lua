--[[  DeleteActor.lua: A interface for easily dynamically deleting actors on the fly.

	The file makes use of the RemoveChild( string sChild ) function of ActorFrame.

Usage:
	In your lua file, insert the following line:
		local deleteActor = dofile(ResolveRelativePath([path to DeleteActor.lua], 1));

	To delete an Actor object, first say:
	(assume the variable name of the Actor object is named "actor"):
		deleteActor(actor);
	This calles the Actor's "Off" command.

	If the Actor to be deleted has no the "Off" command,
	    a default "Off" command, which automatically calles the "Term" command,
	    will be added to the Actor and called.

	If the "Term" command is not being called, then say:
		actor:queuecommand("Term");
	This will complete the deletion.
]]

local deleteActorCount = 0;
local function deleteActor(actor)	
	-- Do nothing when passing nil
	if actor == nil then return; end

	-- Do not delete twice
	if actor.DeleteActor ~= nil and actor.DeleteActor.isBeingDeleted then return; end

	if type(actor.GetParent) ~= "function" then
		error("Removing actor failed: Not an actor", 2);
	end

	local parent = actor:GetParent();

	if parent == nil then
		error("Removing " .. actor:GetName() .. " failed: No parents", 2);
	end


	-- Set up the clean-up state of this Actor
	deleteActorCount = deleteActorCount + 1;
	actor:name("[Being deleted "..deleteActorCount.."] "..actor:GetName())
	actor.DeleteActor = actor.DeleteActor or {};
	actor.DeleteActor.isBeingDeleted = true;
	actor.DeleteActor.isTermed = false;


	-- Set up the parent Actor
	parent.DeleteActor = parent.DeleteActor or {};
	parent.DeleteActor.actorsToDestroy = parent.DeleteActor.actorsToDestroy or {};

	local actorsToDestroy = parent.DeleteActor.actorsToDestroy;
	actorsToDestroy[#actorsToDestroy + 1] = actor;

	if parent:GetCommand("DestroyActors") == nil then
		parent:addcommand("DestroyActors", function(self)
			for key, value in pairs(actorsToDestroy) do
				if value.DeleteActor.isTermed then
					self:RemoveChild(value:GetName());
					actorsToDestroy[key] = nil;
				end
			end
		end);
	end


	-- Set up the clean-up commands of this Actor
	offCommandFunction = actor:GetCommand("Off")
	if offCommandFunction == nil then
		actor:addcommand("Off", function(self)
			self:visible(false);
			self:queuecommand("Term");
		end);
	end

	termCommandFunction = actor:GetCommand("Term") or function(self) end;
	actor:addcommand("Term", function(self)
		termCommandFunction(self);
		self:visible(false);
		self.DeleteActor.isTermed = true;
		self:GetParent():queuecommand("DestroyActors");
	end);

	actor:queuecommand("Off");
end

return deleteActor;
