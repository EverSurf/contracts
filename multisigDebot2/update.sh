#!/bin/bash
set -e

debot_name=msigDebotv2
TONOS_CLI=~/Downloads/tonos-cli

debot=$(cat address.log)
debot_abi=$(cat $debot_name.abi.json | jq -c '.' | xxd -ps -c 200000)
new_state=$( base64 $debot_name.tvc)

$TONOS_CLI call $debot upgrade "{\"state\":\"$new_state\"}" --sign $debot_name.keys.json --abi $debot_name.abi.json
$TONOS_CLI call $debot setABIBytes "{\"dabi\":\"$debot_abi\"}" --sign $debot_name.keys.json --abi $debot_name.abi.json

echo DONE
