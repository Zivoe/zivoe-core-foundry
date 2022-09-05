#!/bin/bash
docker run -it -v $PWD:/home/ethsec/`pwd|sed 's/^.*\///g'` trailofbits/eth-security-toolbox 
