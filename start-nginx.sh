#!/usr/bin/env bash
set -euo pipefail

# Default directory containing the configuration files
SHARE_DIR=${SHARE_DIR:-$(dirname "${BASH_SOURCE[0]}")}

# Default work directory
CACHE_ADDR=${CACHE_ADDR:-[::]:8080}
CACHE_DIR=${CACHE_DIR:-"${PWD}/data"}
CACHE_SIZE=${CACHE_SIZE:-10g}

NGINX_CONF_PATH=${CACHE_DIR}/nginx.conf
NGINX_SERVER_NAME=${NGINX_SERVER_NAME:-"localhost"}

# Create required directories
mkdir -p "${CACHE_DIR}"

# Process the nginx.conf template using sed
sed \
    -e "s|@NGINX_SERVER_NAME@|${NGINX_SERVER_NAME}|g" \
    -e "s|@CACHE_ADDR@|${CACHE_ADDR}|g" \
    -e "s|@CACHE_SIZE@|${CACHE_SIZE}|g" \
    -e "s|@CACHE_DIR@|${CACHE_DIR}|g" \
    -e "s|@SHARE_DIR@|${SHARE_DIR}|g" \
    "$SHARE_DIR/nginx.conf.template" > "${NGINX_CONF_PATH}"

# Validate the configuration
nginx -t -c "${NGINX_CONF_PATH}"

# Start nginx in the foreground
exec nginx -g "daemon off;" -c "${NGINX_CONF_PATH}" "$@"
