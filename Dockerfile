# NOTE: these MUST be provided
ARG OPERATING_SYSTEM_VERSION=18.04
ARG OPERATING_SYSTEM_CODENAME=bionic

# NOTE: these are recommended to be provided
ARG NGINX_VERSION=1.20.1
ARG PASSENGER_VERSION=6.0.6

# NOTE: these are updated as required (build dependencies)
ARG AUTOMAKE_VERSION=1.16.1
ARG OPENSSL_VERSION=1.1.1g
ARG PCRE_VERSION=8.44
ARG ZLIB_VERSION=1.2.11
ARG LIBGD_VERSION=2.3.2
ARG MODSECURITY_VERSION=3.0.4
ARG LUAJIT2_VERSION=2.1.0-beta3
ARG LUAJIT2_PACKAGE_VERSION=2.1-20210510
ARG LUAJIT2_SHORT_VERSION=2.1
ARG LUA_RESTY_CORE_VERSION=0.1.21
ARG LUA_RESTY_LRUCACHE_VERSION=0.10
ARG LIBMAXMINDDB_VERSION=1.6.0

# NOTE: these are updated as required (NGINX modules)
ARG MODSECURITY_MODULE_VERSION=1.0.1
ARG HEADERS_MORE_MODULE_VERSION=0.33
ARG HTTP_AUTH_PAM_MODULE_VERSION=1.5.2
ARG CACHE_PURGE_MODULE_VERSION=2.4.3
ARG DAV_EXT_MODULE_VERSION=3.0.0
ARG DEVEL_KIT_MODULE_VERSION=0.3.1
ARG ECHO_MODULE_VERSION=0.62
ARG FANCYINDEX_MODULE_VERSION=0.5.1
ARG NCHAN_MODULE_VERSION=1.2.8
ARG LUA_MODULE_VERSION=0.10.19
ARG RTMP_MODULE_VERSION=1.2.1
ARG UPLOAD_PROGRESS_MODULE_VERSION=0.9.2
ARG UPSTREAM_FAIR_MODULE_VERSION=0.1.3
ARG HTTP_SUBSTITUTIONS_FILTER_MODULE_VERSION=0.6.4
ARG HTTP_GEOIP2_MODULE_VERSION=3.3

# NOTE: these are debian package versions derived from the above (for packages that will be publicly published)
# NOTE: tried using debian epoch BUT it looks like there's a bug in apt where if the package name contains a ':' character, it doesn't install the package (says nothing to be done)
# ARG DEBIAN_EPOCH_PREFIX="1:"
ARG DEBIAN_EPOCH_PREFIX=""
ARG DEBIAN_REVISION="-1~${OPERATING_SYSTEM_CODENAME}1"
ARG MODSECURITY_DEB_VERSION="${DEBIAN_EPOCH_PREFIX}${MODSECURITY_VERSION}${DEBIAN_REVISION}"
ARG LUAJIT2_DEB_VERSION="${DEBIAN_EPOCH_PREFIX}${LUAJIT2_PACKAGE_VERSION}${DEBIAN_REVISION}"
ARG LUA_RESTY_CORE_DEB_VERSION="${DEBIAN_EPOCH_PREFIX}${LUA_RESTY_CORE_VERSION}${DEBIAN_REVISION}"
ARG LUA_RESTY_LRUCACHE_DEB_VERSION="${DEBIAN_EPOCH_PREFIX}${LUA_RESTY_LRUCACHE_VERSION}${DEBIAN_REVISION}"
ARG NGINX_DEB_VERSION="${DEBIAN_EPOCH_PREFIX}${NGINX_VERSION}${DEBIAN_REVISION}"
ARG PASSENGER_DEB_VERSION="${DEBIAN_EPOCH_PREFIX}${PASSENGER_VERSION}${DEBIAN_REVISION}"
ARG NGINX_PASSENGER_MODULE_DEB_VERSION="${DEBIAN_EPOCH_PREFIX}${PASSENGER_VERSION}+nginx${NGINX_VERSION}${DEBIAN_REVISION}"

FROM ubuntu:$OPERATING_SYSTEM_VERSION AS base
ARG AUTOMAKE_VERSION
WORKDIR /usr/local/build

RUN mkdir -p /usr/local/sources
RUN mkdir -p /usr/local/build
RUN mkdir -p /usr/local/deb_sources
RUN mkdir -p /usr/local/debs

RUN apt-get update &&\
    apt-get install -y software-properties-common &&\
    apt-add-repository ppa:brightbox/ruby-ng &&\
    apt-get update &&\
    apt-get install -y apt-utils autoconf build-essential curl git libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpam0g-dev libpcre++-dev libperl-dev libtool libxml2-dev libxslt-dev libyajl-dev pkgconf ruby-dev ruby2.7 ruby2.7-dev vim wget zlib1g-dev 

# NGINX seems to require a specific version of automake, but only sometimes...
RUN wget https://ftp.gnu.org/gnu/automake/automake-${AUTOMAKE_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/automake-${AUTOMAKE_VERSION}.tar.gz &&\
    cd automake-${AUTOMAKE_VERSION} &&\
    ./configure &&\
    make &&\
    make install

ADD current_state.sh /usr/local/bin
ADD generate_deb.rb /usr/local/bin
ADD include_modules.rb /usr/local/bin
ADD setup_passenger.rb /usr/local/bin
ADD test_nginx.sh /usr/local/bin

# CONFIGURE REQUIREMENTS FOR MODULES
######################################################################################################################################################################################################################################

FROM base AS openssl
ARG OPENSSL_VERSION
WORKDIR /usr/local/build

RUN wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -P /usr/local/sources

RUN dpkg --purge --force-all openssl
RUN current_state.sh before

# Required for NGINX: https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/#compiling-and-installing-from-source
RUN tar -zxf /usr/local/sources/openssl-${OPENSSL_VERSION}.tar.gz &&\
    cd openssl-${OPENSSL_VERSION} &&\
    ./config --prefix=/usr --openssldir=/usr shared zlib &&\
    make &&\
    make install

RUN echo "/usr/lib" > /etc/ld.so.conf.d/openssl-${OPENSSL_VERSION}.conf
RUN ldconfig
RUN rm -rf /usr/certs && cp -r /etc/ssl/certs /usr/certs

RUN current_state.sh after
RUN generate_deb.rb openssl ${OPENSSL_VERSION} binary
RUN generate_deb.rb openssl ${OPENSSL_VERSION} source

######################################################################################################################################################################################################################################

FROM base AS pcre
ARG PCRE_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for NGINX: https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/#compiling-and-installing-from-source
RUN wget https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz -P /usr/local/sources &&\
    tar -zxf /usr/local/sources/pcre-${PCRE_VERSION}.tar.gz &&\
    cd pcre-${PCRE_VERSION} &&\
    ./configure &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb pcre ${PCRE_VERSION} binary
RUN generate_deb.rb pcre ${PCRE_VERSION} source

######################################################################################################################################################################################################################################

FROM base AS zlib
ARG ZLIB_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for NGINX: https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/#compiling-and-installing-from-source
RUN wget https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz -P /usr/local/sources &&\
    tar -zxf /usr/local/sources/zlib-${ZLIB_VERSION}.tar.gz &&\
    cd zlib-${ZLIB_VERSION} &&\
    ./configure &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb zlib ${ZLIB_VERSION} binary
RUN generate_deb.rb zlib ${ZLIB_VERSION} source

######################################################################################################################################################################################################################################

FROM base AS libgd
ARG LIBGD_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for NGINX to run - installing latest instead of installing libgd-dev on the customer's servers
RUN wget https://github.com/libgd/libgd/releases/download/gd-${LIBGD_VERSION}/libgd-${LIBGD_VERSION}.tar.gz -P /usr/local/sources &&\
    tar -zxf /usr/local/sources/libgd-${LIBGD_VERSION}.tar.gz &&\
    cd libgd-${LIBGD_VERSION} &&\
    ./configure &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb libgd ${LIBGD_VERSION} binary

######################################################################################################################################################################################################################################

FROM base AS modsecurity
ARG MODSECURITY_VERSION
ARG MODSECURITY_DEB_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for modsecurity-nginx: https://www.nginx.com/blog/compiling-and-installing-modsecurity-for-open-source-nginx/
RUN wget https://github.com/SpiderLabs/ModSecurity/releases/download/v${MODSECURITY_VERSION}/modsecurity-v${MODSECURITY_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/modsecurity-v${MODSECURITY_VERSION}.tar.gz &&\
    cd modsecurity-v${MODSECURITY_VERSION} &&\
    ./build.sh &&\
    ./configure &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb modsecurity ${MODSECURITY_DEB_VERSION} binary

######################################################################################################################################################################################################################################

FROM base AS luajit2
ARG LUAJIT2_PACKAGE_VERSION
ARG LUAJIT2_DEB_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for the NGINX lua module
RUN wget https://github.com/openresty/luajit2/archive/refs/tags/v${LUAJIT2_PACKAGE_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/v${LUAJIT2_PACKAGE_VERSION}.tar.gz &&\
    cd luajit2-${LUAJIT2_PACKAGE_VERSION} &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb openresty-luajit ${LUAJIT2_DEB_VERSION} binary

######################################################################################################################################################################################################################################

FROM base AS lua-resty-core
ARG LUA_RESTY_CORE_VERSION
ARG LUA_RESTY_CORE_DEB_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for NGINX lua module
RUN wget https://github.com/openresty/lua-resty-core/archive/refs/tags/v${LUA_RESTY_CORE_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/v${LUA_RESTY_CORE_VERSION}.tar.gz &&\
    cd lua-resty-core-${LUA_RESTY_CORE_VERSION} &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb openresty-lua-core ${LUA_RESTY_CORE_DEB_VERSION} binary

######################################################################################################################################################################################################################################

FROM base AS lua-resty-lrucache
ARG LUA_RESTY_LRUCACHE_VERSION
ARG LUA_RESTY_LRUCACHE_DEB_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for NGINX lua module
RUN wget https://github.com/openresty/lua-resty-lrucache/archive/refs/tags/v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz &&\
    cd lua-resty-lrucache-${LUA_RESTY_LRUCACHE_VERSION} &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb openresty-lua-lrucache ${LUA_RESTY_LRUCACHE_DEB_VERSION} binary

######################################################################################################################################################################################################################################

FROM base AS libmaxminddb
ARG LIBMAXMINDDB_VERSION
WORKDIR /usr/local/build

RUN current_state.sh before

# Required for NGINX GeoIP module
RUN wget https://github.com/maxmind/libmaxminddb/releases/download/${LIBMAXMINDDB_VERSION}/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/libmaxminddb-${LIBMAXMINDDB_VERSION}.tar.gz &&\
    cd libmaxminddb-${LIBMAXMINDDB_VERSION} &&\
    ./configure &&\
    make &&\
    make install

RUN current_state.sh after
RUN generate_deb.rb libmaxminddb ${LIBMAXMINDDB_VERSION} binary

######################################################################################################################################################################################################################################

FROM base AS passenger
ARG PASSENGER_VERSION
ARG NGINX_VERSION
ARG NGINX_DEB_VERSION
ARG PASSENGER_DEB_VERSION
ARG NGINX_PASSENGER_MODULE_DEB_VERSION
WORKDIR /usr/local/build

# NOTE: prerequisites for the apache module - compilation process installs everything, unfortunately
RUN apt-get install -y apache2 apache2-dev

COPY --from=openssl /usr/local/debs /usr/local/debs
RUN dpkg -i /usr/local/debs/*.deb

# NOTE: directory is called passenger-release-${PASSENGER_VERSION}
RUN wget https://github.com/phusion/passenger/archive/refs/tags/release-${PASSENGER_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/release-${PASSENGER_VERSION}.tar.gz &&\
    cd passenger-release-${PASSENGER_VERSION} &&\
    rake fakeroot

RUN current_state.sh before
RUN cp -a passenger-release-${PASSENGER_VERSION}/pkg/fakeroot/* /
RUN cd passenger-release-${PASSENGER_VERSION} && setup_passenger.rb
RUN current_state.sh after
RUN generate_deb.rb passenger ${PASSENGER_DEB_VERSION} binary '{"Suggests":"ruby"}'

RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/nginx-${NGINX_VERSION}.tar.gz &&\
    cd nginx-${NGINX_VERSION} &&\
    ./configure \
        --with-compat \
        --add-dynamic-module=$(passenger-config --nginx-addon-dir) &&\
    make modules
RUN current_state.sh before
RUN mkdir -p /usr/lib/nginx/modules
RUN mkdir -p /etc/nginx/modules-enabled
RUN cp /usr/local/build/nginx-${NGINX_VERSION}/objs/ngx_http_passenger_module.so /usr/lib/nginx/modules/ngx_http_passenger_module.so
RUN include_modules.rb
RUN current_state.sh after
RUN generate_deb.rb nginx-module-http-passenger ${NGINX_PASSENGER_MODULE_DEB_VERSION} binary "{\"Depends\":\"passenger (= ${PASSENGER_DEB_VERSION}), nginx (= ${NGINX_DEB_VERSION})\"}"

######################################################################################################################################################################################################################################

# FROM base AS passenger-enterprise
# ARG PASSENGER_VERSION
# ARG NGINX_VERSION
# ARG NGINX_DEB_VERSION
# ARG PASSENGER_DEB_VERSION
# ARG NGINX_PASSENGER_MODULE_DEB_VERSION
# WORKDIR /usr/local/build

# # NOTE: prerequisites for the apache module - compilation process installs everything, unfortunately
# RUN apt-get install -y apache2 apache2-dev

# COPY --from=openssl /usr/local/debs /usr/local/debs
# RUN dpkg -i /usr/local/debs/*.deb

# # NOTE: directory is called passenger-enterprise-${PASSENGER_VERSION}
# RUN wget https://github.com/phusion/passenger/archive/refs/tags/enterprise-${PASSENGER_VERSION}.tar.gz -P /usr/local/sources &&\
#     tar zxf /usr/local/sources/enterprise-${PASSENGER_VERSION}.tar.gz &&\
#     cd passenger-enterprise-${PASSENGER_VERSION} &&\
#     rake fakeroot

# RUN current_state.sh before
# RUN cp -a passenger-enterprise-${PASSENGER_VERSION}/pkg/fakeroot/* /
# RUN cd passenger-enterprise-${PASSENGER_VERSION} && setup_passenger.rb
# RUN current_state.sh after
# RUN generate_deb.rb passenger-enterprise ${PASSENGER_DEB_VERSION} binary

# RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -P /usr/local/sources &&\
#     tar zxf /usr/local/sources/nginx-${NGINX_VERSION}.tar.gz &&\
#     cd nginx-${NGINX_VERSION} &&\
#     ./configure \
#         --with-compat \
#         --add-dynamic-module=$(passenger-config --nginx-addon-dir) &&\
#     make modules
# RUN current_state.sh before
# RUN mkdir -p /usr/lib/nginx/modules
# RUN mkdir -p /etc/nginx/modules-enabled
# RUN cp /usr/local/build/nginx-${NGINX_VERSION}/objs/ngx_http_passenger_module.so /usr/lib/nginx/modules/ngx_http_passenger_module.so
# RUN include_modules.rb
# RUN current_state.sh after
# RUN generate_deb.rb nginx-module-http-passenger-enterprise ${NGINX_PASSENGER_MODULE_DEB_VERSION} binary "{\"Depends\":\"passenger-enterprise (= ${PASSENGER_DEB_VERSION}), nginx (= ${NGINX_DEB_VERSION})\"}"

######################################################################################################################################################################################################################################

FROM base AS nginx

ARG OPENSSL_VERSION
ARG ZLIB_VERSION
ARG NGINX_VERSION
ARG NGINX_DEB_VERSION
ARG LIBMAXMINDDB_VERSION
ARG MODSECURITY_VERSION
ARG PCRE_VERSION
ARG LUAJIT2_VERSION
ARG LUAJIT2_SHORT_VERSION
ARG LUA_RESTY_CORE_VERSION
ARG LUA_RESTY_LRUCACHE_VERSION

ARG MODSECURITY_MODULE_VERSION
ARG HEADERS_MORE_MODULE_VERSION
ARG HTTP_AUTH_PAM_MODULE_VERSION
ARG CACHE_PURGE_MODULE_VERSION
ARG DAV_EXT_MODULE_VERSION
ARG DEVEL_KIT_MODULE_VERSION
ARG ECHO_MODULE_VERSION
ARG FANCYINDEX_MODULE_VERSION
ARG NCHAN_MODULE_VERSION
ARG LUA_MODULE_VERSION
ARG RTMP_MODULE_VERSION
ARG UPLOAD_PROGRESS_MODULE_VERSION
ARG UPSTREAM_FAIR_MODULE_VERSION
ARG HTTP_SUBSTITUTIONS_FILTER_MODULE_VERSION
ARG HTTP_GEOIP2_MODULE_VERSION

WORKDIR /usr/local/build

COPY --from=openssl /usr/local/debs /usr/local/debs
COPY --from=pcre /usr/local/debs /usr/local/debs
COPY --from=zlib /usr/local/debs /usr/local/debs
COPY --from=modsecurity /usr/local/debs /usr/local/debs
COPY --from=luajit2 /usr/local/debs /usr/local/debs
COPY --from=lua-resty-core /usr/local/debs /usr/local/debs
COPY --from=lua-resty-lrucache /usr/local/debs /usr/local/debs
COPY --from=libmaxminddb /usr/local/debs /usr/local/debs
COPY --from=libgd /usr/local/debs /usr/local/debs
RUN dpkg -i /usr/local/debs/*.deb

# NOTE: required to use the new openssl version that is installed in the above debs
# TODO: when using a custom openssl directory, configuring passenger fails with -lcrypto fails and wasn't able to figure it out just yet (fixing custom include using CPATH worked, unlike with-cc-opt)
# ENV PATH="${PATH}:/usr/local/ssl/bin"
# ENV CPATH=/usr/local/ssl/include

# MODULE SOURCES
# directory name: modsecurity-nginx-v${MODSECURITY_MODULE_VERSION}
RUN wget https://github.com/SpiderLabs/ModSecurity-nginx/releases/download/v${MODSECURITY_MODULE_VERSION}/modsecurity-nginx-v${MODSECURITY_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/modsecurity-nginx-v${MODSECURITY_MODULE_VERSION}.tar.gz
# directory name: headers-more-nginx-module-${HEADERS_MORE_MODULE_VERSION}
RUN wget https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${HEADERS_MORE_MODULE_VERSION}.tar.gz
# directory name: ngx_http_auth_pam_module-${HTTP_AUTH_PAM_MODULE_VERSION}
RUN wget https://github.com/sto/ngx_http_auth_pam_module/archive/refs/tags/v${HTTP_AUTH_PAM_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${HTTP_AUTH_PAM_MODULE_VERSION}.tar.gz
# NOTE: original repository is FRiCKLE/ngx_cache_purge but it doesn't have dynamic configuration and repo maintainer suggests using this fork
# https://github.com/FRiCKLE/ngx_cache_purge/issues/63
# directory name: ngx_cache_purge-${CACHE_PURGE_MODULE_VERSION}
RUN wget https://github.com/nginx-modules/ngx_cache_purge/archive/refs/tags/${CACHE_PURGE_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/${CACHE_PURGE_MODULE_VERSION}.tar.gz
# directory name: nginx-dav-ext-module-${DAV_EXT_MODULE_VERSION}
RUN wget https://github.com/arut/nginx-dav-ext-module/archive/refs/tags/v${DAV_EXT_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${DAV_EXT_MODULE_VERSION}.tar.gz
# directory name: ngx_devel_kit-${DEVEL_KIT_MODULE_VERSION}
RUN wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v${DEVEL_KIT_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${DEVEL_KIT_MODULE_VERSION}.tar.gz
# directory name: echo-nginx-module-${ECHO_MODULE_VERSION}
RUN wget https://github.com/openresty/echo-nginx-module/archive/refs/tags/v${ECHO_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${ECHO_MODULE_VERSION}.tar.gz
# directory name: ngx-fancyindex-${FANCYINDEX_MODULE_VERSION}
RUN wget https://github.com/aperezdc/ngx-fancyindex/releases/download/v${FANCYINDEX_MODULE_VERSION}/ngx-fancyindex-${FANCYINDEX_MODULE_VERSION}.tar.xz -P /usr/local/sources && tar xf /usr/local/sources/ngx-fancyindex-${FANCYINDEX_MODULE_VERSION}.tar.xz
# directory name: nchan-${NCHAN_MODULE_VERSION}
RUN wget https://github.com/slact/nchan/archive/refs/tags/v${NCHAN_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${NCHAN_MODULE_VERSION}.tar.gz
# directory name: lua-nginx-module-${LUA_MODULE_VERSION}
RUN wget https://github.com/openresty/lua-nginx-module/archive/refs/tags/v${LUA_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${LUA_MODULE_VERSION}.tar.gz
# directory name: nginx-rtmp-module-${RTMP_MODULE_VERSION}
RUN wget https://github.com/arut/nginx-rtmp-module/archive/refs/tags/v${RTMP_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${RTMP_MODULE_VERSION}.tar.gz
# directory name: nginx-upload-progress-module-${UPLOAD_PROGRESS_MODULE_VERSION}
RUN wget https://github.com/masterzen/nginx-upload-progress-module/archive/refs/tags/v${UPLOAD_PROGRESS_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${UPLOAD_PROGRESS_MODULE_VERSION}.tar.gz
# directory name: nginx-upstream-fair-${UPSTREAM_FAIR_MODULE_VERSION}
RUN wget https://github.com/itoffshore/nginx-upstream-fair/archive/refs/tags/${UPSTREAM_FAIR_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/${UPSTREAM_FAIR_MODULE_VERSION}.tar.gz
# directory name: ngx_http_substitutions_filter_module-${HTTP_SUBSTITUTIONS_FILTER_MODULE_VERSION}
RUN wget https://github.com/yaoweibin/ngx_http_substitutions_filter_module/archive/refs/tags/v${HTTP_SUBSTITUTIONS_FILTER_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/v${HTTP_SUBSTITUTIONS_FILTER_MODULE_VERSION}.tar.gz
# directory name: ngx_http_geoip2_module-${HTTP_GEOIP2_MODULE_VERSION}
RUN wget https://github.com/leev/ngx_http_geoip2_module/archive/refs/tags/${HTTP_GEOIP2_MODULE_VERSION}.tar.gz -P /usr/local/sources && tar zxf /usr/local/sources/${HTTP_GEOIP2_MODULE_VERSION}.tar.gz

# INSTALL NGINX

RUN current_state.sh before

ENV LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_INC=/usr/local/include/luajit-${LUAJIT2_SHORT_VERSION}

# NOTE: original --with-cc-opt had -Wdate-time, but that throws an error for the NGINX rtmp module, so removing it: https://github.com/arut/nginx-rtmp-module/issues/1235
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -P /usr/local/sources &&\
    tar zxf /usr/local/sources/nginx-${NGINX_VERSION}.tar.gz &&\
    cd nginx-${NGINX_VERSION} &&\
    ./configure \
        --with-cc-opt='-g -O2 -fdebug-prefix-map=/build/nginx-${NGINX_VERSION}=. -fstack-protector-strong -Wformat -Werror=format-security -fPIC -D_FORTIFY_SOURCE=2' \
        --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -fPIC' \
        --prefix=/usr/share/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --lock-path=/var/lock/nginx.lock \
        --pid-path=/run/nginx.pid \
        --modules-path=/usr/lib/nginx/modules \
        --http-client-body-temp-path=/var/lib/nginx/body \
        --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
        --http-proxy-temp-path=/var/lib/nginx/proxy \
        --http-scgi-temp-path=/var/lib/nginx/scgi \
        --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
        --with-debug \
        --with-pcre-jit \
        --with-compat \
	--with-openssl=/usr/local/build/openssl-${OPENSSL_VERSION} \
        --with-pcre=/usr/local/build/pcre-${PCRE_VERSION} \
        --with-zlib=/usr/local/build/zlib-${ZLIB_VERSION} \
        --with-threads \
        --with-mail \
        --with-stream \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_realip_module \
        --with-http_auth_request_module \
        --with-http_v2_module \
        --with-http_dav_module \
        --with-http_slice_module \
        --with-http_addition_module \
        --with-http_flv_module \
        --with-http_geoip_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_image_filter_module \
        --with-http_mp4_module \
        --with-http_perl_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_sub_module \
        --with-http_xslt_module \
        --with-mail_ssl_module \
        --with-stream_geoip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --add-module=/usr/local/build/headers-more-nginx-module-${HEADERS_MORE_MODULE_VERSION} \
        --add-module=/usr/local/build/ngx_http_auth_pam_module-${HTTP_AUTH_PAM_MODULE_VERSION} \
        --add-module=/usr/local/build/ngx_cache_purge-${CACHE_PURGE_MODULE_VERSION} \
        --add-module=/usr/local/build/nginx-dav-ext-module-${DAV_EXT_MODULE_VERSION} \
        --add-module=/usr/local/build/ngx_devel_kit-${DEVEL_KIT_MODULE_VERSION} \
        --add-module=/usr/local/build/echo-nginx-module-${ECHO_MODULE_VERSION} \
        --add-module=/usr/local/build/ngx-fancyindex-${FANCYINDEX_MODULE_VERSION} \
        --add-module=/usr/local/build/nchan-${NCHAN_MODULE_VERSION} \
        --add-module=/usr/local/build/lua-nginx-module-${LUA_MODULE_VERSION} \
        --add-module=/usr/local/build/nginx-rtmp-module-${RTMP_MODULE_VERSION} \
        --add-module=/usr/local/build/nginx-upload-progress-module-${UPLOAD_PROGRESS_MODULE_VERSION} \
        --add-module=/usr/local/build/nginx-upstream-fair-${UPSTREAM_FAIR_MODULE_VERSION} \
        --add-module=/usr/local/build/ngx_http_substitutions_filter_module-${HTTP_SUBSTITUTIONS_FILTER_MODULE_VERSION} \
        --add-module=/usr/local/build/ngx_http_geoip2_module-${HTTP_GEOIP2_MODULE_VERSION} \
        --add-module=/usr/local/build/modsecurity-nginx-v${MODSECURITY_MODULE_VERSION} &&\
    make &&\
    make install

# make sure we have these as part of the deb
RUN mkdir -p /var/log/nginx
RUN mkdir -p /var/lib/nginx
RUN cp /usr/share/nginx/sbin/nginx /usr/sbin/nginx

# Required for NGINX to find the openresty library
RUN ln -s /usr/local/lib/lua/resty /usr/local/share/luajit-${LUAJIT2_VERSION}/resty

RUN current_state.sh after
RUN rm -rf /usr/local/debs/*
# NOTE: The general approach is that if the OS offers the package, then we should use the OS package (e.g. libmaxminddb/libpcre3/libgd3),
#       and package it ourselves if it doesn't and doesn't conflict with any package (e.g. modsecurity/openresty-lua-core).
RUN generate_deb.rb nginx ${NGINX_DEB_VERSION} binary '{"Depends":"libcurl4-openssl-dev, libgd3, libgeoip-dev, libmaxminddb-dev, libpcre3, libxml2-dev, libxslt-dev, modsecurity, openresty-lua-core, openresty-lua-lrucache, openresty-luajit"}'

FROM base AS prefinal

ARG MODSECURITY_DEB_VERSION
ARG LUAJIT2_DEB_VERSION
ARG LUA_RESTY_CORE_DEB_VERSION
ARG LUA_RESTY_LRUCACHE_DEB_VERSION
ARG NGINX_DEB_VERSION
ARG PASSENGER_DEB_VERSION
ARG NGINX_PASSENGER_MODULE_DEB_VERSION
ARG NGINX_VERSION
ARG PASSENGER_VERSION

COPY --from=modsecurity /usr/local/debs /usr/local/debs
COPY --from=luajit2 /usr/local/debs /usr/local/debs
COPY --from=lua-resty-core /usr/local/debs /usr/local/debs
COPY --from=lua-resty-lrucache /usr/local/debs /usr/local/debs
COPY --from=nginx /usr/local/debs /usr/local/debs
COPY --from=passenger /usr/local/debs /usr/local/debs
# COPY --from=passenger-enterprise /usr/local/debs /usr/local/debs

RUN mkdir -p /usr/local/debs/cloud66-nginx-${NGINX_VERSION}
RUN mkdir -p /usr/local/debs/cloud66-nginx-${NGINX_VERSION}/prerequisites
RUN mkdir -p /usr/local/debs/cloud66-nginx-${NGINX_VERSION}/nginx

RUN mv /usr/local/debs/modsecurity_${MODSECURITY_DEB_VERSION}_amd64.deb \
       /usr/local/debs/openresty-luajit_${LUAJIT2_DEB_VERSION}_amd64.deb \
       /usr/local/debs/openresty-lua-core_${LUA_RESTY_CORE_DEB_VERSION}_amd64.deb \
       /usr/local/debs/openresty-lua-lrucache_${LUA_RESTY_LRUCACHE_DEB_VERSION}_amd64.deb \
       /usr/local/debs/cloud66-nginx-${NGINX_VERSION}/prerequisites
RUN mv /usr/local/debs/nginx_${NGINX_DEB_VERSION}_amd64.deb /usr/local/debs/cloud66-nginx-${NGINX_VERSION}/nginx

RUN mkdir -p /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-${PASSENGER_VERSION}/passenger
RUN mkdir -p /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-${PASSENGER_VERSION}/passenger-module
RUN mv /usr/local/debs/passenger_${PASSENGER_DEB_VERSION}_amd64.deb /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-${PASSENGER_VERSION}/passenger
RUN mv /usr/local/debs/nginx-module-http-passenger_${NGINX_PASSENGER_MODULE_DEB_VERSION}_amd64.deb /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-${PASSENGER_VERSION}/passenger-module

# RUN mkdir -p /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-enterprise-${PASSENGER_VERSION}/passenger-enterprise
# RUN mkdir -p /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-enterprise-${PASSENGER_VERSION}/passenger-enterprise-module
# RUN mv /usr/local/debs/passenger-enterprise_${PASSENGER_DEB_VERSION}_amd64.deb /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-enterprise-${PASSENGER_VERSION}/passenger-enterprise
# RUN mv /usr/local/debs/nginx-module-http-passenger-enterprise_${NGINX_PASSENGER_MODULE_DEB_VERSION}_amd64.deb /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-enterprise-${PASSENGER_VERSION}/passenger-enterprise-module

RUN tar -czf /nginx.tar.gz /usr/local/debs/cloud66-nginx-${NGINX_VERSION}/prerequisites /usr/local/debs/cloud66-nginx-${NGINX_VERSION}/nginx
RUN tar -czf /passenger.tar.gz /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-${PASSENGER_VERSION}
# RUN tar -czf /passenger-enterprise.tar.gz /usr/local/debs/cloud66-nginx-${NGINX_VERSION}-passenger-enterprise-${PASSENGER_VERSION}

FROM ubuntu:$OPERATING_SYSTEM_VERSION AS test
ARG NGINX_VERSION
ARG PASSENGER_VERSION

# NOTE: not testing passenger-enterprise because it requires a valid license
COPY --from=prefinal /nginx.tar.gz /nginx.tar.gz
COPY --from=prefinal /passenger.tar.gz /passenger.tar.gz

RUN tar -C / -zxvf nginx.tar.gz
RUN tar -C / -zxvf passenger.tar.gz

# NOTE: dpkg doesn't respect dependencies if you just give it a list of all packages to install, but apt does
RUN apt update && apt install -y /usr/local/debs/**/**/*.deb

# NOTE: curl is a requirement for test_nginx.sh and ruby is a requirement for Passenger
RUN apt-get update && apt-get install -y curl ruby

ADD test_nginx.sh /usr/local/bin
ADD test_nginx.conf /etc/nginx/nginx.conf
RUN test_nginx.sh
RUN touch /tmp/test_successful

FROM prefinal AS final
# NOTE: make test as dependency before this final image builds
COPY --from=test /tmp/test_successful /tmp/test_successful