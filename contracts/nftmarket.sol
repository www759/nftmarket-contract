// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract Market {
    address public marketOwner;
    IERC20 public erc20;
    
    struct Order {
        address contractAddress;
        uint256 tokenId;
        address seller;
        uint256 price;
    }

    mapping(address => Order[]) public contractOrders;
    mapping(address => mapping(uint256 => Order)) public orderOfTokenId;
    mapping(address => mapping(uint256 => uint256)) public tokenIdToIndex;

    event NewOrder(
        address indexed contractAddress,
        address indexed seller, 
        uint256 indexed tokenId,
        uint256 price
    );

    event Deal(
        address indexed contractAddress,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price
    );

    event OrderCanceled(
        address indexed contractAddress,
        address indexed seller, 
        uint256 indexed tokenId
    );

    event PriceChanged(
        address indexed contractAddress,
        address indexed seller, 
        uint256 indexed tokenId,
        uint256 oldPrice,
        uint256 newPrice
    );


    constructor(address _erc20Address) {
        require(_erc20Address != address(0), "erc20 address is zero");

        marketOwner = msg.sender;
        erc20 = IERC20(_erc20Address);
    }

    function listNFT(address _contractAddress, uint256 _tokenId, uint256 _price) public {
        require(_contractAddress != address(0), "contract address is zero");

        IERC721 nft = IERC721(_contractAddress);
        address seller = msg.sender;
        require(nft.ownerOf(_tokenId) == seller, "msg sender is not token's owner");
        require(nft.isApprovedForAll(seller, address(this)), "msg sender have not call setApprovedForAll for market");

        contractOrders[_contractAddress].push(Order(_contractAddress, _tokenId, seller, _price));
        tokenIdToIndex[_contractAddress][_tokenId] = contractOrders[_contractAddress].length - 1;
        orderOfTokenId[_contractAddress][_tokenId] = Order(_contractAddress, _tokenId, seller, _price);


        emit NewOrder(_contractAddress, seller, _tokenId, _price);
    }

    function buy(address _contractAddress, uint256 _tokenId) public {
        require(_contractAddress != address(0), "contract address is zero");

        IERC721 nft = IERC721(_contractAddress);
        Order memory order = orderOfTokenId[_contractAddress][_tokenId];
        require(order.seller != address(0), "token has not listed");
        require(order.seller != msg.sender, "buyer is seller");
        
        require(erc20.transferFrom(msg.sender, order.seller, order.price), "transfer erc20 fail");
        nft.safeTransferFrom(order.seller, msg.sender, _tokenId);

        _removeOrder(_contractAddress, _tokenId);

        emit Deal(_contractAddress, msg.sender, _tokenId, order.price);
    }

    function unlistNFT(address _contractAddress, uint256 _tokenId) public {
        require(_contractAddress != address(0), "contract address is zero");
        
        address seller = orderOfTokenId[_contractAddress][_tokenId].seller;
        require(seller != address(0), "token has not listed");
        require(msg.sender == seller, "msg sender is not seller");

        _removeOrder(_contractAddress, _tokenId);

        emit OrderCanceled(_contractAddress, seller, _tokenId);
    }

    function changePrice(address _contractAddress, uint256 _tokenId, uint256 _price) public {
        require(_contractAddress != address(0), "contract address is zero");
        address seller = orderOfTokenId[_contractAddress][_tokenId].seller;
        require(seller != address(0), "token has not listed");
        require(msg.sender == seller, "msg sender is not seller");

        uint256 oldPrice = orderOfTokenId[_contractAddress][_tokenId].price;
        orderOfTokenId[_contractAddress][_tokenId].price = _price;

        uint256 index = tokenIdToIndex[_contractAddress][_tokenId];
        contractOrders[_contractAddress][index].price = _price;
        
        emit PriceChanged(_contractAddress, seller, _tokenId, oldPrice, _price);
    }
    

    // function getAllNFTs(address _contractAddress) external view returns (Order[] memory) {
    // }


    // function getOrderByTokenId(address _contractAddress, uint256 _tokenId) external view returns (Order memory) {
    // }


    // function getMyNFTs() external view returns (uint256[] memory){
    // }


    function getOrderLength(address _contractAddress) external view returns(uint256) {
        return contractOrders[_contractAddress].length;
    }

    function _removeOrder(address _contractAddress, uint256 _tokenId) internal {
        uint256 index = tokenIdToIndex[_contractAddress][_tokenId];
        uint256 lastIndex = contractOrders[_contractAddress].length - 1;
        if(index != lastIndex) {
            Order storage lastOrder = contractOrders[_contractAddress][lastIndex];
            contractOrders[_contractAddress][index] = lastOrder;
            tokenIdToIndex[_contractAddress][lastOrder.tokenId] = index;
        }
        contractOrders[_contractAddress].pop();
        delete orderOfTokenId[_contractAddress][_tokenId];
        delete tokenIdToIndex[_contractAddress][_tokenId];
    }


}