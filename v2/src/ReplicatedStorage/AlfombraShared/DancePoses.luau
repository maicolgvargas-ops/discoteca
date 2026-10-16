--[[
	DANCEPOSES - bailes PROCEDURALES (sin ids de animacion) para personajes R6 y R15.
	Se aplican en el CLIENTE cambiando Motor6D.C0 (no se replican: cada cliente anima a quien baila).

	DancePoses.new(model)              -> estado (o nil si no hay articulaciones conocidas)
	DancePoses.apply(state, id, t, w)  -> aplica el baile `id` en el instante t con peso w (0..1)
	DancePoses.reset(state)            -> restaura los C0 originales
	DancePoses.IDS                     -> ids de los bailes

	Los giros se expresan en el sistema del padre de la articulacion (X derecha, Y arriba, -Z delante):
	rx > 0 balancea el brazo/pierna hacia delante, rz > 0 separa el brazo derecho hacia fuera
	(el izquierdo usa -rz). Todos son bailes de discoteca normales y suaves.
]]

local DancePoses = {}

DancePoses.IDS = { "suave", "disco", "rebote", "ola", "lateral" }

-- nombres de Motor6D por tipo de rig
local MAP = {
	R6 = {
		root = "RootJoint", neck = "Neck", shR = "Right Shoulder", shL = "Left Shoulder", hipR = "Right Hip", hipL = "Left Hip",
	},
	R15 = {
		root = "Root", waist = "Waist", neck = "Neck", shR = "RightShoulder", shL = "LeftShoulder", elR = "RightElbow", elL = "LeftElbow",
		hipR = "RightHip", hipL = "LeftHip", kneeR = "RightKnee", kneeL = "LeftKnee",
	},
}

function DancePoses.new(model)
	local byName = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			byName[d.Name] = d
		end
	end
	local rigType = (byName["RootJoint"] and byName["Right Shoulder"]) and "R6" or ((byName["Root"] and byName["RightShoulder"]) and "R15" or nil)
	if not rigType then
		return nil
	end
	local state = { model = model, rig = rigType, joints = {} }
	for key, name in MAP[rigType] do
		local m = byName[name]
		if m then
			state.joints[key] = { motor = m, base = m.C0 }
		end
	end
	return state
end

local sin, abs, max = math.sin, math.abs, math.max

-- devuelve { joint = { rx, ry, rz, dx, dy } } para el baile id en el instante t
local function pose(id, t, rig)
	local p = {}
	if id == "guardia" then
		-- de pie, brazos recogidos al frente, respiracion lenta (NPC, no seleccionable por jugadores)
		local b = t * 1.2
		p.root = { dy = 0.012 * sin(b), ry = 0.05 * sin(b * 0.4) }
		p.shR = { rz = 0.12, rx = 0.25 }
		p.shL = { rz = -0.12, rx = 0.25 }
		p.elR = { rx = -0.9 }
		p.elL = { rx = -0.9 }
		p.neck = { ry = 0.35 * sin(b * 0.35) }
	elseif id == "barra" then
		-- bartender: movimiento tranquilo de manos como si preparase una copa
		local b = t * 1.6
		p.root = { ry = 0.1 * sin(b * 0.5), dy = 0.01 * sin(b) }
		p.shR = { rx = 0.5 + 0.25 * sin(b), rz = 0.2 }
		p.shL = { rx = 0.5 + 0.25 * sin(b + 2.2), rz = -0.2 }
		p.elR = { rx = -0.7 + 0.2 * sin(b) }
		p.elL = { rx = -0.7 + 0.2 * sin(b + 2.2) }
		p.neck = { ry = 0.2 * sin(b * 0.4), rx = 0.1 }
	elseif id == "disco" then
		local b = t * 4
		p.root = { dy = 0.07 * abs(sin(b)), ry = 0.12 * sin(b * 0.5) }
		p.shR = { rz = 1.0 + 1.0 * max(0, sin(b)), rx = 0.1 }
		p.shL = { rz = -(1.0 + 1.0 * max(0, sin(b + math.pi))), rx = 0.1 }
		p.hipR = { rx = 0.25 * sin(b) }
		p.hipL = { rx = -0.25 * sin(b) }
		p.elR = { rx = -0.4 }
		p.elL = { rx = -0.4 }
		p.neck = { ry = 0.15 * sin(b * 0.5) }
	elseif id == "rebote" then
		local b = t * 5
		p.root = { dy = 0.18 * abs(sin(b)) }
		p.shR = { rx = 0.7 * sin(b), rz = 0.25 }
		p.shL = { rx = -0.7 * sin(b), rz = -0.25 }
		p.hipR = { rx = 0.2 * abs(sin(b)) }
		p.hipL = { rx = 0.2 * abs(sin(b)) }
		p.kneeR = { rx = -0.5 * abs(sin(b)) }
		p.kneeL = { rx = -0.5 * abs(sin(b)) }
		p.elR = { rx = -0.6 }
		p.elL = { rx = -0.6 }
	elseif id == "ola" then
		local b = t * 3
		p.root = { ry = 0.2 * sin(b * 0.5), dy = 0.03 * sin(b) }
		p.shR = { rz = 1.7 + 0.5 * sin(b), rx = 0.1 }
		p.shL = { rz = -(1.7 + 0.5 * sin(b - 1.2)), rx = 0.1 }
		p.elR = { rx = -0.5 * (1 + sin(b)) * 0.5 }
		p.elL = { rx = -0.5 * (1 + sin(b - 1.2)) * 0.5 }
		p.neck = { rz = 0.1 * sin(b * 0.5) }
	elseif id == "lateral" then
		local b = t * 2.5
		p.root = { dx = 0.4 * sin(b), dy = 0.04 * abs(sin(b * 2)), rz = 0.06 * sin(b) }
		p.hipR = { rz = 0.18 * max(0, sin(b)), rx = 0.05 }
		p.hipL = { rz = -0.18 * max(0, -sin(b)), rx = 0.05 }
		p.shR = { rx = 0.35 * sin(b), rz = 0.35 }
		p.shL = { rx = 0.35 * sin(b + math.pi), rz = -0.35 }
		p.elR = { rx = -0.7 }
		p.elL = { rx = -0.7 }
	else -- "suave"
		local b = t * 2
		p.root = { ry = 0.16 * sin(b), rz = 0.05 * sin(b), dy = 0.025 * abs(sin(b)) }
		p.shR = { rz = 0.45 + 0.18 * sin(b), rx = 0.1 * sin(b) }
		p.shL = { rz = -(0.45 + 0.18 * sin(b + math.pi)), rx = 0.1 * sin(b + math.pi) }
		p.elR = { rx = -0.35 }
		p.elL = { rx = -0.35 }
		p.neck = { ry = -0.1 * sin(b) }
	end
	if rig == "R6" then
		-- sin codos ni rodillas ni cintura: los brazos hacen todo el trabajo
		p.elR, p.elL, p.kneeR, p.kneeL, p.waist = nil, nil, nil, nil, nil
	end
	return p
end

local function composed(base, r, w)
	local pos = base.Position
	local rotOnly = CFrame.new(-pos.X, -pos.Y, -pos.Z) * base
	local c = CFrame.new(pos.X, pos.Y, pos.Z) * CFrame.Angles((r.rx or 0) * w, (r.ry or 0) * w, (r.rz or 0) * w) * rotOnly
	if r.dx or r.dy then
		c = CFrame.new((r.dx or 0) * w, (r.dy or 0) * w, 0) * c
	end
	return c
end

function DancePoses.apply(state, id, t, w)
	if not state then
		return
	end
	local p = pose(id, t, state.rig)
	for key, j in state.joints do
		local r = p[key]
		if r then
			j.motor.C0 = composed(j.base, r, w)
		else
			j.motor.C0 = j.base
		end
	end
end

function DancePoses.reset(state)
	if not state then
		return
	end
	for _, j in state.joints do
		j.motor.C0 = j.base
	end
end

-- id valido de baile (para validar peticiones)
function DancePoses.isValid(id)
	return type(id) == "string" and table.find(DancePoses.IDS, id) ~= nil
end

return DancePoses
