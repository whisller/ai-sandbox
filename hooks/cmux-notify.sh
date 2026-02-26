#!/bin/bash
set -euo pipefail

PAYLOAD="$(cat)"
TITLE="$(printf '%s' "$PAYLOAD" | jq -r '.title // "Claude"')"
MESSAGE="$(printf '%s' "$PAYLOAD" | jq -r '.message // "Task complete"')"

# Sanitize: strip control characters that could break OSC sequences
TITLE="$(printf '%s' "$TITLE" | tr -d '\000-\037\177')"
MESSAGE="$(printf '%s' "$MESSAGE" | tr -d '\000-\037\177')"
TITLE="${TITLE:0:80}"
MESSAGE="${MESSAGE:0:200}"

send_via_socket() {
    [ -z "${CMUX_SOCKET_PATH:-}" ] && return 1
    [ ! -S "$CMUX_SOCKET_PATH" ]   && return 1
    command -v socat >/dev/null 2>&1 || return 1

    local json
    json="$(python3 -c "
import json, sys
payload = {
    'id': '1',
    'method': 'notification.create',
    'params': {'title': sys.argv[1], 'body': sys.argv[2]}
}
if '${CMUX_TAB_ID:-}':
    payload['params']['tabId'] = '${CMUX_TAB_ID:-}'
print(json.dumps(payload))
" "$TITLE" "$MESSAGE" 2>/dev/null)" || return 1

    printf '%s\n' "$json" | socat -t 2 - "UNIX-CONNECT:${CMUX_SOCKET_PATH}" >/dev/null 2>&1
}

send_via_osc777() {
    [ -t 1 ] || [ -e /dev/tty ] || return 1
    printf '\e]777;notify;%s;%s\a' "$TITLE" "$MESSAGE" > /dev/tty 2>/dev/null
}

send_via_socket && exit 0
send_via_osc777 && exit 0
exit 0
