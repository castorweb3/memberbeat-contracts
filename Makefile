-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil install deploy deploy-sepolia verify

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/Cyfrin/foundry-devops@0.2.3 --no-commit && forge install foundry-rs/forge-std@v1.9.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v5.1.0 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts --no-commit && forge install rollaProject/solidity-datetime@v2.2.0 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:	
	@forge script script script/DeploySubscriptionManager.s.sol --rpc-url=http://localhost:8545 --account defaultKey --broadcast -vvvv

deploy-sepolia:
	@forge script script script/DeploySubscriptionManager.s.sol --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast --verify
