# lua-resty-rollbar [![Codeship Status for Scalingo/lua-resty-rollbar](https://app.codeship.com/projects/d0902e10-6667-0136-c148-5e8eddb6d7b2/status?branch=master)](https://app.codeship.com/projects/297381)

Simple module for [OpenResty](http://openresty.org/) to send errors to
[Rollbar](https://rollbar.com).

`lua-resty-rollbar` is a Lua Rollbar client that makes it easy to report errors to Rollbar with
stack traces. Errors are sent to Rollbar asynchronously in a light thread.

## Installation

As of version `0.2.0`, the project is unfortunately not published to LuaRocks because we are having trouble getting an answer on our Github issue to transfer the project (https://github.com/luarocks/luarocks-site/issues/218).

However, you can install the project directly using the rockspec URL:

```bash
luarocks install 'https://github.com/Scalingo/lua-resty-rollbar/releases/download/0.2.0/lua-resty-rollbar-0.2.0-1.rockspec'
```

If you are looking for older versions, they are [available on LuaRocks directly](https://luarocks.org/modules/etiennem/lua-resty-rollbar):

```bash
luarocks install lua-resty-rollbar 0.1.0
```

## Usage

```lua
local rollbar = require 'resty.rollbar'

-- Set your Rollbar token
-- This token must have 'post_server_item' scope
rollbar.set_token('MY_TOKEN')
-- Set the set_environment. Defaults to 'development'
rollbar.set_environment('production')

function main()
	local res, err = do_something()
	if not res {
		-- Error reporting
		-- This function will automatically read request information (URI, method,...) if available before reporting the error to Rollbar
		rollbar.report(rollbar.ERR, err)

		-- If the error reporting occurs from outside a request context (eg. inside a timer), you can supply a third parameter to prevent
		-- an useless function call that will try to read non existing request information
		rollbar.report(rollbar.ERR, err, {})

		return
	}
end
```

## Execute the tests

The tests are written using the [busted](http://olivinelabs.com/busted/) unit testing
framework. To ease the testing of this package, we provide a self contained Docker Compose file
to execute the unit tests.

Run the Docker Compose container in a terminal:

```bash
docker compose up
```

In a different terminal, execute the tests with:

```bash
docker compose exec test busted specs
```

## Publish on LuaRocks

```bash
luarocks upload --api-key=<API key> ./lua-resty-rollbar-0.2.0-1.rockspec
```

The API key is from [LuaRocks settings](https://luarocks.org/settings/api-keys).
