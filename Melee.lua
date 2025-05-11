-------------
------------- Hey! This is my Melee combat system. It was made for a commission.
------------- This system is quite basic, it uses an open-source hitbox system, named "MuchachoHitbox"
------------- Here's the link for it: https://create.roblox.com/store/asset/9645263113/MuchachoHitbox
-------------

--- Setting variables

local TweenService = game:GetService("TweenService")

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local CooldownGui = playerGui:WaitForChild("CooldownGui")
local HitCooldown = CooldownGui:WaitForChild("HitCooldown")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

--- System folder is where I usually store my less important modules, which I use both on client and server, playSound is a good example for this. 

local System = ReplicatedStorage:WaitForChild("System")
local playSound = require(System:WaitForChild("PlaySound"))

--- Here's the open-source MuchachoHitbox

local Combat = script.Parent
local hitboxModule = require(Combat:WaitForChild("MuchachoHitbox"))

local Melee = {}
Melee.__index = Melee

--- this is the constructor of the module. It needs a tool as an argument.

function Melee.new(player, tool)
	local self = setmetatable({}, Melee)
		
	--- base variables, some of them are used to check if the player can use the weapon or not.

	self.player = player
	self.character = player.Character or player.CharacterAdded:Wait()
	self.tool = tool
	self.equipped = false
	self.activated = false
	self.hitSpeed = tool:GetAttribute("hitSpeed")

	self.inputs = {}
	self:connections()
	return self
end

--- This method connects events based on the tool's events, and also connects the tool's events to the module's methods.

function Melee:connections()
	table.insert(
		self.inputs,
		self.tool.Equipped:Connect(function()
			self:equip()
		end)
	)

	table.insert(
		self.inputs,
		self.tool.Unequipped:Connect(function()
			self:unequip()
		end)
	)

	table.insert(
		self.inputs,
		self.tool.Activated:Connect(function()
			self:activate()
		end)
	)

	table.insert(
		self.inputs,
		self.tool.Deactivated:Connect(function()
			self:deactivate()
		end)
	)
end

--- This just plays an UI "animation" for the cooldown, so players know when they are able to use the weapon again.

function Melee:playCooldownTween(amount)
	HitCooldown.Visible = true

	local tweenInfo = TweenInfo.new(
		amount,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(HitCooldown.Fill, tweenInfo, { Size = UDim2.new(0, 0, 1, 0) })
	tween:Play()

	tween.Completed:Connect(function()
		HitCooldown.Visible = false
		HitCooldown.Fill.Size = UDim2.new(1, 0, 1, 0)
	end)
end

function Melee:equip()
	self.equipped = true
	self.character = self.player.Character
	
	--- This part loads the animations into the module, then plays the Equip and Idle animation.
	
	self.animations = {
		equip = self.character:WaitForChild("Humanoid"):LoadAnimation(self.tool.Animations.Equip),
		idle = self.character:WaitForChild("Humanoid"):LoadAnimation(self.tool.Animations.IdleCombat),
		hit1 = self.character:WaitForChild("Humanoid"):LoadAnimation(self.tool.Animations.Hit1),
		hit2 = self.character:WaitForChild("Humanoid"):LoadAnimation(self.tool.Animations.Hit2),
		hit3 = self.character:WaitForChild("Humanoid"):LoadAnimation(self.tool.Animations.Hit3),
	}
	
	self.animations.equip:Play()
	self.animations.idle:Play()
	
	--- This part replaces the RightGrip weld with a motor6, so the tool's handle becomes animatable.

	local a:Weld = self.character:FindFirstChild("Right Arm"):WaitForChild("RightGrip")
	self.m6d = Instance.new("Motor6D")
	self.m6d.Parent = self.character:FindFirstChild("Right Arm")
	self.m6d.Name = "RightGrip"
	self.m6d.Part0 = a.Part0
	self.m6d.Part1 = a.Part1
	self.m6d.C0 = a.C0
	self.m6d.C1 = a.C1
	a:Destroy()
end

function Melee:unequip()
	self.equipped = false
	
	--- This part deletes the motor6 and stops the animations.
	
	if self.m6d then
		self.m6d:Destroy()
	end
	
	--- I use pcall to try to stop the animations.

	local success, result = pcall(function()
		if self.animations["idle"] then
			self.animations["idle"]:Stop()
		end
		
		if self.animations["equip"] then
			self.animations["equip"]:Stop()
		end
	end)
end

--- This part checks multiple things and makes sure if the player can hit with the weapon, or not. 

function Melee:canHit()
	if self.character and self.character.Humanoid and self.character.Humanoid.Health > 0 and self.equipped == true then
		return true
	end

	return false
end

function Melee:hit()
	
	--- This part creates the hitbox, sets the size, offset, etc... and fires a remote to the server whenever it hit something.
	
	task.spawn(function()
		self.hitbox = hitboxModule.CreateHitbox()
		self.hitbox.Visualizer = false
		self.hitbox.Size = Vector3.new(4,4,3)
		self.hitbox.CFrame = self.player.Character.HumanoidRootPart
		self.hitbox.Offset = CFrame.new(0.5,0,-2)
		self.hitbox.OverlapParams = self.params
		self.hitbox.Touched:Connect(function(hit, hum)
			if hum ~= self.character.Humanoid then
				Remotes.HitPlayer:FireServer(hum, self.tool)
			end
		end)
		task.wait(0.2)
		self.hitbox:Start()
		task.wait(0.3)
		self.hitbox:Stop()
	end)
	
	--- This part fires a remote to the server, which gets the tool's slash sound and fires a remote to every client (but not this current one) to plays it. I exclude this player, because I play the sound on the client, so the sound plays INSTANTLY for the localplayer with no delay.

	Remotes.Hit:FireServer(self.tool)
	playSound.playSoundAtLocation(self.character.PrimaryPart, self.tool.Sounds.Slash)

	--- Picks a random number between 1 and 3, and plays the hit animation with that number.

	local hitIndex = math.random(1, 3)
	self.animations["hit".. hitIndex]:Play()
end

function Melee:attack()
	
	--- Checks, so the player cannot hit while the weapon is equipped, and if they are already hitting.
	
	if not self.equipped then
		return
	end

	if self.character:GetAttribute("hitting") == true then
		return
	end
	
	--- While the self.activated is true and the player can hit, it runs the "hit" method and plays the cooldown tween.
	--- It also has a cooldown system, which prevents players from hitting too fast.
	
	task.spawn(function()
		self.character:SetAttribute("hitting", true)
		while self.activated and self:canHit() do
			self:hit()
			self:playCooldownTween((60 / self.hitSpeed) -0.01)
			task.wait(60 / self.hitSpeed)
		end
		self.character:SetAttribute("hitting", false)
	end)
end

function Melee:activate()
	if self.activated then
		return
	end
	
	--- This sets the self.activated to true and calls the attack method, which automatically starts hitting.
	--- This method gets called when the player presses/holds the attack button (LMB).

	self.activated = true

	self:attack()
end

function Melee:deactivate()
	if not self.activated then
		return
	end
	
	--- This sets the self.activated to false, which automatically "cancels" the while loop inside the attack method.
	--- This method gets called when the player stops holding/pressing the attack button (LMB).


	self.activated = false
end

--- Quick function to disconnect the connections of a table and clear it.

local function disconnectAndClear(connections)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

function Melee:destroy()
	--- This gets called when the tool itself gets destroyed. It disconnects the events from the self.inputs table, and clears it.
	
	self:unequip()
	
	disconnectAndClear(self.inputs)
end

return Melee
