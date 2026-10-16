--[[
	RIG - NPC humanoides R6 construidos por codigo (sin assets, sin IDs de ropa ni de animacion).

	Rig.build{ name, displayName, cframe (pies + orientacion), scale, outfit = "guard" | "bartender" | "dancer",
	           skin, hair, hairStyle = "short" | "long" | "bun", dress, parent }  ->  Model
	El HumanoidRootPart va anclado (el NPC no cae ni se mueve); el resto de piezas son sueltas y
	siguen a la raiz mediante Motor6D, de modo que el CLIENTE puede animar las articulaciones
	cambiando Motor6D.C0 (ver DancePoses). Nada se anima desde el servidor.
]]

local Rig = {}

local function c3(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local SKINS = { c3(240, 200, 170), c3(224, 172, 130), c3(190, 138, 98), c3(150, 104, 72) }
Rig.Skins = SKINS

function Rig.build(opts)
	local s = opts.scale or 1
	local cf = opts.cframe or CFrame.new()
	local outfit = opts.outfit or "guard"
	local skin = opts.skin or SKINS[1]
	local hairColor = opts.hair or c3(30, 22, 18)
	local hrpCF = cf * CFrame.new(0, 3 * s, 0)

	local model = Instance.new("Model")
	model.Name = opts.name or "NPC"

	local function part(name, size, offset, color, material, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = false
		p.CanCollide = false
		p.CastShadow = true
		p.Size = Vector3.new(math.max(size.X * s, 0.05), math.max(size.Y * s, 0.05), math.max(size.Z * s, 0.05))
		p.CFrame = hrpCF * CFrame.new(offset.X * s, offset.Y * s, offset.Z * s)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if props then
			for k, v in props do
				if k == "Vertical" then
					-- cilindro con el eje hacia arriba: altura = size.Y (se gira ANTES de soldar)
					p.Size = Vector3.new(math.max(size.Y * s, 0.05), math.max(size.X * s, 0.05), math.max(size.Z * s, 0.05))
					p.CFrame = p.CFrame * CFrame.Angles(0, 0, math.pi / 2)
				else
					p[k] = v
				end
			end
		end
		p.Parent = model
		return p
	end

	local function attach(acc, to)
		local w = Instance.new("WeldConstraint")
		w.Part0 = to
		w.Part1 = acc
		w.Parent = acc
	end

	local function acc(name, size, offset, color, material, props, to)
		local p = part(name, size, offset, color, material, props)
		attach(p, to)
		return p
	end

	local function ball(name, d, offset, color, material, props, to)
		local pr = props or {}
		pr.Shape = Enum.PartType.Ball
		return acc(name, Vector3.new(d, d, d), offset, color, material, pr, to)
	end

	-- colores segun el uniforme
	local top, pants, shoes, sleeve = c3(20, 20, 24), c3(20, 20, 24), c3(10, 10, 12), c3(20, 20, 24)
	if outfit == "bartender" then
		top, pants, sleeve = c3(240, 238, 232), c3(24, 24, 28), c3(240, 238, 232)
	elseif outfit == "dancer" then
		top = opts.dress or c3(18, 18, 22)
		pants = skin
		sleeve = skin
		shoes = c3(14, 14, 16)
	end

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Anchored = true
	hrp.CanCollide = true
	hrp.Transparency = 1
	hrp.Size = Vector3.new(2 * s, 2 * s, 1 * s)
	hrp.CFrame = hrpCF
	hrp.TopSurface = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth
	hrp.Parent = model

	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), top, Enum.Material.SmoothPlastic, { Reflectance = (outfit == "dancer") and 0.12 or 0.05 })
	local head = part("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 1.65, 0), skin, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball })
	local armR = part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), sleeve, Enum.Material.SmoothPlastic, { Reflectance = 0.05 })
	local armL = part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), sleeve, Enum.Material.SmoothPlastic, { Reflectance = 0.05 })
	local legR = part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), pants, Enum.Material.SmoothPlastic)
	local legL = part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), pants, Enum.Material.SmoothPlastic)

	-- articulaciones R6 estandar (C0/C1 de Roblox) con la posicion escalada
	local function motor(name, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
		return m
	end
	local function cfS(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
		return CFrame.new(x * s, y * s, z * s, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	end
	motor("RootJoint", hrp, torso, cfS(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cfS(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, head, cfS(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cfS(0, -0.65, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, armR, cfS(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cfS(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, armL, cfS(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cfS(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, legR, cfS(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cfS(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, legL, cfS(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cfS(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayName = opts.displayName or opts.name or "NPC"
	hum.NameDisplayDistance = 0
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	model.PrimaryPart = hrp

	-- cara: ojos y sonrisa discreta (piezas, sin decals)
	local black = c3(16, 14, 14)
	ball("EyeL", 0.17, Vector3.new(-0.26, 1.72, -0.6), black, nil, nil, head)
	ball("EyeR", 0.17, Vector3.new(0.26, 1.72, -0.6), black, nil, nil, head)
	acc("Smile", Vector3.new(0.42, 0.07, 0.07), Vector3.new(0, 1.42, -0.6), c3(150, 70, 70), nil, nil, head)

	-- pelo
	local style = opts.hairStyle or "short"
	ball("Hair", 1.42, Vector3.new(0, 1.78, 0.12), hairColor, Enum.Material.SmoothPlastic, { Reflectance = 0.06 }, head)
	if style == "long" then
		acc("HairBack", Vector3.new(1.15, 1.9, 0.5), Vector3.new(0, 1.0, 0.55), hairColor, Enum.Material.SmoothPlastic, { Reflectance = 0.06 }, head)
	elseif style == "bun" then
		ball("Bun", 0.6, Vector3.new(0, 2.5, 0.2), hairColor, Enum.Material.SmoothPlastic, { Reflectance = 0.06 }, head)
	end

	-- manos y zapatos
	ball("HandR", 0.7, Vector3.new(1.5, -0.95, 0), skin, nil, nil, armR)
	ball("HandL", 0.7, Vector3.new(-1.5, -0.95, 0), skin, nil, nil, armL)
	acc("ShoeR", Vector3.new(1.05, 0.4, 1.4), Vector3.new(0.5, -2.85, -0.15), shoes, Enum.Material.SmoothPlastic, { Reflectance = 0.2 }, legR)
	acc("ShoeL", Vector3.new(1.05, 0.4, 1.4), Vector3.new(-0.5, -2.85, -0.15), shoes, Enum.Material.SmoothPlastic, { Reflectance = 0.2 }, legL)

	local gold = c3(222, 178, 98)
	if outfit == "guard" then
		-- traje oscuro, camisa blanca, corbata dorada, hombreras anchas y auricular
		acc("Shirt", Vector3.new(0.7, 1.5, 0.06), Vector3.new(0, 0.2, -0.53), c3(240, 238, 232), nil, nil, torso)
		acc("Tie", Vector3.new(0.18, 1.1, 0.07), Vector3.new(0, 0.05, -0.57), gold, Enum.Material.Metal, { Reflectance = 0.3 }, torso)
		ball("ShoulderR", 1.15, Vector3.new(1.2, 0.85, 0), top, nil, { Reflectance = 0.05 }, torso)
		ball("ShoulderL", 1.15, Vector3.new(-1.2, 0.85, 0), top, nil, { Reflectance = 0.05 }, torso)
		acc("Badge", Vector3.new(0.3, 0.3, 0.06), Vector3.new(0.6, 0.55, -0.55), gold, Enum.Material.Metal, { Reflectance = 0.4 }, torso)
		acc("Earpiece", Vector3.new(0.08, 0.22, 0.08), Vector3.new(-0.68, 1.6, -0.1), c3(20, 20, 20), nil, nil, head)
		acc("Sunglasses", Vector3.new(1.0, 0.2, 0.08), Vector3.new(0, 1.74, -0.62), c3(8, 8, 10), Enum.Material.Glass, { Reflectance = 0.3 }, head)
	elseif outfit == "bartender" then
		acc("Vest", Vector3.new(1.7, 1.5, 0.06), Vector3.new(0, 0.1, -0.53), c3(22, 22, 26), nil, { Reflectance = 0.1 }, torso)
		acc("BowTie", Vector3.new(0.5, 0.2, 0.07), Vector3.new(0, 0.85, -0.55), c3(16, 16, 18), nil, nil, torso)
		acc("Apron", Vector3.new(1.7, 1.2, 0.06), Vector3.new(0, -0.55, -0.55), c3(14, 14, 16), nil, nil, torso)
		acc("ApronTrim", Vector3.new(1.7, 0.08, 0.07), Vector3.new(0, 0.05, -0.56), gold, Enum.Material.Metal, { Reflectance = 0.4 }, torso)
	else
		-- vestido de fiesta largo hasta la rodilla: falda acampanada, cinturon dorado y manga corta
		local dressC = top
		acc("SkirtTop", Vector3.new(2.4, 0.55, 2.4), Vector3.new(0, -1.05, 0), dressC, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, Vertical = true, Reflectance = 0.12 }, torso)
		acc("SkirtMid", Vector3.new(2.8, 0.6, 2.8), Vector3.new(0, -1.55, 0), dressC, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, Vertical = true, Reflectance = 0.12 }, torso)
		acc("SkirtLow", Vector3.new(3.2, 0.6, 3.2), Vector3.new(0, -2.1, 0), dressC, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, Vertical = true, Reflectance = 0.12 }, torso)
		acc("Belt", Vector3.new(2.05, 0.18, 1.05), Vector3.new(0, -0.8, 0), gold, Enum.Material.Metal, { Reflectance = 0.45 }, torso)
		acc("SleeveR", Vector3.new(1.05, 0.7, 1.05), Vector3.new(1.5, 0.65, 0), dressC, Enum.Material.SmoothPlastic, { Reflectance = 0.1 }, armR)
		acc("SleeveL", Vector3.new(1.05, 0.7, 1.05), Vector3.new(-1.5, 0.65, 0), dressC, Enum.Material.SmoothPlastic, { Reflectance = 0.1 }, armL)
		acc("Necklace", Vector3.new(0.7, 0.1, 0.07), Vector3.new(0, 0.85, -0.54), gold, Enum.Material.Metal, { Reflectance = 0.5 }, torso)
	end
	model:SetAttribute("AR_Npc", outfit)
	if opts.parent then
		model.Parent = opts.parent
	end
	return model
end

return Rig
