pragma solidity ^0.4.15;

/* This contract is based on https://github.com/AltCoinExchange/ethatomicswap/blob/master/contracts/AtomicSwap.sol
   
   For two ETH-based chains, this contract allows two persons safely exchange assets without trusting each other. All ERC20 and ERC721Value tokens are supported.

   Author: Lin F. Yang
   Date:   2018/08/18

*/

contract AtomicSwap {

	/*The state of the swap instance*/
    enum State { Empty, Initiator}

	/*The AssetType of the swap instance*/
	enum AssetType { Native, ERC20Value, ERC721Value }

    struct Swap {
        uint initTimestamp;
        uint refundTime;

        bytes20 hashedSecret;
        bytes32 secret;

        address initiator;
        address participant;

        uint256 value;
		uint256 indexed erc721TokenId;

        bool emptied;

        State state;
		AssetType assetType;
    }

    mapping(bytes20 => Swap) public swaps;
    
	event Refunded(uint _refundTime);
    event Redeemed(uint _redeemTime);

	event Initiated(
		uint _initTimestamp,
    	uint _refundTime,
    	bytes20 _hashedSecret,
    	address _participant,
    	address _initiator,
		uint256 _funds,
		uint256 indexed erc721TokenId; 
	);

	constructor() public {}
    
	modifier isRefundable(bytes20 _hashedSecret) {
	    require(block.timestamp > swaps[_hashedSecret].initTimestamp + swaps[_hashedSecret].refundTime);
	    require(swaps[_hashedSecret].emptied == false);
	    _;
	}
	
	modifier isRedeemable(bytes20 _hashedSecret, bytes32 _secret) {
	    require(ripemd160(_secret) == _hashedSecret);
		require(block.timestamp < swaps[_hashedSecret].initTimestamp + swaps[_hashedSecret].refundTime);
	    require(swaps[_hashedSecret].emptied == false);
	    _;
	}
	
	modifier isInitiator(bytes20 _hashedSecret) {
	    require(msg.sender == swaps[_hashedSecret].initiator);
	    _;
	}
	
	modifier isNotInitiated(bytes20 _hashedSecret) {
	    require(swaps[_hashedSecret].state == State.Empty);
	    _;
	}


	function __initiate (uint _refundTime,bytes20 _hashedSecret,address _participant) 
		private
	{
	    swaps[_hashedSecret].refundTime = _refundTime;
	    swaps[_hashedSecret].initTimestamp = block.timestamp;
	    swaps[_hashedSecret].hashedSecret = _hashedSecret;
	    swaps[_hashedSecret].participant = _participant;
	    swaps[_hashedSecret].initiator = msg.sender;
        swaps[_hashedSecret].state = State.Initiator;
	}

	/**
		Initiate the swapper with the native token.
	*/
	function initiate (uint _refundTime,bytes20 _hashedSecret,address _participant) 
	    payable 
	    isNotInitiated(_hashedSecret)    
	{
		__initiate(_refundTime, _hashedSecret, _participant);

        swaps[_hashedSecret].value = msg.value;
		swaps[_hashedSecret].assetType = AssetType.Native;

		Initiated(
			swaps[_hashedSecret].initTimestamp,
    		_refundTime,
    		_hashedSecret,
    		_participant,
    		msg.sender,
		 	msg.value,
			0
		);
	}

	/**
		Initiate the swapper with the ERC20Value token.
	*/
	function initiateERC20 (uint _refundTime, 
							bytes20 _hashedSecret, 
							address _participant, 
							address _tokenAddress, 
							uint256 _value) 
	    isNotInitiated(_hashedSecret)    
	{
		__initiate(_refundTime, _hashedSecret, _participant);

		//TODO

        swaps[_hashedSecret].value = _value;
		swaps[_hashedSecret].assetType = AssetType.ERC20Value;

		Initiated(
			swaps[_hashedSecret].initTimestamp,
    		_refundTime,
    		_hashedSecret,
    		_participant,
    		msg.sender,
		 	msg.value,
			0
		);
	}

	/**
		Initiate the swapper with the ERC721Value token.
	*/
	function initiateERC20 (uint _refundTime, 
							bytes20 _hashedSecret, 
							address _participant, 
							address _tokenAddress, 
							uint256 indexed tokenId) 
	    isNotInitiated(_hashedSecret)    
	{
		__initiate(_refundTime, _hashedSecret, _participant);

		//TODO

        swaps[_hashedSecret].erc721TokenId = tokenId;
		swaps[_hashedSecret].assetType = AssetType.ERC20Value;

		Initiated(
			swaps[_hashedSecret].initTimestamp,
    		_refundTime,
    		_hashedSecret,
    		_participant,
    		msg.sender,
		 	msg.value,
			0
		);
	}


	function redeem(bytes32 _secret, bytes20 _hashedSecret) 
	    isRedeemable(_hashedSecret, _secret)
	{

        if(swaps[_hashedSecret].state == State.Initiator){
			if(swaps[_hashedSecret].assetType == AssetType.Native){
            	swaps[_hashedSecret].participant.transfer(swaps[_hashedSecret].value);
			}
			if(swaps[_hashedSecret].assetType == AssetType.ERC20Value){
            	//TODO
			}

			if(swaps[_hashedSecret].assetType == AssetType.ERC721Value){
            	//TODO
			}				

        }
        swaps[_hashedSecret].emptied = true;
        Redeemed(block.timestamp);
        swaps[_hashedSecret].secret = _secret;
	}

	function refund(bytes20 _hashedSecret)
	    isRefundable(_hashedSecret) 
	{

        if(swaps[_hashedSecret].state == State.Initiator){
			if(swaps[_hashedSecret].assetType == AssetType.Native){
            	swaps[_hashedSecret].initiator.transfer(swaps[_hashedSecret].value);
			}

			if(swaps[_hashedSecret].assetType == AssetType.ERC20Value){
            	//TODO
			}

			if(swaps[_hashedSecret].assetType == AssetType.ERC721Value){
            	//TODO
			}
        }
        swaps[_hashedSecret].emptied = true;
	    Refunded(block.timestamp);
	}
}
