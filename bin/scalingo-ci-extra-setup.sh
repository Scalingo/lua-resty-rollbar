#!/bin/bash
set -euo pipefail

# Install OpenResty and LuaRocks
wget -qO - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list
sudo apt-get update
sudo apt-get install -y --no-install-recommends openresty openresty-resty openresty-opm luarocks

# Configure environment
LUAROCKS_TREE="${RUNNER_TEMP}/luarocks"
mkdir -p "${LUAROCKS_TREE}"
echo "LUAROCKS_TREE=${LUAROCKS_TREE}" >> "${GITHUB_ENV}"
echo "/usr/local/openresty/bin" >> "${GITHUB_PATH}"
echo "/usr/local/openresty/luajit/bin" >> "${GITHUB_PATH}"
echo "${LUAROCKS_TREE}/bin" >> "${GITHUB_PATH}"

# Install test dependencies
luarocks --tree "${LUAROCKS_TREE}" install busted
luarocks --tree "${LUAROCKS_TREE}" install lua-resty-http
luarocks --tree "${LUAROCKS_TREE}" install lua-cjson

# Install resty-busted (runs busted in OpenResty context with ngx available)
git clone --depth 1 https://github.com/thibaultcha/lua-resty-busted /tmp/lua-resty-busted
sudo cp /tmp/lua-resty-busted/bin/busted /usr/local/bin/resty-busted
sudo chmod +x /usr/local/bin/resty-busted

# Export LUA paths (include lib directory for the rollbar module)
echo "LUA_PATH=${GITHUB_WORKSPACE}/lib/?.lua;$(luarocks --tree "${LUAROCKS_TREE}" path --lr-path)" >> "${GITHUB_ENV}"
echo "LUA_CPATH=$(luarocks --tree "${LUAROCKS_TREE}" path --lr-cpath)" >> "${GITHUB_ENV}"
