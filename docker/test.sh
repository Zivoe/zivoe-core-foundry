#!/bin/bash
#run from repo root
docker run --network host -v $PWD:/app  foundry "forge test --root /app --watch"
