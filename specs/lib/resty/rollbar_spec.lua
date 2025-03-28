local assert      = require 'luassert.assert'
local stub        = require 'luassert.stub'
local describe    = describe ---@diagnostic disable-line: undefined-global
local it          = it ---@diagnostic disable-line: undefined-global
local before_each = before_each ---@diagnostic disable-line: undefined-global
local rollbar     = require 'resty.rollbar'

describe('rollbar.report', function()
  describe('without token', function()
    before_each(function()
      rollbar.reset()
    end)

    it('should not do anything if the token is empty', function()
      stub(ngx.timer, 'at')

      rollbar.report(rollbar.ERR, 'test message')

      assert.stub(ngx.timer.at).was_not_called()
    end)
  end)

  describe('with token', function()
    before_each(function()
      rollbar.reset()
      rollbar.set_token('TEST TOKEN')
    end)

    it('should call read_request_info if req_info is not provided', function()
      stub(rollbar, 'read_request_info')

      rollbar.report(rollbar.ERR, 'test message')

      assert.stub(rollbar.read_request_info).was_called()
    end)

    it('should call read_request_info if req_info is nil', function()
      stub(rollbar, 'read_request_info')

      rollbar.report(rollbar.ERR, 'test message')

      assert.stub(rollbar.read_request_info).was_called()
    end)

    it('should not call read_request_info if req_info is an empty table', function()
      stub(rollbar, 'read_request_info')

      rollbar.report(rollbar.ERR, 'test message', {})

      assert.stub(rollbar.read_request_info).was_not_called()
    end)

    it('should not call read_request_info if req_info is provided', function()
      stub(rollbar, 'read_request_info')

      rollbar.report(rollbar.ERR, 'test message', {
        method = 'GET',
        url = 'http://example.com',
        headers = { ['Content-Type'] = 'application/json' },
        query_string = 'foo=bar',
      })

      assert.stub(rollbar.read_request_info).was_not_called()
    end)
  end)
end)
