local Emitter = require('core').Emitter
local instanceof = require('core').instanceof
local qs = require('querystring')
local request = require('./request')
local Credentials = require('./credentials')

local OAuth2Client = Emitter:extend()

function OAuth2Client:initialize(clientID, clientSecret, authorizeUrl, accessTokenUrl, opts)
	if not opts then opts = {} end

	self.clientID = clientID
	self.clientSecret = clientSecret
	self.authorizeUrl = authorizeUrl
	self.accessTokenUrl = accessTokenUrl
	self.redirectURI = opts.redirectURI
	self.customHeaders = opts.customHeaders or {}
	self.authMethod = opts.authMethod or 'Bearer'
	self.credentials = opts.credentials or Credentials:new()
end

function OAuth2Client:generateAuthUrl(params)
	if not params then params = {} end
	if not params.response_type then params.response_type = 'code' end
	if not params.client_id then params.client_id = self.clientID end
	if not params.redirect_uri then params.redirect_uri = self.redirectURI end
	return self.authorizeUrl .. '?' .. qs.stringify(params)
end

-- raw get token, no saving of credentials
function OAuth2Client:_getAccessToken(code, params, callback)
	if not params then params = {} end
	params['client_id'] = self.clientID
	params['client_secret'] = self.clientSecret
	params['grant_type'] = 'authorization_code'
	params['code'] = code

	return request.post(self.accessTokenUrl, {form = params, json = true}, function(err, tokens, response)
		if tokens and tokens.error then
			err = tostring(tokens.error) .. ": " .. tostring(tokens.error_description)
		end
		if not err and tokens and tokens.expires_in then
			tokens.expiry_date = os.time() + tokens.expires_in
		end
		if callback then
			return callback(err, tokens, response)
		end
	end)
end

-- raw refresh, no saving of credentials
function OAuth2Client:_refreshToken(refreshToken, callback)
	local params = {
		refresh_token = refreshToken,
		client_id = self.clientID,
		client_secret = self.clientSecret,
		grant_type = 'refresh_token',
	}

	return request.post(self.accessTokenUrl, {form = params, json = true}, function(err, tokens, response)
		if not err and tokens and tokens.expires_in then
			tokens.expiry_date = os.time() + tokens.expires_in
		end
		if callback then
			return callback(err, tokens, response)
		end
	end)
end

-- get access token and save credentials
function OAuth2Client:getAccessToken(code, redirect_uri, callback)
	if type(code) == 'function' then callback = code end
	if type(redirect_uri) == 'function' then callback = redirect_uri end

	if not self.credentials:exist() then
		return self:_getAccessToken(code, {redirect_uri = redirect_uri}, function(err, result, response)
			if not err then
				self.credentials:fromResponse(result)
				self:onCredentialsChanged()
			end
			if callback then
				local token = (result and result.access_token) or nil
				return callback(err, token, response)
			end
		end)
	end

	if self.credentials:shouldRefresh() then
		assert(self.credentials.refresh_token, "No refresh token set")

		return self:refreshAccessToken(function(err, tokens, response)
			return callback(err, tokens and tokens.access_token, response)
		end)
	else
		return callback(nil, self.credentials.access_token, nil)
	end
end

-- refresh and save credentials
function OAuth2Client:refreshAccessToken(callback)
	assert(self.credentials, "No credentials set")
	assert(self.credentials.refresh_token, "No refresh token set")

	return self:_refreshToken(self.credentials.refresh_token, function(err, result, response)
		if not err then
			self.credentials:fromResponse(result)
			self:onCredentialsChanged()
		end
		if callback then
			return callback(err, result, response)
		end
	end)
end

function OAuth2Client:getAuthorizationHeaders(callback)
	assert(self.credentials:exist(), "No refresh token or access token set")

	if self.credentials:isValid() then
		return callback(nil, self.credentials:buildHeaders(), nil)
	end

	return self:refreshAccessToken(function(err, tokens, response)
		return callback(err, tokens and self.credentials:buildHeaders(), response)
	end)
end

function OAuth2Client:setCredentials(credentials)
	assert(instanceof(credentials, Credentials), "setCredentials only accepts Crententials instances")
	self.credentials = credentials
	self:onCredentialsChanged()
end

function OAuth2Client:onCredentialsChanged()
	self:emit('creds', self.credentials)
end

function OAuth2Client:request(uri, opts, callback)
	return self:getAuthorizationHeaders(function(err, headers, response)
		if err then
			return callback(err, headers, response)
		else
			if not opts then opts = {} end
			if not opts.headers then opts.headers = {} end
			for k,v in pairs(headers) do
				opts.headers[k] = v
			end
			return request(uri, opts, callback)
		end
	end)
end

local function createMethodFunction(method)
	return function(self, uri, opts, callback)
		if not opts then opts = {} end
		opts.method = method
		return self:request(uri, opts, callback)
	end
end

OAuth2Client.get = createMethodFunction('GET')
OAuth2Client.head = createMethodFunction('HEAD')
OAuth2Client.post = createMethodFunction('POST')
OAuth2Client.put = createMethodFunction('PUT')
OAuth2Client.patch = createMethodFunction('PATCH')
OAuth2Client.delete = createMethodFunction('DELETE')

return OAuth2Client
