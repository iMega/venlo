#!/usr/bin/env bash

#
# $1 name container
#
checkConnectToData() {
    DATA_IP=$(docker inspect --format '{{ index (index .Config.Env) 0 }}' $1)
    IFS='=' read -ra IP <<< "$DATA_IP"
    if [ "$TELEPORT_DATA_IP" != "${IP[1]}" ]; then
        docker stop $1
        docker rm -fv $1
        make $1 -I `pwd`/../../
    fi
}

TELEPORT_DATA_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' teleport_data)

checkConnectToData teleport_inviter
checkConnectToData teleport_acceptor
checkConnectToData teleport_settings
