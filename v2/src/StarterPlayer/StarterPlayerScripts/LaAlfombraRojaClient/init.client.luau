--[[
	LA ALFOMBRA ROJA v2 - cliente (LocalScript). Coordina los modulos de esta carpeta:
	Effects (luces y pantallas), ControlUi (cabina), ShopUi (carta y mochila), Dance, GuardUi, Npcs, Hud.

	* Todo lo visual es LOCAL y esta limitado por distancia. No se toca UserGameSettings ni
	  RenderSettings, y no se cambia la calidad grafica automaticamente.
	* Chat: solo el TextChatService oficial de Roblox (con su filtro). No se crea ningun chat propio.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local club = Workspace:WaitForChild("LaAlfombraRoja", 60)
if not club then
	return
end
local control = club:WaitForChild("Control", 30)
local remotesFolder = ReplicatedStorage:WaitForChild("AlfombraRemotes", 30)
if not control or not remotesFolder then
	return
end
local remotes = {}
for _, name in { "Shop", "ShopNotice", "Control", "ControlNotice", "Social", "SocialNotice" } do
	remotes[name] = remotesFolder:WaitForChild(name, 30)
	if not remotes[name] then
		return
	end
end

local Ui = require(script.Ui)
local Effects = require(script.Effects)
local ControlUi = require(script.ControlUi)
local ShopUi = require(script.ShopUi)
local Dance = require(script.Dance)
local GuardUi = require(script.GuardUi)
local Npcs = require(script.Npcs)
local Hud = require(script.Hud)
local FollowLights = require(script.FollowLights)
local Mood = require(script.Mood)

local deps = { club = club, control = control, remotes = remotes }
local function boot(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn(string.format("[LaAlfombraRoja] el modulo cliente %s fallo al iniciar (los demas siguen): %s", name, tostring(err)))
	end
	return ok
end
boot("Effects", Effects.init, club, control)
deps.effects = Effects
boot("FollowLights", FollowLights.init, Effects)
boot("Mood", Mood.init, Effects)
boot("ControlUi", ControlUi.init, deps)
boot("ShopUi", ShopUi.init, deps)
boot("Dance", Dance.init, deps)
boot("GuardUi", GuardUi.init, deps)
boot("Npcs", Npcs.init)
boot("Hud", Hud.init, {
	dance = Dance.toggle,
	backpack = function()
		ShopUi.open("mochila")
	end,
})

-- chat oficial: solo se avisa si la cuenta no puede usarlo (no se intenta saltarse nada)
task.spawn(function()
	local okSvc, tcs = pcall(function()
		return game:GetService("TextChatService")
	end)
	if not okSvc then
		return
	end
	local okChat, can = pcall(function()
		return tcs:CanUserChatAsync(Players.LocalPlayer.UserId)
	end)
	if okChat and can == false then
		Ui.toast("El chat no está disponible para tu cuenta (ajustes de Roblox).")
	end
end)

-- Cada modulo se ejecuta AISLADO: si uno lanza un error (se avisa una sola vez por modulo) los demas, incluidos los
-- focos rojos, siguen funcionando.
local failedOnce = {}
local function guarded(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not failedOnce[name] then
		failedOnce[name] = true
		warn(string.format("[LaAlfombraRoja] error en el modulo cliente %s (los demas siguen): %s", name, tostring(err)))
	end
end

local slow = 0
RunService.Heartbeat:Connect(function(dt)
	guarded("Effects", Effects.step, dt)
	guarded("FollowLights", function()
		FollowLights.step(dt, Effects.isNear())
	end)
	guarded("Mood", Mood.step, dt)
	guarded("Npcs", Npcs.step, dt)
	guarded("Dance", Dance.step, dt)
	slow += dt
	if slow >= 0.5 then
		slow = 0
		guarded("Ui", Ui.tick)
		guarded("Hud", Hud.tick)
		guarded("ControlUi", ControlUi.houseKeeping)
	end
end)
