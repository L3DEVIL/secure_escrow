# SecureEscrow Smart Contract

The **SecureEscrow** smart contract is a Solidity-based escrow system designed to facilitate secure transactions between buyers and sellers. It manages trade processes including the creation of trades, collateral deposits, approvals, and fund releases. The contract includes mechanisms to ensure that funds are safely held until both parties agree on the trade's completion. The escrow agent, who controls certain actions like fee collection and fund release, plays a central role in maintaining trust. Security features like non-reentrancy and access control protect the contract from potential attacks, ensuring a reliable and transparent transaction process.

## Features

- **Trade Management:** Secure creation and tracking of trades between buyers and sellers.
- **Collateral Handling:** Collateral deposits are required from sellers to ensure commitment.
- **Approval System:** Both buyer and seller must approve the trade for the release of funds.
- **Escrow Control:** An escrow agent oversees the trade, collecting fees and managing fund releases.
- **Security:** The contract includes non-reentrancy and access control mechanisms to prevent attacks.

## Contract Structure

- `createTrade`: Allows a buyer to create a new trade by specifying a seller and the trade amount.
- `depositCollateral`: Sellers deposit collateral, which is held until the trade is complete.
- `approve`: Both parties must approve the trade for the funds to be released.
- `releaseFunds`: Internal function that releases the funds to the seller once both parties have approved.
- `refundBuyer`: Allows the buyer to reclaim funds if the trade is not completed.
- `directRelease`: The escrow agent can directly release funds in special circumstances.
- `redeemFees`: The escrow agent can collect accumulated fees.
- `setEscrowAgent`: Change the escrow agent in charge of the contract.
- `setFeePercentage`: Update the fee percentage charged on each trade.
- `setPaused`: Pause or unpause the contract in case of emergency.

## How to Use

### Deploying the Contract

1. Compile the `SecureEscrow` contract using Solidity compiler version `^0.8.6`.
2. Deploy the contract on your preferred Ethereum-compatible blockchain.

### Interacting with Web3.js

```javascript

// using web3.js libary for connecting and interact with the SecureEscrow Smart contract 

const {Web3} = require('web3');
const contractABI = [/* ABI goes here */];
const contractAddress = 'YOUR_CONTRACT_ADDRESS';
const web3 = new Web3('YOUR_INFURA_OR_ALCHEMY_ENDPOINT');

const secureEscrow = new web3.eth.Contract(contractABI, contractAddress);
```

```javascript
// Creating a new trade and sign it using buyer private key 

async function createTrade(sellerAddress, amount, buyerPrivateKey) {
    const buyerAddress = web3.eth.accounts.privateKeyToAccount(buyerPrivateKey).address;

    // Create transaction object
    const tx = {
        from: buyerAddress,
        to: contractAddress,
        gas: 2000000,
        data: secureEscrow.methods.createTrade(sellerAddress).encodeABI(),
        value: web3.utils.toWei(amount, 'ether') // Convert amount to Wei
    };

    // Sign the transaction
    const signedTx = await web3.eth.accounts.signTransaction(tx, buyerPrivateKey);

    // Send the transaction
    web3.eth.sendSignedTransaction(signedTx.rawTransaction)
        .on('receipt', console.log)
        .on('error', console.error);
}
```


```javascript
// Deposit Collateral: Need the trade ID and the seller’s private key. The seller will sign the transaction:

async function depositCollateral(tradeID, collateralAmount, sellerPrivateKey, preApprove) {
    const sellerAddress = web3.eth.accounts.privateKeyToAccount(sellerPrivateKey).address;

    // Create transaction object
    const tx = {
        from: sellerAddress,
        to: contractAddress,
        gas: 2000000,
        data: secureEscrow.methods.depositCollateral(tradeID, preApprove).encodeABI(),
        value: web3.utils.toWei(collateralAmount, 'ether') // Convert collateral amount to Wei
    };

    // Sign the transaction
    const signedTx = await web3.eth.accounts.signTransaction(tx, sellerPrivateKey);

    // Send the transaction
    web3.eth.sendSignedTransaction(signedTx.rawTransaction)
        .on('receipt', console.log)
        .on('error', console.error);
}
```

```javascript
//Approve a Trade: Need the trade ID, the approver's private key, and a flag indicating if the approver is the buyer or seller
async function approveTrade(tradeID, approverPrivateKey) {
    const approverAddress = web3.eth.accounts.privateKeyToAccount(approverPrivateKey).address;

    // Create transaction object
    const tx = {
        from: approverAddress,
        to: contractAddress,
        gas: 2000000,
        data: contract.methods.approve(tradeID).encodeABI()
    };

    // Sign the transaction
    const signedTx = await web3.eth.accounts.signTransaction(tx, approverPrivateKey);

    // Send the transaction
    web3.eth.sendSignedTransaction(signedTx.rawTransaction)
        .on('receipt', console.log)
        .on('error', console.error);
}
```
