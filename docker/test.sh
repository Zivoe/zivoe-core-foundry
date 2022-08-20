#!/bin/bash
#run from repo root
docker run --rm --network host -v $PWD:/app  foundry "forge test --root /app --watch"
