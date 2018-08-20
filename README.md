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


# 中文版例子
我们现在考虑Alice想用5ETH兑换Bob的200 EOS例子。我们假定Alice和Bob各在ETH和EOS有账号。他们操作的步骤如下。

1. Alice首先生成一个随机的私钥，key。

2. Alice和Bob在线下先约定好一个期限，比如T1 = 30分钟。 这个时间代表Alice的转账将在30分钟后失效。Bob为了保证转账成功，Bob将取一个时间T2=T1/2 = 15分钟。Bob取的时间只要能保证T2和T1-T2足够长即可（例如保证区块链confirm）。

3. Alice用key来生成一个伪随机数，例如 ```R = sha(key|| transaction_nonce)```。这里sha代表SHA Hash。需要注意的是，transaction_nonce必须是每一次都不一样的。这样才能保证生成的R是不一样的。

4. Alice用R计算另一个Hash值， ```H=ripemd160(R)```。这个ripemd160是另一个Hash函数。它几乎在所有的区块链合约上都有实现。

5. Alice用H作为key, 用我们的Swap合约锁定5ETH，指定失效时间为T1 = 30分钟，并将收款人为Bob的以太坊地址。然后将H发送给Bob。 注意，Bob只有拿到了R之后，才能取到5个ETH。所以只要Alice不将R发给Bob，那么Alice的资金则是安全的。

6. Bob得到了H之后，他可以用H在以太访的Swap合约上查询Alice是否正确地将5个ETH锁定了。如果他发现错误，他可以不做任何操作，这即是中止交易。如果Alice的锁定是正确的，那么Bob可以做进一步操作。 Bob用H将200 EOS在EOS上的Swap合约锁定，设定失效时间为T2=15分钟，收款人是Alice。这时Bob可以告知Alice EOS已锁定。

7. Alice在得到Bob的通知之后，她可以用H在EOS的Swap合约上查询，检查Bob是否按要求把EOS锁定了。如果Alice发现任何不对，Alice可以不做任何操作。那么交易自动中止，双方都不会损失。如果Alice确认Bob的锁定，她可以用R在EOS的Swap合约上领取200EOS。Alice可以选告知Bob（也可以不告知，不会对安全性有所影响）。

8. Bob可以等待T2=15分钟，这时如果Alice没有领取EOS，那么Bob可以把200EOS退回。如果Alice已经领取，那么EOS上的Swap合同已经正确地记录了R。Bob可以使用R在ETH上的Swap合约上把自己5个ETH赎回。

8. 等待T1=30分钟后，如果Bob没能在ETH的Swap合约上领取ETH，那么Alice可以把自己的ETH退回。
