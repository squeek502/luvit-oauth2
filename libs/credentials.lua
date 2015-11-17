local instanceof = require('core').instanceof
local Object = require('core').Object
local json = require('json')

local Credentials = Object:extend()

function Credentials:initialize(access_token, refresh_token)
	self.access_token = access_token
	self.refresh_token = refresh_token
end

function Credentials:isValid()
	return self.access_token and not self:isTokenExpired()
end

function Credentials:isTokenExpired()
	if self.expiry_date and os.time() > self.expiry_date then
		return true
	else
		return false
	end
end

function Credentials:shouldRefresh()
	return not self.access_token or self:isTokenExpired()
end

function Credentials:exist()
	return self.access_token or self.refresh_token
end

function Credentials:buildHeaders()
	return { 
		['Authorization'] = (self.token_type or 'Bearer') .. ' ' .. self.access_token
	}
end

function Credentials:fromJson(data)
	if not instanceof(self, Credentials) then
		data = self
		self = Credentials:new()
	end
	if type(data) == "string" then data = json.parse(data) end
	for key, value in pairs(data) do
		self[key] = value
	end
	return self
end

function Credentials:fromResponse(data)
	if not instanceof(self, Credentials) then
		data = self
		self = Credentials:new()
	end
	if type(data) == "string" then data = json.parse(data) end
	for key, value in pairs(data) do
		self[key] = value
	end
	return self:fromJson(data)
end

return Credentials