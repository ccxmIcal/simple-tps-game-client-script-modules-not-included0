local start: number = tick();
print("[Client]: hello (:");

local players: Players = game:GetService("Players");
local repstorage: ReplicatedStorage = game:GetService("ReplicatedStorage");
local userinput: UserInputService = game:GetService("UserInputService");
local runservice: RunService = game:GetService("RunService");
local startergui: StarterGui = game:GetService("StarterGui");
local tweenserv: TweenService = game:GetService("TweenService");
local marketplace: MarketplaceService = game:GetService("MarketplaceService");

local localplayer: Player = players.LocalPlayer;
local camera: Camera = workspace.CurrentCamera;
local mouse: Mouse = localplayer:GetMouse();

local guns: {} = require(repstorage:WaitForChild("modules").guns);
local chars: {} = require(repstorage:WaitForChild("modules").characters);
local instances: {} = require(repstorage:WaitForChild("modules").instances);
local threads: {} = require(repstorage:WaitForChild("modules").threading);

local gunsmod: {} = require(script:WaitForChild("modules").gunfunctions);
local gunvfx: {} = require(script:WaitForChild("modules").gunvfx);
local guis_handler: {} = require(script:WaitForChild("modules").guishandler);

local replicateanim: RemoteEvent = repstorage:WaitForChild("events"):WaitForChild("replicateanim");
local reload: RemoteFunction = repstorage:WaitForChild("functions").reload;

local mbdown: boolean = false;

local data: { {} } = {
	Weapon = {
		Equipped  = nil;
		LastShot  = 0;
		Reloading = false;
		FirstEq   = true;
		Spread    = 0;
		Ammo      = 0;
	};
	Animations = {
		Crouch    = false;
		Guard     = false;
		Shooting  = false;
		Reloading = false;
		Idle      = false;
	};
	CharData = {
		Crouching = false;
		Guard     = false;
		Sprinting = false;
	};
	JetData = {
		Debounce  = false;
		GoingUp   = false;
		IsKeyDown = false;
		Fuel      = 100;
		LastPress = 0;
	}
};

startergui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false);
startergui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false);

local network: RemoteEvent = nil;

repeat
	network = repstorage:WaitForChild("events").__:FindFirstChildWhichIsA("RemoteEvent");
	task.wait()
until network:IsA("RemoteEvent")

network.OnClientEvent:Connect(function(data: {})
	local action: string = data[1];
	if action == "HitData" then
		local dmg: number = data[2];
		local hitpart: Instance = data[3];
		local hitpos: Vector3 = data[4];
		local target: Player = players:GetPlayerFromCharacter(hitpart.Parent);
		gunvfx:draw_damage(dmg, camera:WorldToViewportPoint(hitpart.Parent["HumanoidRootPart"].Position), target or hitpart.Parent, camera:WorldToScreenPoint(hitpos));
	end
end)

repstorage:WaitForChild("functions").updatecurrency.OnClientInvoke = function(money: number, is_robbery: boolean, set_cash: boolean): () -> nil
	guis_handler:handle_cash(money, is_robbery, set_cash);
	localplayer.PlayerGui.tab.Holder.RadiusCount.Text = money;
end

local oldguns: {} = {};
local gunfuncs: {} = {
	equip = function(name: string): () -> nil
		userinput.MouseIconEnabled = false;
		localplayer.PlayerGui.Crosshair.Frame.Visible = true;
		data.Weapon.Equipped = name;
		data.Weapon.Spread = 0;
		if oldguns[name] then
			data.Weapon.Ammo = oldguns[name].Ammo;
			data.Weapon.LastShot = oldguns[name].LastShot;
		else
			data.Weapon.Ammo = guns[name].Bullets;
			data.Weapon.LastShot = 0;
		end
		replicateanim:FireServer(guns[name].Animations.Idle, true);
		localplayer.PlayerGui.gunstuff.Ammo.allammo.Text = guns[name].Bullets;
		localplayer.PlayerGui.gunstuff.Ammo.ammo.Text = data.Weapon.Ammo
	end,
	
	unequip = function(name: string): () -> nil
		userinput.MouseIconEnabled = true;
		localplayer.PlayerGui.Crosshair.Frame.Visible = false;
		localplayer.Character.Humanoid.WalkSpeed = 16;
		data.CharData.Guard = false;
		data.Weapon.Equipped = nil;
		data.Weapon.Spread = 0;
		oldguns[name] = {Ammo = data.Weapon.Ammo, LastShot = data.Weapon.LastShot};
		localplayer.PlayerGui.gunstuff.Ammo.allammo.Text = 0;
		localplayer.PlayerGui.gunstuff.Ammo.ammo.Text = 0;
	end,
	
	reload = function(gun: {}): () -> nil
		data.Weapon.Reloading = true;
		data.Weapon.Spread = 0;
		replicateanim:FireServer(gun.Animations.Shooting, false);
		replicateanim:FireServer(gun.Animations.Reloading, true);
		reload:InvokeServer(true);
		local start: number = tick();
		local equipped: string = data.Weapon.Equipped;
		while tick() - start <= gun.ReloadTime - 1 do
			if data.Weapon.Equipped then
				if data.Weapon.Equipped ~= equipped then
					data.Weapon.Reloading = false;
					return
				end
				runservice.Stepped:Wait();
			else
				replicateanim:FireServer(gun.Animations.Reloading, false);
				reload:InvokeServer(false);
				data.Weapon.Reloading = false;
			end
		end
		data.Weapon.Ammo = gun.Bullets;
		data.Weapon.Reloading = false;
		localplayer.PlayerGui.gunstuff.Ammo.allammo.Text = gun.Bullets;
		localplayer.PlayerGui.gunstuff.Ammo.ammo.Text = gun.Bullets;
		replicateanim:FireServer(gun.Animations.Reloading, false);
		reload:InvokeServer(false);
	end,
	
	canshoot = function(): () -> boolean
		if not chars:is_alive(localplayer) then
			return false;
		elseif data.Weapon.Reloading then
			return false;
		elseif localplayer.Character.Humanoid.WalkSpeed >= 20 then
			return false;
		elseif data.CharData.Guard then
			return false;
		else
			return true;
		end
	end,
	
	getignore = function(): () -> table
		local ray_ignore: {} = {localplayer.Character, workspace.ignore};
		for i,v in next, players:GetPlayers() do
			if chars:is_alive(v) then
				for _, acc in next, v.Character:GetChildren() do
					if acc:IsA("Accessory") then
						table.insert(ray_ignore, acc);
					end
				end
			end
		end
		return ray_ignore;
	end,
}

localplayer.CharacterAdded:Connect(function(char: Model)
	char.ChildAdded:Connect(function(kid: Instance)
		if kid:IsA("Tool") then
			if guns[kid.Name] then
				gunfuncs.equip(kid.Name);
			end
		end
	end)
	---
	char.ChildRemoved:Connect(function(kid: Instance)
		if kid:IsA("Tool") then
			if guns[kid.Name] then
				gunfuncs.unequip(kid.Name);
			end
		end
	end)
	---
	char:WaitForChild("Humanoid").Died:Connect(function()
		table.clear(oldguns);
		data.Weapon.Equipped = nil;
		data.JetData.Fuel = 100;
	end)
	---
	localplayer.PlayerGui:WaitForChild("currency").Holder["+"].Currency.Text = repstorage.functions.getcash:InvokeServer() or 0;
end)

mouse.Button1Down:Connect(function()
	mbdown = true;
	if data.Weapon.Equipped then
		local gun: {} = guns[data.Weapon.Equipped];
		if gunfuncs.canshoot() then
			local crosshair: Frame = localplayer.PlayerGui.Crosshair.Frame;
			local guninst: Instance = localplayer.Character[data.Weapon.Equipped];
			local mouse: Vector2 = userinput:GetMouseLocation();
			local params: RaycastParams = RaycastParams.new();
			params.FilterDescendantsInstances = gunfuncs.getignore();
			params.IgnoreWater = true;
			params.FilterType = Enum.RaycastFilterType.Exclude;
			
			if data.Weapon.Ammo > 0 then
				if gun.FireMode == "Automatic" then
					while mbdown do
						if tick() >= data.Weapon.LastShot then
							local origin: Vector3 = guninst.Muzzle.Position;
							local dir: Ray = gunsmod:get_dir(crosshair.Position.X.Offset, crosshair.Position.Y.Offset);
							local spread: Vector3, newspread: number = gunsmod:get_spread(dir.Direction, gun.Spread.Spread, data.Weapon.Spread);
							data.Weapon.Spread -= newspread;
							local ray: RaycastResult = workspace:Raycast(dir.Origin, spread * 9e9, params);
							if ray and ray.Instance then
								local spreadfactor: number = math.random(gun.Spread.MinFactor * 100, gun.Spread.MaxFactor * 100) / 100;
								gunsmod:shoot(network, origin, ray.Position - origin, params, gun, localplayer);
								data.Weapon.LastShot = tick() + gun.FireRate;
								data.Weapon.Ammo -= 1;
								localplayer.PlayerGui.gunstuff.Ammo.allammo.Text = guns[data.Weapon.Equipped].Bullets;
								localplayer.PlayerGui.gunstuff.Ammo.ammo.Text = data.Weapon.Ammo
							end
						end
						---
						if data.Weapon.Ammo <= 0 then
							gunfuncs.reload(gun);
							break;
						end
						---
						if not gunfuncs.canshoot() then
							return;
						end
						runservice.RenderStepped:Wait();
					end
				elseif gun.FireMode == "Semi" then
					if tick() >= data.Weapon.LastShot then
						local origin: Vector3 = guninst.Muzzle.Position;
						local dir: Ray = gunsmod:get_dir(crosshair.Position.X.Offset, crosshair.Position.Y.Offset);
						local spread: Vector3, newspread: number = gunsmod:get_spread(dir.Direction, gun.Spread.Spread, data.Weapon.Spread);
						local ray: RaycastResult = workspace:Raycast(dir.Origin, spread * 9e9, params);
						if ray and ray.Instance then
							local spreadfactor: number = math.random(gun.Spread.MinFactor * 100, gun.Spread.MaxFactor * 100) / 100;
							gunsmod:shoot(network, origin, ray.Position - origin, params, gun, localplayer);
							data.Weapon.LastShot = tick() + gun.FireRate;
							data.Weapon.Ammo -= 1;
							localplayer.PlayerGui.gunstuff.Ammo.allammo.Text = guns[data.Weapon.Equipped].Bullets;
							localplayer.PlayerGui.gunstuff.Ammo.ammo.Text = data.Weapon.Ammo
						end
					end
				end
			end
		end
	end
end)

mouse.Button1Up:Connect(function()
	mbdown = false;
	if data.Weapon.Equipped then
		local gun: {} = guns[data.Weapon.Equipped];
		replicateanim:FireServer(gun.Animations.Shooting, false);
		if gun.FireMode == "Automatic" then
			if math.random(1, 100) <= gun.Spread.Accurate then
				data.Weapon.Spread = 0;
			end
		end
	end
end)

userinput.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if not processed then
		if not data.Weapon then return end
		local gun: {} = guns[data.Weapon.Equipped] and guns[data.Weapon.Equipped] or false;
		if gun then
			if input.KeyCode == Enum.KeyCode.F and chars:is_alive(localplayer) and not data.CharData.Crouching then
				data.CharData.Guard = not data.CharData.Guard;
				local state: boolean = data.CharData.Guard;
				if state then
					replicateanim:FireServer(gun.Animations.Guard, true)
				else
					replicateanim:FireServer(gun.Animations.Guard, false);
				end
			elseif input.KeyCode == Enum.KeyCode.C and chars:is_alive(localplayer) then
				data.CharData.Crouching = not data.CharData.Crouching;
				local state: boolean = data.CharData.Crouching;
				if state then
					localplayer.Character.Humanoid.WalkSpeed = 0;
					replicateanim:FireServer(gun.Animations.Crouching, true)
				else
					localplayer.Character.Humanoid.WalkSpeed = 16;
					replicateanim:FireServer(gun.Animations.Crouching, false)
				end
			elseif input.KeyCode == Enum.KeyCode.R then
				local target: Player = repstorage.functions.gamepasses.hitman_target:InvokeServer()
				instances:new_instance("Highlight", {
					DepthMode = "AlwaysOnTop";
					Enabled   = true;
					FillColor = Color3.new(255, 255, 255);
					FillTransparency = 0.8;
					OutlineColor = Color3.new(0,0,0);
					Parent = target.Character;
				})
				gunfuncs.reload(gun);
			elseif input.KeyCode == Enum.KeyCode.LeftShift then
				if not data.CharData.Crouching then
					localplayer.Character.Humanoid.WalkSpeed = 20;
				end
			end
		end
		---
		if marketplace:UserOwnsGamePassAsync(localplayer.UserId, 4415625) then
			if input.KeyCode == Enum.KeyCode.Space then
				local current_time: number = tick();
				if current_time - data.JetData.LastPress < 0.5 and not data.JetData.Debounce then
					data.JetData.Debounce = true;
					data.JetData.GoingUp = true;
					threads:new_thread("jetpack_up", function()
						while true do
							if chars:is_alive(localplayer) then
								if not data.JetData.IsKeyDown and data.JetData.Fuel > 0 then
									localplayer.Character.HumanoidRootPart.Velocity = Vector3.new(localplayer.Character.Humanoid.MoveDirection.X, 50, localplayer.Character.Humanoid.MoveDirection.Z);
									data.JetData.Fuel -= 0.3;
									guis_handler:show_jetpack(true, data.JetData.Fuel);
								end
							end
							task.wait();
						end
					end)
				else
					data.JetData.LastPress = current_time;
				end
			end
		end
	end
end)

userinput.InputEnded:Connect(function(input: InputObject, processed: boolean)
	if not processed then
		if chars:is_alive(localplayer) then
			local gun: {} = guns[data.Weapon.Equipped] and guns[data.Weapon.Equipped] or false;
			if gun then
				if input.KeyCode == Enum.KeyCode.LeftShift then
					localplayer.Character.Humanoid.WalkSpeed = 16;
				end
			end
			---
			if marketplace:UserOwnsGamePassAsync(localplayer.UserId, 4415625) then
				if input.KeyCode == Enum.KeyCode.Space then
					data.JetData.Debounce = false;
					data.JetData.IsKeyDown = false;
					guis_handler:show_jetpack(false, data.JetData.Fuel);
					threads:cancel_thread("jetpack_up");
				end
			end
		end
	end
end)

warn("[Client]: Loaded client in: "..tick() - start.." seconds.");
