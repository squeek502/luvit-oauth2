local GoogleClient = require('./libs/googleclient')
local AuthFlow = require('./libs/authflow')
local json = require('json')
local fs = require('fs')

local CLIENT_SECRETS_FILE = "client_secrets.json"

local YOUTUBE_UPLOAD_SCOPE = "https://www.googleapis.com/auth/youtube.upload"
local YOUTUBE_API_SERVICE_NAME = "youtube"
local YOUTUBE_API_VERSION = "v3"

local VALID_PRIVACY_STATUSES = {"public", "private", "unlisted"}

local client = GoogleClient:new(AuthFlow.getClientSecrets(CLIENT_SECRETS_FILE))
local flow = AuthFlow:new(client)

local function initializeResumableUpload(auth, filepath, callback)
	local parts = "status,snippet"
	local url = "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=" .. parts
	local body = {
		snippet = {
			title = "Test"
		},
		status = {
			privacyStatus = "private"
		}
	}

	local headers = {
		["X-Upload-Content-Length"] = fs.statSync(filepath).size,
		["X-Upload-Content-Type"] = "video/*",
	}

	auth:post(url, {headers=headers, body=body, json=true}, function(err, data, res)
		if err then
			p(err, data, res)
			return
		end
		if data and data.error then
			p(data.error.code, data.error.message)
			return
		end

		callback(res.headers.location, res)
	end)
end

local function uploadVideo()
	local videopath = "video.mp4"
	initializeResumableUpload(client, videopath, function(upload_url, init_res)
		client:post(upload_url, {headers = {["content-type"] = "video/*"}, body = fs.readFileSync(videopath)}, function(err, data, res)
			if not err then p(data) else p(err) end
		end)
	end)
end

flow:start({
	access_type = 'offline',
	scope = YOUTUBE_UPLOAD_SCOPE,
}, 
function(err)
	if not err then 
		p('Authed!')
		uploadVideo()
	else
		p(err)
	end
end)
