#!/bin/bash
#run from repo root
docker run --network host -v $PWD:/app -e'FOUNDRY_ETH_RPC_URL=$1'  foundry "forge test --root /app --watch"
