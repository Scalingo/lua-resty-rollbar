FROM openresty/openresty:1.11.2.5-jessie
MAINTAINER Scalingo Team "tech@scalingo.com"

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install --yes git \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove --yes \
    && rm -rf /var/lib/apt/lists/*

# Install this package dependencies:
RUN luarocks install lua-resty-http
RUN luarocks install lua-cjson

# Install the test framework:
RUN luarocks install busted
# We actually can't use the LuaRocks version as it contains a blocking bug
# (https://github.com/thibaultcha/lua-resty-busted/issues/1) which is fixed on master.
# RUN luarocks install lua-resty-busted
RUN git clone https://github.com/thibaultcha/lua-resty-busted /tmp/lua-resty-busted \
    && cp /tmp/lua-resty-busted/bin/busted /usr/local/bin \
    && chmod +x /usr/local/bin/busted \
    && rm -fr /tmp/lua-resty-busted

COPY ./entrypoint.sh /

ENTRYPOINT ["bash"]
CMD ["/entrypoint.sh"]
