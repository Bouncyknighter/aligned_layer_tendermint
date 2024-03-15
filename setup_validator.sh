#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage: $0 <node_name> <staking_amount>"
	exit 1
fi

VALIDATOR=$1
STAKING_AMOUNT=$2

NODE_HOME=$HOME/.alignedlayer
CHAIN_BINARY=alignedlayerd
CHAIN_ID=alignedlayer
PEER_ADDR=blockchain-1
FAUCET_ADDR=blockchain-1:8088
TOKEN=stake

git clone https://github.com/yetanotherco/aligned_layer_tendermint.git
cd aligned_layer_tendermint
ignite chain build 

$CHAIN_BINARY init $VALIDATOR --chain-id $CHAIN_ID --overwrite

curl $PEER_ADDR:26657/genesis | jq '.result.genesis' > $NODE_HOME/config/genesis.json
NODEID=$(curl -s $PEER_ADDR:26657/status | jq -r '.result.node_info.id')

$CHAIN_BINARY config set config p2p.seeds "$NODEID@$PEER_ADDR:26656" --skip-validate
$CHAIN_BINARY config set config p2p.persistent_peers "$NODEID@$PEER_ADDR:26656" --skip-validate
$CHAIN_BINARY config set app minimum-gas-prices 0.25$TOKEN --skip-validate

$CHAIN_BINARY keys add $VALIDATOR
NODE_ADDR=$($CHAIN_BINARY keys show $VALIDATOR --output json | jq -r .address)
VALIDATOR_KEY=$($CHAIN_BINARY tendermint show-validator)

cat << EOF > $NODE_HOME/config/validator.json
{
	"pubkey": '$VALIDATOR_KEY',
	"amount": "'$STAKING_AMOUNT$TOKEN'",
	"moniker": "'$VALIDATOR'",
	"commission-rate": "0.1",
	"commission-max-rate": "0.2",
	"commission-max-change-rate": "0.01",
	"min-self-delegation": "1"
}
EOF

curl $FAUCET_ADDR/send/alignedlayer/$NODE_ADDR

$CHAIN_BINARY tx staking create-validator $NODE_HOME/config/validator.json --from $NODE_ADDR --node tcp://$PEER_ADDR:26657 --fees 20000$TOKEN --chain-id $CHAIN_ID

$CHAIN_BINARY start
