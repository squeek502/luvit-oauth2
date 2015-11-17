local OAuth2Client = require('./oauth2client')

local GoogleClient = OAuth2Client:extend()

GoogleClient.GOOGLE_OAUTH2_AUTH_BASE_URL = 'https://accounts.google.com/o/oauth2/auth'
GoogleClient.GOOGLE_OAUTH2_TOKEN_URL = 'https://accounts.google.com/o/oauth2/token'
GoogleClient.GOOGLE_OAUTH2_REVOKE_URL = 'https://accounts.google.com/o/oauth2/revoke'

function GoogleClient:initialize(clientID, clientSecret, opts)
	self.meta.super.initialize(self, clientID, clientSecret, GoogleClient.GOOGLE_OAUTH2_AUTH_BASE_URL, GoogleClient.GOOGLE_OAUTH2_TOKEN_URL, opts)
end

function GoogleClient:generateAuthUrl(params)
	if not params then params = {} end
	-- allow scopes to be passed either as array or a string
	if type(params.scope) == "table" then
		params.scope = table.concat(params.scope, ' ')
	end
	return self.meta.super.generateAuthUrl(self, params)
end

return GoogleClient