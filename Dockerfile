FROM openresty/openresty:1.27.1.2-jammy

LABEL maintainer="Scalingo Team <tech@scalingo.com>"

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get install -y --no-install-recommends git \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove --yes \
    && rm -rf /var/lib/apt/lists/*

# Install this package dependencies:
RUN luarocks install lua-resty-http
RUN luarocks install lua-cjson

# Install the test framework:
RUN luarocks install busted
RUN luarocks install lua-resty-busted

COPY ./entrypoint.sh /

ENTRYPOINT ["bash"]
CMD ["/entrypoint.sh"]
