#!/usr/bin/env bash
set -euo pipefail

# Default directory containing the configuration files
SHARE_DIR=${SHARE_DIR:-$(dirname "${BASH_SOURCE[0]}")}

# Default work directory
CACHE_ADDR=${CACHE_ADDR:-[::]:8080}
CACHE_DIR=${CACHE_DIR:-"${PWD}/data"}
CACHE_SIZE=${CACHE_SIZE:-10g}
UPSTREAM=${UPSTREAM:-"https://cache.nixos.org"}
SCHEME=${SCHEME:-"http"}
STATS_PATH=${STATS_PATH:-"/status"}
STATS_ENABLED=${STATS_ENABLED:-"0"}

NGINX_CONF_PATH=${CACHE_DIR}/nginx.conf
INDEX_HTML_PATH=${CACHE_DIR}/index.html
NGINX_SERVER_NAME=${NGINX_SERVER_NAME:-"localhost"}
LAN_MODE=${LAN_MODE:-"0"}

# Create required directories
mkdir -p "${CACHE_DIR}"

# In LAN mode, prefer .local mDNS hostname if no domain is present
if [ "${LAN_MODE}" = "1" ]; then
  case "${NGINX_SERVER_NAME}" in
    *.*) : ;; # already has a dot/domain, leave as-is
    *.local) : ;; # already .local
    *) NGINX_SERVER_NAME="${NGINX_SERVER_NAME}.local" ;;
  esac
fi

# Render index.html from template
render_stats_section() {
  if [ "${STATS_ENABLED}" = "1" ]; then
    cat <<'HTML'
<p>Stats: <a href="@SCHEME@://@HOSTNAME@@STATS_PATH@">@STATS_PATH@</a></p>
HTML
  else
    echo ""
  fi
}

# Escape for sed replacement
sed_escape() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g' -e $'s/\n/\\n/g'; }

STATS_SECTION_RAW="$(render_stats_section)"
STATS_SECTION_ESCAPED="$(sed_escape "${STATS_SECTION_RAW}")"

sed \
    -e "s|@HOSTNAME@|${NGINX_SERVER_NAME}|g" \
    -e "s|@UPSTREAM@|${UPSTREAM}|g" \
    -e "s|@SCHEME@|${SCHEME}|g" \
    -e "s|@STATS_PATH@|${STATS_PATH}|g" \
    -e "s|@STATS_SECTION@|${STATS_SECTION_ESCAPED}|g" \
    "$SHARE_DIR/index.html.template" > "${INDEX_HTML_PATH}"

# Process the nginx.conf template using sed
# Derive upstream host (strip scheme and path)
UPSTREAM_HOST=$(printf '%s' "$UPSTREAM" | sed -E 's,^[a-zA-Z0-9+.-]+://,,' | cut -d/ -f1)
sed \
    -e "s|@NGINX_SERVER_NAME@|${NGINX_SERVER_NAME}|g" \
    -e "s|@CACHE_ADDR@|${CACHE_ADDR}|g" \
    -e "s|@CACHE_SIZE@|${CACHE_SIZE}|g" \
    -e "s|@CACHE_DIR@|${CACHE_DIR}|g" \
    -e "s|@UPSTREAM@|${UPSTREAM}|g" \
    -e "s|@UPSTREAM_HOST@|${UPSTREAM_HOST}|g" \
    -e "s|@INDEX_HTML_PATH@|${INDEX_HTML_PATH}|g" \
    -e "s|@SHARE_DIR@|${SHARE_DIR}|g" \
    "$SHARE_DIR/nginx.conf.template" > "${NGINX_CONF_PATH}"

# Validate the configuration
nginx -t -c "${NGINX_CONF_PATH}"

# Start nginx in the foreground
exec nginx -g "daemon off;" -c "${NGINX_CONF_PATH}" "$@"
