# lua-resty-rollbar [ ![Codeship Status for Scalingo/lua-resty-rollbar](https://app.codeship.com/projects/d0902e10-6667-0136-c148-5e8eddb6d7b2/status?branch=master)](https://app.codeship.com/projects/297381)

Simple module for [OpenResty](http://openresty.org/) to send errors to
[Rollbar](https://rollbar.com).

`lua-resty-rollbar` is a Lua Rollbar client that makes it easy to report errors to Rollbar with
stack traces. Errors are sent to Rollbar asynchronously in a light thread.

## Installation

Install using LuaRocks:

```
luarocks install lua-resty-rollbar 0.1.0
```

## Usage

```lua
local rollbar = require 'resty.rollbar'

rollbar.set_token('MY_TOKEN')
rollbar.set_environment('production') -- defaults to 'development'

function main()
	res, err = do_something()
	if not res {
		// Error reporting
		rollbar.report(rollbar.ERR, err)
		return
	}
end
```

## Execute the tests

The tests are written using the [busted](http://olivinelabs.com/busted/) unit testing
framework. To ease the testing of this package, we provide a self contained Docker Compose file
to execute the unit tests.

Run the Docker Compose container in a terminal:

```
docker-compose up
```

In a different terminal, execute the tests with:

```
docker-compose exec test busted specs
```

## Publish on LuaRocks

```
luarocks upload --api-key=<API key> ./lua-resty-rollbar-0.1.0-1.rockspec
```

The API key is from [LuaRocks settings](https://luarocks.org/settings/api-keys).
