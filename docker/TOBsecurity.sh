#!/bin/bash
export REPO=`pwd|sed 's/^.*\///g'`
docker run --rm -it -w /home/ethsec/$REPO -v $PWD:/home/ethsec/$REPO trailofbits/eth-security-toolbox $1
