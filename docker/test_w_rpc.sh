#!/bin/bash
#run from repo root
export RPC=http://127.0.0.1:8545
docker run --network host -v $PWD:/app -e'FOUNDRY_ETH_RPC_URL=$RPC'  foundry "forge test --root /app --watch"
