local http = require 'resty.http'
local json = require 'cjson'

-- The list of Nginx phase where 'ngx.var' can be found.
-- Detecting the current phase can be done using 'ngx.get_phase()' (https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxget_phase).
-- The supported phases for 'ngx.var' can be found here: https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxvarvariable.
local ALLOWED_PHASE_FOR_NGX_VAR = {
  ['set'] = true,
  ['rewrite'] = true,
  ['access'] = true,
  ['content'] = true,
  ['header_filter'] = true,
  ['body_filter'] = true,
  ['log'] = true,
  ['balancer'] = true,
}

-- The list of Nginx phase where 'ngx.req.XX' can be found.
-- Up to 4 functions from 'ngx.req' will be used to get the request information:
-- 1. ngx.req.get_method() to get the HTTP method
-- (https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxreqget_method)
-- 2. ngx.req.get_headers() to get the request headers
-- (https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxreqget_headers)
-- 3. (Optional) ngx.req.get_uri_args() to get the query string
-- (https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxreqget_uri_args)
-- 4. (Optional) ngx.req.get_post_args() to get the POST arguments
-- (https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#ngxreqget_post_args)
--
-- The following table is the list of Nginx phases supported by the 4 functions.
local ALLOWED_PHASE_FOR_NGX_REQ = {
  ['rewrite'] = true,
  ['access'] = true,
  ['content'] = true,
  ['header_filter'] = true,
  ['body_filter'] = true,
  ['log'] = true,
}

---@class resty.rollbar
---@field CRIT string
---@field ERR string
---@field WARN string
---@field INFO string
---@field DEBUG string
local _M = {
  version = '0.1.0',

  -- 	Rollbar severity levels as reported to the Rollbar API.
  CRIT    = 'critical',
  ERR     = 'error',
  WARN    = 'warning',
  INFO    = 'info',
  DEBUG   = 'debug',
}


-- Token is the Rollbar access token under which all items will be reported. If Token is blank, no errors will be
-- reported to Rollbar.
local token = nil
-- 	Environment is the environment under which all items will be reported.
local environment = 'development'
-- 	Endpoint is the URL destination for all Rollbar item POST requests.
local endpoint = 'https://api.rollbar.com/api/1/item/'

local rollbar_initted = nil

-- gethostname tries to find the host name of the machine executing this code. It first tries to
-- call the C function gethostname using FFI. If it fails it tries the command /bin/hostname. If it
-- fails again, it returns an empty string.
local function gethostname()
  local ffi = require "ffi"
  local C = ffi.C

  ffi.cdef [[
  int gethostname(char *name, size_t len);
  ]]

  local size = 50
  local buf = ffi.new("unsigned char[?]", size)

  local res = C.gethostname(buf, size)
  if res == 0 then
    return ffi.string(buf, size)
  end

  local f = io.popen("/bin/hostname", "r")
  if f then
    local host = f:read("*l")
    f:close()

    return host
  end
  return ''
end

-- send_request sends the given message at the specified level to Rollbar. This function should be
-- call asynchronously with ngx.timer.at.
--
-- First argument of a function called with ngx.timer.at is premature
-- (https://github.com/openresty/lua-nginx-module#ngxtimerat)
local function send_request(_, level, title, stacktrace, request)
  local body = {
    access_token = token,
    data = {
      environment = environment,
      body = {
        message = {
          body = stacktrace,
        },
      },
      level = level,
      timestamp = ngx.now(),
      platform = 'linux',
      language = 'lua',
      framework = 'OpenResty',
      request = request,
      server = { host = gethostname() },
      title = title,
      notifier = {
        name    = 'lua-resty-rollbar',
        version = _M.version,
      },
    },
  }

  local httpc = http.new()
  -- request_uri automatically closes the underlying connection so we don't need to close it by
  -- ourselves.
  local res, err = httpc:request_uri(endpoint, {
    method = 'POST',
    headers = {
      ['Content-Type'] = 'application/json',
      ['Accept'] = 'application/json, text/html;q=0.9',
    },
    ssl_verify = true,
    body = json.encode(body),
  })
  if not res then
    ngx.log(ngx.ERR, 'failed to send Rollbar error: ', err)
    return err
  end
  if res.status ~= 200 then
    ngx.log(ngx.ERR, 'invalid Rollbar response: ', res.status, ' - ', res.body)
    return 'invalid Rollbar response'
  end

  return false
end

-- isempty returns true if the given variable is nil or an empty string.
local function isempty(s)
  return s == nil or s == ''
end

-- set_token sets the token used by this client.
-- The value is a Rollbar access token with scope "post_server_item".
-- It is required to set this value before any of the other functions herein will be able to work
-- properly.
function _M.set_token(t)
  token = t
end

-- set_environment sets the environment under which all errors and messages will be submitted.
function _M.set_environment(env)
  environment = env
end

-- set_endpoint sets the endpoint to post items to.
function _M.set_endpoint(e)
  endpoint = e
end

-- report sends an error to Rollbar with the given level and title.
-- It fills the other fields using Nginx API for Lua
-- (https://github.com/openresty/lua-nginx-module#nginx-api-for-lua).
--
---@param level string#CRIT|ERR|WARN|INFO|DEBUG Rollbar severity level
---@param title any Report title. This field will be converted to a string if needed
---@param req_info table? Optional request information if this error was raised by a request.
-- If the `req_info` field is `nil`, the payload will be automatically filled using `read_request_info`.
-- If you know that this error was not raised by a request, you can supply `{}` (an empty table) to prevent extracting a non existing payload.
function _M.report(level, title, req_info)
  if rollbar_initted == nil then
    if isempty(token) then
      rollbar_initted = false
      ngx.log(ngx.ERR, 'Rollbar token not set, no error sent to Rollbar')
      return
    else
      rollbar_initted = true
    end
  end

  if not rollbar_initted then
    return
  end

  if type(title) ~= 'string' then
    title = tostring(title)
  end

  -- Extract request information if not provided by the caller.
  if req_info == nil then
    req_info = _M.read_request_info()
  end

  -- create a light thread to send the HTTP request in background
  ngx.timer.at(0, send_request, level, title, debug.traceback(), req_info)
end

-- read request information (URL, method, query string, args, user IP and headers) from Nginx variables.
-- This function is called when the request information is not provided by the caller.
-- This function may only be used in some Nginx phases. Calling this function in other phases will return `nil`.
--
---@return table? request_info optional request information extracted from Nginx variables
function _M.read_request_info()
  -- Before calling 'ngx.var' or 'ngx.req.XX', we need to check if the current phase is allowed.
  -- These variables may not be available in all phases (eg. inside a timer)
  local phase = ngx.get_phase()
  if ALLOWED_PHASE_FOR_NGX_REQ[phase] == nil or ALLOWED_PHASE_FOR_NGX_VAR[phase] == nil then
    return nil
  end

  local url = ngx.var.scheme .. '://' .. ngx.var.host .. ngx.var.request_uri
  local method = ngx.req.get_method()
  local request_info = {
    url = url,
    method = method,
    headers = ngx.req.get_headers(),
    query_string = ngx.var.args,
    user_ip = ngx.var.remote_addr,
  }
  if method == 'GET' then
    request_info.GET = ngx.req.get_uri_args()
  elseif method == 'POST' then
    request_info.POST = ngx.req.get_post_args()
  end

  return request_info
end

function _M.reset()
  token = nil
  environment = 'development'
  endpoint = 'https://api.rollbar.com/api/1/item/'
  rollbar_initted = nil
end

return _M
