#!/bin/bash
#run from repo root
export `grep ^RPC .env`
docker run --network host -v $PWD:/app  foundry "forge test --root /app --watch --rpc-url $RPC"
