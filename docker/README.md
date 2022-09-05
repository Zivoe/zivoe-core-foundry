scripts to run docker containerized test, and alter deploy environments


run them from the root directory of the repo 


``init.sh`` does the submodules for the repo and gets the docker image(s), 
the can run:
``build.sh`` - just builds, 
``test.sh`` just runs tests with no rpc
``test_w_rpc.sh`` - runs tests expecting working foundation rpc at localhost 8545
``chain.sh`` - gets parity docker container going and syncing
``TOBsecurity.sh`` - run trail of bits sec docker with 'all teh toolz'
``slither.sh`` - run slither default mode on a single file and suppress most of the more useless messages



example .env put it in the root directory:
```
RPC=https://mainnet.infura.io/v3/xxxxxxxxxxxxxxxxxxxxxxxxxx
```
