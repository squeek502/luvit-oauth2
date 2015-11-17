local Object = require('core').Object
local json = require('json')
local Credentials = require('./credentials')
local http = require('http')
local fs = require('fs')
local url = require('url')

local AuthFlow = Object:extend()

local DEFAULT_LISTEN_PORT = 8080
local DEFAULT_CREDS_FILE = "credentials.json"

function AuthFlow.getClientSecrets(clientSecretsFile)
	local client_secrets = json.parse(fs.readFileSync(clientSecretsFile))
	client_secrets = client_secrets.web or client_secrets.installed
	return client_secrets.client_id, client_secrets.client_secret
end

function AuthFlow:initialize(authClient, authCredsFile, listenPort)
	self.client = authClient
	self.creds_file = authCredsFile or DEFAULT_CREDS_FILE
	self.listen_port = listenPort or DEFAULT_LISTEN_PORT
	self.client:on('creds', function(creds)
		if creds and creds:exist() then
			fs.writeFile(self.creds_file, json.stringify(creds))
		end
	end)
end

function AuthFlow:getRedirectURI()
	return 'http://localhost:'..self.listen_port
end

function AuthFlow:createAuthServer(callback)
	local server
	server = http.createServer(function(req, res)
		local code = url.parse(req.url, true).query.code

		if code then
			self.client:getAccessToken(code, self:getRedirectURI(), function(err)
				local body
				if err then
					body = tostring(err)
					callback(err)
				else
					body = "Authenticated\n"
					callback()
				end
				res:setHeader("Content-Type", "text/plain")
				res:setHeader("Content-Length", #body)
				res:finish(body)
				server:close()
			end)
		else
			res.statusCode = 404
			res:finish()
		end
	end)
	return server
end

function AuthFlow:start(params, callback)
	if not params then params = {} end

	local credentials

	if fs.existsSync(self.creds_file) then
		credentials = Credentials.fromJson(fs.readFileSync(self.creds_file))
	end

	if not credentials or not credentials:exist() then
		local opts = {
			redirect_uri = self:getRedirectURI(),
		}
		for k,v in pairs(params) do
			opts[k] = v
		end

		local authURL = self.client:generateAuthUrl(opts)
		print('Visit the URL:')
		print(authURL)

		local server = self:createAuthServer(function(err)
			callback(err)
		end)
		server:listen(self.listen_port)
	else
		self.client:setCredentials(credentials)
		callback()
	end
end

return AuthFlow