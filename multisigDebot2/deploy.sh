#!/bin/bash
set -e
filename=msigDebotv2
filenameabi=$filename.abi.json
filenametvc=$filename.tvc
filenamekeys=$filename.keys.json

TONOS_CLI=~/Downloads/tonos-cli
NET_GIVER_PATH=~/givers/net_giver

#$TONOS_CLI config --url https://localhost/

function giver_net {
$TONOS_CLI call 0:2bb4a0e8391e7ea8877f4825064924bd41ce110fce97e939d3323999e1efbb13 sendTransaction "{\"dest\":\"$1\",\"value\":10000000000,\"bounce\":\"false\"}" --abi $NET_GIVER_PATH/giver.abi.json --sign $NET_GIVER_PATH/keys.json
}
function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

echo ""
echo "[DEBOT]"
echo ""
echo GENADDR DEBOT
$TONOS_CLI genaddr $filenametvc --genkey $filenamekeys > log.log
debot_address=$(get_address)
echo $debot_address
echo GIVER
giver_net $debot_address
echo DEPLOY DEBOT
debot_abi=$(cat $filename.abi.json | jq -c '.' | xxd -ps -c 200000)
$TONOS_CLI deploy $filenametvc "{}" --sign $filenamekeys --abi $filenameabi
echo SET DEBOT ABI
$TONOS_CLI call $debot_address setABIBytes "{\"dabi\":\"$debot_abi\"}" --sign $filenamekeys --abi $filenameabi
echo DONE
echo $debot_address > address.log
