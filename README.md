# The Atomic Swap Protocol for Native Coins on Two ETH-based chains

Suppose Alice want to use X ETH to exchange Y KETH from Bob. They mutually agree on this rate. Suppose we have the contracts running on ETH chain and the KETH chain with names ```ETHcontract``` and ```KETHcontract```, respectively.

The steps for calling the contracts are as follows:

1. *BOTH:* They first agree on an expiring time ```T1``` (the amount of time till this amount of money expires), sufficiently far away from now. Bob sets ```T2 = T1/2```



2.  *Alice:* Alice generate a random secrete R of type bytes32, she creates a secret

    *   ``` _hashedSecret = ripemd160(R)```
    *   Alice can use her secret key to sign a crypto nonce (e.g. the transaction) as the secrete R

    *  as a sanity check step, Alice should check  ```_hashedSecret``` has not been used before in ```swaps``` of the ```ETHcontract```


3. *Alice:* Alice calls the initiate function on the ETH chain by sending X ETH

    *   ```ETHcontract.initiate(T1, _hashedSecret, Bob.ETHaddress)```



4. *Alice:* Alice then send the ```_hashedSecret``` to Bob through a communication channel



5. *Bob:* Upon receiving ```_hashedSecret```, Bob also checks whether the state of ```swaps[_hashedSecret]``` of ```ETHcontract``` has status Initiator and has all the correct parameters. If true, Bob calls the ```initiate``` function on the KETH chain by sending Y KETH

    *   ```KETHcontract.initiate(T2, _hashedSecret, Alice.KETHaddress)```



6. *Alice:* Alice then receives the ```Initiated``` event. She first checks whether ```swaps[_hashedSecret].value == Y``` in the ```KETHcontract```. If so, she can redeem the KETH on the KETH chain:

    *   ```KETHcontract .redeem(R, _hashedSecret)```



7. *Bob:* Bob then receives the ```Redeemed``` event on the KETH chain. He can obtain the secret from ```swaps[_hashedSecret].secret```



8. *Bob:* Bob can then redeem the ETH from the ETH chain by running

    *   ```ETHcontract.Redeem(R, _hashedSecret)```

If any of the conditions fail to satisfy, then either Alice or Bob fail to cooperate. They can simply do nothing but wait for the contact to expire. After expiring, the corresponding person can call “refund” function on the corresponding contract to get their money back.


# The Atomic Swap Protocol for ERC20 and ERC721 Token

The process of swapping ERC20 and ERC721 token are similar to swap native tokens. To initiate the swap, the initiator just need to first call the token contract to approve the swap contract the corresponding amount of tokens.

```
ERC20/721Token.approve(ETHContract.address, value)
```

Then the swap initiator/participator use the initiateERC20/initiateERC721 function to start the swap contract.

```
initiateERC20/initiateERC721(uint _refundTime,      // in seconds. The amount of time till this swap expires
                            bytes20 _hashedSecret, 
                            address _participant, 
                            address _tokenAddress,  // the contract address of the token
                            uint256 _value          // the amount of value or tokenId to be swapped
                            )
```

The rest of the protocol is the same as the native coins.
