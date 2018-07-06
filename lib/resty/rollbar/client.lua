local http = require 'resty.http'
local json = require 'cjson'

local ngx = ngx

local _M = {
  version  = '0.1.0',

  -- 	Rollbar severity levels as reported to the Rollbar API.
  CRIT  = 'critical',
  ERR   = 'error',
  WARN  = 'warning',
  INFO  = 'info',
  DEBUG = 'debug',
}


-- Token is the Rollbar access token under which all items will be reported. If Token is blank, no errors will be
-- reported to Rollbar.
local token = nil
-- 	Environment is the environment under which all items will be reported.
local environment = 'development'
-- 	Endpoint is the URL destination for all Rollbar item POST requests.
local endpoint = 'https://api.rollbar.com/api/1/item/'

local rollbar_initted = nil

local function send_request(level, msg)
  local body = {
    access_token = token,
    data = {
      environment = environment,
      title = msg,
      level = level,
      timestamp = ngx.now(),
      platform = 'linux',
      language = 'lua',
      server = { host = 'TODO' },
      notifier = {
        name    = 'lua-resty-rollbar',
        version = _M.version,
      },
      body = {
        trace = {
          frames = debug.traceback(),
        },
      },
    },
  }

  local httpc = http.new()
  local res, err = httpc:request_uri(endpoint, {
    method = ngx.HTTP_POST,
    body = json.encode(body),
    headers = {
      ['Content-Type'] = 'application/json',
    },
    ssl_verify = true,
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

function _M.set_token(t)
  token = t
end

function _M.set_environment(env)
  environment = env
end

function _M.set_endpoint(e)
  endpoint = e
end

function _M.report(level, msg)
  if rollbar_initted == nil and token == nil then
    rollbar_initted = false
    ngx.log(ngx.ERR, 'Rollbar token not set, no error sent to Rollbar')
    return
  end

  if not rollbar_initted then
    return
  end
  rollbar_initted = true

  if type(msg) ~= 'string' then
    msg = tostring(msg)
  end

  -- create a light thread to send the HTTP request in background
  ngx.timer.at(0, send_request, level, msg)
end

return _M
