#!/bin/bash
# This script is executed to setup Codeship environment in which tests are executed.

set -o errexit
set -x

# The VERSION environment variables are defined in Codeship environment
# (https://app.codeship.com/projects/297381/environment/edit)
RESTY_VERSION="${RESTY_VERSION:-1.11.2.5}"
RESTY_LUAROCKS_VERSION="${RESTY_LUAROCKS_VERSION:-2.3.0}"
RESTY_OPENSSL_VERSION="${RESTY_OPENSSL_VERSION:-1.0.2k}"
RESTY_PCRE_VERSION="${RESTY_PCRE_VERSION:-8.40}"

RESTY_HOME="$HOME/cache/openresty"
RESTY_J="1"
export LUA_PATH="$HOME/src/github.com/Scalingo/lua-resty-rollbar/lib/?.lua;;"

function versions {
  echo "${RESTY_VERSION}|${RESTY_LUAROCKS_VERSION}|${RESTY_OPENSSL_VERSION}|${RESTY_PCRE_VERSION}"
}

VERSIONS=$(versions)
if [[ ! -f "$RESTY_HOME/.versions" ]] || [[ "${VERSIONS}" != "$(cat $RESTY_HOME/.versions)" ]]; then
  cs clear-cache
  mkdir -p $RESTY_HOME

  RESTY_CONFIG_OPTIONS="\
  --with-file-aio \
  --with-http_addition_module \
  --with-http_auth_request_module \
  --with-http_gunzip_module \
  --with-http_realip_module \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-ipv6 \
  --with-md5-asm \
  --with-pcre-jit \
  --with-sha1-asm \
  --with-stream \
  --with-stream_ssl_module \
  --with-threads \
  "
  RESTY_CONFIG_OPTIONS_MORE=""
  _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"

  cd /tmp \
      && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
      && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
      && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
      && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
      && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
      && tar xzf openresty-${RESTY_VERSION}.tar.gz \
      && cd /tmp/openresty-${RESTY_VERSION} \
      && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} --prefix=$RESTY_HOME \
      && make -j${RESTY_J} \
      && make -j${RESTY_J} install

  cd /tmp \
      && rm -rf \
          openssl-${RESTY_OPENSSL_VERSION} \
          openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
          openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
          pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
      && curl -fSL http://luarocks.org/releases/luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
      && tar xzf luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
      && cd luarocks-${RESTY_LUAROCKS_VERSION} \
      && ./configure \
          --prefix=$RESTY_HOME/luajit \
          --with-lua=$RESTY_HOME/luajit \
          --lua-suffix=jit-2.1.0-beta3 \
          --with-lua-include=$RESTY_HOME/luajit/include/luajit-2.1 \
      && make build \
      && make install \
      && cd /tmp \
      && rm -rf luarocks-${RESTY_LUAROCKS_VERSION} luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
      && ln -sf /dev/stdout $RESTY_HOME/nginx/logs/access.log \
      && ln -sf /dev/stderr $RESTY_HOME/nginx/logs/error.log

  $RESTY_HOME/luajit/bin/luarocks install lua-messagepack 0.5.1 \
      && $RESTY_HOME/luajit/bin/luarocks install lua-resty-uuid 1.1 \
      && $RESTY_HOME/luajit/bin/luarocks install lua-resty-http 0.10 \
      && $RESTY_HOME/luajit/bin/luarocks install lua-resty-cookie 0.1.0 \
      && $RESTY_HOME/luajit/bin/luarocks install lua-resty-rollbar 0.1.0 \
      && $RESTY_HOME/luajit/bin/luarocks install busted

  cd /tmp
  git clone https://github.com/thibaultcha/lua-resty-busted
  cp lua-resty-busted/bin/busted $RESTY_HOME/luajit/bin
  rm -rf /tmp/lua-resty-busted
  chmod +x $RESTY_HOME/luajit/bin/busted

  echo "${VERSIONS}" > $RESTY_HOME/.versions
fi

cd $HOME/src/github.com/Scalingo/lua-resty-rollbar

cat <<EOF > $RESTY_HOME/resty_launcher.sh
#!/bin/sh

$RESTY_HOME/bin/resty \$*
EOF
chmod +x $RESTY_HOME/resty_launcher.sh

# Replace busted shebang with resty_launcher
sed -i "1s|.*|#\!$RESTY_HOME/resty_launcher.sh|" $RESTY_HOME/luajit/bin/busted

# The following line must be used in the Pipeline script of Codeship:
# $RESTY_HOME/luajit/bin/busted $HOME/src/github.com/Scalingo/lua-resty-rollbar/specs/
