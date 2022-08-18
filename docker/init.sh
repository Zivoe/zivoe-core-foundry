#!/bin/bash
docker pull ghcr.io/foundry-rs/foundry:latest 
docker tag ghcr.io/foundry-rs/foundry:latest foundry:latest
git submodule init
git submodule update
cd lib/forge-std
git submodule init
git submodule update
