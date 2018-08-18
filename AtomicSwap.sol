pragma solidity ^0.4.22;

/* This contract is based on https://github.com/AltCoinExchange/ethatomicswap/blob/master/contracts/AtomicSwap.sol
   
   For two ETH-based chains, this contract allows two persons safely exchange assets without trusting each other. All ERC20 and ERC721Value tokens are supported.

   Author: Lin F. Yang
   Date:   2018/08/18

*/

contract ERC20 {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract ERC721{
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

interface ERC721TokenReceiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the
    /// recipient after a `transfer`. This function MAY throw to revert and reject the transfer. Return
    /// of other than the magic value MUST result in the transaction being reverted.
    /// @notice The contract address is always the message sender. 
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    /// unless throwing
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) external returns(bytes4);
}
    

contract AtomicSwap is ERC721TokenReceiver{

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

        address tokenAddress;

        uint256 value;

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

        AssetType _assetType,

        uint256 _funds,

        address _tokenAddress
    );

    constructor() public{}
    
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
        public
        payable 
        isNotInitiated(_hashedSecret)   
    {
        __initiate(_refundTime, _hashedSecret, _participant);

        swaps[_hashedSecret].value = msg.value;
        swaps[_hashedSecret].assetType = AssetType.Native;

        emit Initiated(
            swaps[_hashedSecret].initTimestamp,
            _refundTime,
            _hashedSecret,
            _participant,
            msg.sender,
            AssetType.Native,
             msg.value,
            address(0)
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
        public
        isNotInitiated(_hashedSecret)    
    {
        __initiate(_refundTime, _hashedSecret, _participant);

        require(ERC20(_tokenAddress).transferFrom(msg.sender, this, _value) == true);

        swaps[_hashedSecret].value = _value;
        swaps[_hashedSecret].assetType = AssetType.ERC20Value;
        swaps[_hashedSecret].tokenAddress = _tokenAddress;

        emit Initiated(
            swaps[_hashedSecret].initTimestamp,
            _refundTime,
            _hashedSecret,
            _participant,
            msg.sender,
            AssetType.ERC20Value,
             _value,
            _tokenAddress
        );
    }

    /**
        Initiate the swapper with the ERC721Value token.
    */
    function initiateERC721 (uint _refundTime, 
                            bytes20 _hashedSecret, 
                            address _participant, 
                            address _tokenAddress, 
                            uint256 _tokenId) 
        public
        isNotInitiated(_hashedSecret)    
    {
        __initiate(_refundTime, _hashedSecret, _participant);

        ERC721(_tokenAddress).safeTransferFrom(msg.sender, this, _tokenId);

        swaps[_hashedSecret].value = _tokenId;
        swaps[_hashedSecret].assetType = AssetType.ERC721Value;
        swaps[_hashedSecret].tokenAddress = _tokenAddress;

        emit Initiated(
            swaps[_hashedSecret].initTimestamp,
            _refundTime,
            _hashedSecret,
            _participant,
            msg.sender,
            AssetType.ERC721Value,
             _tokenId,
            _tokenAddress
        );
    }


    function redeem(bytes32 _secret, bytes20 _hashedSecret) 
        public
        isRedeemable(_hashedSecret, _secret)
    {

        if(swaps[_hashedSecret].state == State.Initiator){
            if(swaps[_hashedSecret].assetType == AssetType.Native){
                swaps[_hashedSecret].participant.transfer(swaps[_hashedSecret].value);
            }
            
            if(swaps[_hashedSecret].assetType == AssetType.ERC20Value){
                ERC20(swaps[_hashedSecret].tokenAddress).transfer(swaps[_hashedSecret].participant, swaps[_hashedSecret].value);
            }

            if(swaps[_hashedSecret].assetType == AssetType.ERC721Value){
                ERC721(swaps[_hashedSecret].tokenAddress).safeTransferFrom(this, swaps[_hashedSecret].participant, swaps[_hashedSecret].value);
            }                

        }
        
        swaps[_hashedSecret].emptied = true;
        emit Redeemed(block.timestamp);
        swaps[_hashedSecret].secret = _secret;
    }

    function refund(bytes20 _hashedSecret)
        public
        isRefundable(_hashedSecret) 
    {

        if(swaps[_hashedSecret].state == State.Initiator){
            if(swaps[_hashedSecret].assetType == AssetType.Native){
                swaps[_hashedSecret].initiator.transfer(swaps[_hashedSecret].value);
            }

            if(swaps[_hashedSecret].assetType == AssetType.ERC20Value){
                ERC20(swaps[_hashedSecret].tokenAddress).transfer(swaps[_hashedSecret].initiator, swaps[_hashedSecret].value);
            }

            if(swaps[_hashedSecret].assetType == AssetType.ERC721Value){
                ERC721(swaps[_hashedSecret].tokenAddress).safeTransferFrom(this, swaps[_hashedSecret].initiator, swaps[_hashedSecret].value);
            }
        }
        swaps[_hashedSecret].emptied = true;
        emit Refunded(block.timestamp);
    }


    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) external returns(bytes4){
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
