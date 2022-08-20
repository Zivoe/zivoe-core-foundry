#!/bin/bash
#run from repo root
export `grep .env ^RPC`||export RPC=$1
docker run --network host -v $PWD:/app -e'FOUNDRY_ETH_RPC_URL=$RPC'  foundry "forge test --root /app --watch"
