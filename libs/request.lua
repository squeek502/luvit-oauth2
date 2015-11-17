local http = require 'http'
local https = require 'https'
local headerMeta = http.headermeta
local json = require 'json'
local qs = require 'querystring'

local request

local createMethodFunction = function(method)
	return function(uri, options, callback)
		options.method = method
		return request(nil, uri, options, callback)
	end
end

local methods = {
	get = createMethodFunction('GET'),
	head = createMethodFunction('HEAD'),
	post = createMethodFunction('POST'),
	put = createMethodFunction('PUT'),
	patch = createMethodFunction('PATCH'),
	delete = createMethodFunction('DELETE'),
}
methods.del = methods.delete

local function headersToCaseInsensitiveHeaderTable(headers)
	local caseInsensitiveHeaders = setmetatable({}, headerMeta)
	if headers then
		for k,v in pairs(headers) do
			caseInsensitiveHeaders[k] = v
		end
	end
	return caseInsensitiveHeaders
end

local function isContentTypeFormUrlEncoded(contentType)
	return contentType and contentType:match("^application/x%-www%-form%-urlencoded[%s%p]?") ~= nil
end

local function isContentTypeJson(contentType)
	return contentType and contentType:match("^application/json[%s%p]?") ~= nil
end

-- first parameter is the proxy table with the __call metamethod
function request(_, uri, options, callback)
	if not callback and type(options) == "function" then
		callback = options
		options = {}
	end

	local req = http.parseUrl(uri)

	for k,v in pairs(options) do
		req[k] = v
	end
	req.headers = headersToCaseInsensitiveHeaderTable(req.headers)

	if req.json then
		if not req.headers['accept'] then
			req.headers['accept'] = 'application/json'
		end
		if not req.headers['content-type'] and (req.body or type(req.json) ~= "boolean") then
			req.headers['content-type'] = 'application/json'
		end

		if type(req.json) == "boolean" and req.body then
			if isContentTypeFormUrlEncoded(req.headers['content-type']) then
				req.body = json.stringify(req.body)
			else
				req.body = qs.stringify(req.body)
			end
		else
			req.body = json.stringify(req.json)
		end
	end

	if req.form then
		if not isContentTypeFormUrlEncoded(req.headers['content-type']) then
			req.headers['content-type'] = 'application/x-www-form-urlencoded'
		end

		req.body = qs.stringify(req.form)
	end

	local requester
	if (req.protocol == 'https') then requester = https else requester = http end

	if req.body then
		req.headers['Content-Length'] = #req.body
	else
		req.headers['Content-Length'] = 0
	end

	local requestObj = requester.request(req, function(res)
		if callback then
			local data = ''
			res:on("data", function(chunk)
				data = data .. chunk
			end)
			res:on("end", function()
				if req.json or isContentTypeJson(res.headers['content-type']) then
					data = json.parse(data)
				end
				callback(nil, data, res)
			end)
			res:on("close", function()
				callback(nil, data, res)
			end)
		end
	end)
	requestObj:on("error", function(...)
		if callback then callback(...) end
	end)
	if req.body then
		requestObj:write(req.body)
	end
	if callback then
		requestObj:done()
	end

	return requestObj
end

return setmetatable({}, {
	__call = request,
	__index = methods
})