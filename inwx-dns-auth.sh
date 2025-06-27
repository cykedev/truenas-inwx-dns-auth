#!/bin/bash

# === Configuration ===
INWX_USERNAME="YOUR_INWX_USERNAME"
INWX_PASSWORD="YOUR_INWX_PASSWORD"
INWX_API="https://api.domrobot.com/jsonrpc/"
COOKIE_FILE="/tmp/inwx_cookie_$$.txt"
LOG_FILE="/tmp/inwx-acme.log"
ENABLE_LOGGING=true

# === Logging Function ===
log() {
    if [[ "$ENABLE_LOGGING" == true ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    fi
}

# === Login to INWX API and store session cookie ===
inwx_login() {
    RESPONSE=$(curl -s -X POST "$INWX_API" \
        -H "Content-Type: application/json" \
        -d "{\"method\":\"account.login\",\"params\":{\"user\":\"$INWX_USERNAME\",\"pass\":\"$INWX_PASSWORD\"}}" \
        -c "$COOKIE_FILE")

    if [[ $(echo "$RESPONSE" | jq -r '.code') -ne 1000 ]]; then
        log "INWX login failed: $RESPONSE"
        exit 1
    fi
    log "Login successful"
}

# === Wait until the TXT record is publicly visible via DNS ===
wait_for_dns() {
    local fqdn=$1
    local expected_value=$2
    local waited=0
    local timeout=180

    log "Waiting for DNS TXT $fqdn = $expected_value"
    while [[ $waited -lt $timeout ]]; do
        result=$(dig +short TXT "$fqdn" | tr -d '"')
        if [[ "$result" == "$expected_value" ]]; then
            log "DNS propagated: $result"
            return 0
        fi
        sleep 5
        ((waited+=5))
    done
    log "Timeout waiting for DNS propagation"
    return 1
}

# === Create a new TXT record at INWX ===
create_dns_record() {
    local full_domain=$1
    local value=$2
    local domain=$(echo "$full_domain" | awk -F. '{print $(NF-1)"."$NF}')
    local name=${full_domain%.$domain}

    log "Creating TXT record: name=$name domain=$domain value=$value"

    RESPONSE=$(curl -s -X POST "$INWX_API" \
        -H "Content-Type: application/json" \
        -d "{
            \"method\": \"nameserver.createRecord\",
            \"params\": {
                \"domain\": \"$domain\",
                \"name\": \"$name\",
                \"type\": \"TXT\",
                \"content\": \"$value\",
                \"ttl\": 300,
                \"prio\": 0
            }
        }" -b "$COOKIE_FILE")

    log "Create response: $RESPONSE"
    wait_for_dns "$full_domain" "$value"
}

# === Delete the matching TXT record after validation ===
delete_dns_record() {
    local full_domain=$1
    local value=$2
    local domain=$(echo "$full_domain" | awk -F. '{print $(NF-1)"."$NF}')

    log "Deleting TXT record: name=$full_domain domain=$domain value=$value"

    RESPONSE=$(curl -s -X POST "$INWX_API" \
        -H "Content-Type: application/json" \
        -d "{\"method\":\"nameserver.info\",\"params\":{\"domain\":\"$domain\"}}" \
        -b "$COOKIE_FILE")

    log "All TXT records:"
    echo "$RESPONSE" | jq -r '.resData.record[] | select(.type == "TXT") | "\(.id) \(.name) = \(.content)"' >> "$LOG_FILE"

    local clean_value=$(echo "$value" | tr -d '"' | xargs)

    ID=$(echo "$RESPONSE" | jq -r --arg name "$full_domain" --arg value "$clean_value" '
        .resData.record[] |
        select(.name == $name and .type == "TXT" and (.content | gsub("\"";"") | gsub(" "; "") == $value)) |
        .id')

    if [[ -n "$ID" && "$ID" != "null" ]]; then
        DEL=$(curl -s -X POST "$INWX_API" \
            -H "Content-Type: application/json" \
            -d "{\"method\":\"nameserver.deleteRecord\",\"params\":{\"id\":\"$ID\"}}" \
            -b "$COOKIE_FILE")
        log "Delete response: $DEL"
    else
        log "Record not found for deletion (name match = $full_domain)"
    fi
}

# === Entry Point: ACME + TrueNAS compatible ===
inwx_login

case "$1" in
    deploy_challenge)
        create_dns_record "$3" "$4"
        ;;
    clean_challenge)
        delete_dns_record "$3" "$4"
        ;;
    set)
        create_dns_record "$3" "$4"
        ;;
    unset)
        delete_dns_record "$3" "$4"
        ;;
    *)
        log "Unknown hook: $1"
        exit 1
        ;;
esac

rm -f "$COOKIE_FILE"
