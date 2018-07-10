local match = require 'luassert.match'

describe('rollbar.report', function()
  it('should not do anything if the token is empty', function()
    local rollbar = require('resty.rollbar')
    rollbar.reset()
    stub(ngx.timer, 'at')

    rollbar.report(rollbar.ERR, 'test message')

    assert.stub(ngx.timer.at).was_not_called()
  end)

  -- it('should call send_request in a light thread', function()
  --   local rollbar = require('resty.rollbar')
  --   rollbar.reset()
  --   rollbar.set_token('TEST TOKEN')

  --   rollbar.report(rollbar.ERR, 'test message')

  --   assert.stub(ngx.timer.at).was_called()
  --   assert.stub(ngx.timer.at).was_called_with(match._, match._, match._, match._, match._, match._)
  -- end)
end)
