scripts to run docker containerized test, and alter deploy environments


run them from the root directory of the repo 


init.sh does the submodules for the repo and gets the docker image(s), 

the can run:

build.sh - just builds, 

test.sh just runs tests with no rpc

test_w_rpc.sh - runs tests expecting working foundation rpc at localhost 8545

chain.sh - gets aprity docker container going and syncing

