-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil install deploy deploy-sepolia deploy-arbitrum-sepolia verify

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install Cyfrin/foundry-devops@0.2.3 --no-commit && forge install foundry-rs/forge-std@v1.9.3 --no-commit && forge install openzeppelin/openzeppelin-contracts@v5.1.0 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.2.0 --no-commit && forge install rollaProject/solidity-datetime@v2.2.0 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:	
	@forge script script/DeploySubscriptionManager.s.sol --rpc-url=http://127.0.0.1:8545 --account defaultKey --broadcast -vvvv

mint-tokens:
	@forge script script/MockTokenMinter.sol --rpc-url http://127.0.0.1:8545 --account defaultKey --broadcast -vvvv

transfer-eth:
	@forge script script/TransferEth.sol --rpc-url http://127.0.0.1:8545 --account defaultKey --broadcast -vvvv

deploy-sepolia:
	@forge script script/DeploySubscriptionManager.s.sol --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast --verify

deploy-arbitrum-sepolia:
	@forge script script/DeploySubscriptionManager.s.sol --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --account $(ACCOUNT) --etherscan-api-key $(ARBISCAN_API_KEY) --broadcast --verify -vvvv

deploy-optimism-sepolia:
	@forge script script/DeploySubscriptionManager.s.sol --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --account $(ACCOUNT) --etherscan-api-key $(OPTIMISM_ETHERSCAN_API_KEY) --broadcast --verify -vvvv