--- This is the server side part of the system. This script handles the damage, and the replication.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local System = ReplicatedStorage:WaitForChild("System")

--- effect and playSound are modules made by me, they are used to play effects, animations and sounds.

local playSound = require(System:WaitForChild("PlaySound"))
local effect = require(System.Effect)

Remotes.HitPlayer.OnServerEvent:Connect(function(player, humanoid, tool)
	
	--- This gets played when the player hit a character client-side. There are some checks to know if the player exists, and if the damage is applyable to the humanoid.
	
	if not player:IsA("Player") then
		return
	end
	
	if not humanoid then
		return
	end

	if humanoid.Health <= 0 then
		return
	end
	
	if not player.Character then
		return
	end
	
	local character = player.Character
	
	if not character.Humanoid then
		return
	end
	
	if character.Humanoid.Health <= 0 then
		return
	end
	
	local targetCharacter = humanoid.Parent
	if not targetCharacter then
		return
	end
	
	--- Applies damage based on the tool's damage attribute.

	humanoid:TakeDamage(tool:GetAttribute("damage"))
	
	--- Plays hit sound and hit animation effect.

	playSound.playSoundAtLocation(targetCharacter.PrimaryPart, tool.Sounds.Hit)
	effect.playEffect(targetCharacter, "Hit")
	
end)

Remotes.Hit.OnServerEvent:Connect(function(player, tool)
	--- This just replicates the visuals for when the player hits/slashes with their weapon. 
	--- It basically just plays a sound. This code replicated the sound play for every client but the one that fired the remote. 
	--- This is because the player who fired this remote already played a sound on their client, It works like this so the sound doesn't play delayed for the client when they have higher ping. 
	
	for _, targetPlayer in Players:GetPlayers() do
		if targetPlayer ~= player then
			Remotes.ReplicateVisuals:FireClient(targetPlayer, targetPlayer.Character, tool)
		end
	end
end)
