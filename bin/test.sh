#!/bin/bash
set -eu

run() {
    echo >&2 "+ $*"
    "$@"
}

check() {
    name="$1"
    echo "========================================"
    echo "Checking $name..."

    "check_$name" && ret=$? || ret=$?
    if [ $ret -eq 0 ]; then
        echo "OK: $name check"
    else
        echo "ERROR: $name check failed"
    fi
}

check_os() {
    uname="$(uname)"
    case "$uname" in
        Linux|Darwin)
            ;;
        *)
            echo "WARNING: not tested on $uname"
            return 1
            ;;
    esac
}

check_ip() {
  run curl -4 --write-out "\n" ifconfig.co/json 
}

dig_short() {
    output="$(dig +short "$@")"
    if [ -z "$output" ]; then
        echo >&2 "Error: command returned no output: dig +short $*"
        return 1
    fi
    echo "$output"
}

check_dns() {
    stripe_ns="$(dig_short -t ns stripe.com)"
    stripe_first_ns="$(head -1 <<< "$stripe_ns")"
    api_addresses="$(dig_short -t a api.stripe.com "@$stripe_first_ns")"

    from_local="$(gethostbyname api.stripe.com)"

    echo "api.stripe.com IP: $from_local"
    echo "api.stripe.com nameservers: $stripe_ns"
    if ! grep -x "$from_local" <<< "$api_addresses" >/dev/null; then
        echo "Error: mismatch between resolved api.stripe.com addresses"
        echo "gethostbyname: $from_local"
        echo "DIG: $api_addresses"
        return 2
    fi
}

check_ping() {
    run ping -c 10 api.stripe.com
}

check_route() {
    if command -v mtr 2>/dev/null; then
        run mtr -n --report api.stripe.com
    elif command -v traceroute 2>/dev/null; then
        run traceroute -n -m 20 api.stripe.com
    fi
}

check_curl_http() {
    run curl -Iv http://api.stripe.com/healthcheck
}
check_curl_https() {
    run curl -Iv https://api.stripe.com/healthcheck
}

gethostbyname() {
    run python -c "import socket; print socket.gethostbyname('$1')"
}

auto_test_all() {
    check os
    check ip
    check dns
    check ping
    check route
    check curl_http
    check curl_https
}

auto_test_all
