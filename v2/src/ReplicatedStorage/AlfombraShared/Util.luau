-- Utilidades compartidas (servidor y cliente): validacion de tipos/rangos, ids de audio y cubos de fichas.
local Util = {}

-- Acepta "rbxassetid://123", "123" o 123. Devuelve "" si no es un id valido (nunca inventa uno).
function Util.normalizeAssetId(id)
	if type(id) == "number" then
		if id ~= id or id <= 0 or id == math.huge then
			return ""
		end
		return "rbxassetid://" .. math.floor(id)
	end
	if type(id) ~= "string" then
		return ""
	end
	local clean = string.gsub(id, "%s+", "")
	if string.match(clean, "^%d+$") and tonumber(clean) ~= 0 then
		return "rbxassetid://" .. clean
	end
	if string.match(clean, "^rbxassetid://%d+$") and not string.match(clean, "^rbxassetid://0+$") then
		return clean
	end
	return ""
end

function Util.isNumber(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- entero en [lo, hi] o nil
function Util.intInRange(v, lo, hi)
	if not Util.isNumber(v) then
		return nil
	end
	local n = math.floor(v + 0.5)
	if n < lo or n > hi then
		return nil
	end
	return n
end

-- texto corto (sin saltos de linea) o nil
function Util.shortString(v, maxLen)
	if type(v) ~= "string" or #v == 0 or #v > maxLen then
		return nil
	end
	if string.find(v, "[%c]") then
		return nil
	end
	return v
end

-- Cubo de fichas: `rate` fichas por segundo y rafaga `burst`. now = os.clock().
function Util.newBucket(rate, burst, now)
	return { rate = rate, burst = burst or rate, tokens = burst or rate, t = now }
end

function Util.take(bucket, now)
	bucket.tokens = math.min(bucket.burst, bucket.tokens + (now - bucket.t) * bucket.rate)
	bucket.t = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function Util.mix(c1, c2, a)
	return Color3.new(c1.R + (c2.R - c1.R) * a, c1.G + (c2.G - c1.G) * a, c1.B + (c2.B - c1.B) * a)
end

function Util.scale(c, k)
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

-- copia superficial/profunda de tablas de datos
function Util.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = Util.deepCopy(v)
	end
	return out
end

return Util
