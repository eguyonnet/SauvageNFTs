//SPDX-License-Identifier: None
pragma solidity 0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @dev future improvment :
///           - Access control for admin tasks (startPresale, startSale, addToWhitelist, isWhiteListed, getWhitelistSize)
///           - withdraw : allow split to multiple owners (known at creation time, then use PaymentSplitter) and partial withdraw
contract SauvageOne is ERC721Enumerable, ReentrancyGuard, Ownable {

    // Use if user does not choose id when claiming and/or if token are burnable
    using Counters for Counters.Counter;
    Counters.Counter private _incrTokenId; 
    // TODO update in loop cost gas (SSTORE), use normal uint (not issue with solc starting 0.8.*)

    // Status
    enum Period {INIT, PRESALE, SALE, AFTERSALE}
    Period public currentPeriod; // TODO est js with event and make this private

    // Total number of token mintable
    uint256 public immutable maxSupply;

    // Maximum number of token mintable by address 
    uint public constant SECURITY_MAX_NBR_TOKEN_CLAIMABLE = 5; 
    uint private _maxNbrTokenClaimable;

    // Price per token
    uint256 public immutable pricePerToken;

    // Presale configuration
    mapping (address => bool) private _presaleWhiteList;
    uint private constant SECURITY_MAX_WHITELIST_ONLY_SALE_DURATION = 604800; // 7 DAYS
    uint private _whitelistSize;
    uint public whitelistOnlySaleEndTimestamp; // end of reserved period for whitelisted addresses during sale period


    // ----------------------------------------
    // EVENTS
    // ----------------------------------------
    event TokenClaimed(address indexed to, uint256 indexed tokenId);
    event PresaleStarted();
    event SaleStarted();
    event SaleEnded();
    event Withdrawed(address indexed to, uint amount);
    event DepositReceived(address indexed from, uint256 amount);


    // ----------------------------------------
    // FUNCTIONS
    // ----------------------------------------
    constructor(string memory name_, string memory symbol_, uint256 pricerPerToken_, uint256 maxSupply_) ERC721(name_, symbol_) Ownable() payable {
        require(maxSupply_ > 0, "Invalid max supply");
        currentPeriod = Period.INIT;
        pricePerToken = pricerPerToken_;
        maxSupply = maxSupply_;

        //console.log("Initializing with name '%s' symbol '%s' and maxtotalSupply '%s'", name_, symbol_, maxSupply_);
    }

    // Called when msg.value > 0 with empty msg.data
    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }

    fallback() external payable { 
        require(msg.data.length == 0 && msg.value >= 0, "Invalid date or value"); 
        emit DepositReceived(msg.sender, msg.value); 
    }

    /// @notice Mint a new token (only owner can mint before sale period and only whitelisted addresses can mint durng reserved period). Only one transaction successful per whitelisted address
    /// @dev determin if reserved period is over when needed and is sale period has to be ended (all tokens with max supply are minted)
    /// @param nbrOfTokenRequested_ Number of token claimed
    function claim(uint nbrOfTokenRequested_) external nonReentrant payable {
        require(currentPeriod != Period.AFTERSALE, "Sale period ended");
        require(nbrOfTokenRequested_ > 0, "Request at least 1 token");
        if (_msgSender() != owner()) {
            require(currentPeriod == Period.SALE, "Sale period not opened");
            if (whitelistOnlySaleEndTimestamp > 0 && whitelistOnlySaleEndTimestamp > block.timestamp) {
                require(_presaleWhiteList[_msgSender()], "Address not found in whitelist");
            }
        }

        uint256 currentTokenId = _incrTokenId.current();

        // check number of tokens allowed (takes into account what the user already owns - he could buy in between...)
        if (_msgSender() != owner() && (balanceOf(_msgSender()) + nbrOfTokenRequested_) > _maxNbrTokenClaimable) {
            revert("Too many tokens claimed");
        }
        // Check if enought tokens left
        if (currentTokenId + nbrOfTokenRequested_ > maxSupply) {
            revert("Not enough tokens left");
        }
        // If case not more supply, end sale
        if (currentTokenId + nbrOfTokenRequested_ == maxSupply) {
            currentPeriod = Period.AFTERSALE;
            emit SaleEnded();
        }

        // Check if enough value ** TODO check if = for gas
        if (_msgSender() != owner() && pricePerToken > 0) {
            require(pricePerToken * nbrOfTokenRequested_ <= msg.value, "Ether value sent is not enough");
        }

        // Whitelist allows one buy only
        if (_presaleWhiteList[_msgSender()]) {
            _presaleWhiteList[_msgSender()] = false;
        }

        for (uint i = 0; i < nbrOfTokenRequested_; i++) {
            _safeMint(_msgSender(), currentTokenId);
            _incrTokenId.increment();
            emit TokenClaimed(_msgSender(), currentTokenId);
            currentTokenId = _incrTokenId.current();
        }

    }

    /// @notice Transfer funds to owner. 
    function withdraw(address payable to_) external nonReentrant onlyOwner {
        require(to_ != address(0), "Invalid address");
        uint balance = address(this).balance;
        require(balance > 0, "No funds");
        (bool sent, ) = to_.call{value: balance}("");
        require(sent, "Fail to send ether");
        emit Withdrawed(to_, balance);
    }

    /// @notice Start the presale process 
    function startPresale() public onlyOwner() {
        require(currentPeriod == Period.INIT, "Invalid period");
        currentPeriod = Period.PRESALE;
        emit PresaleStarted();
    }

    /// @notice Fill whitelist addresses (0x0 ignored as well as owner and adresses already in)
    /// @dev Max size of the array not to run out of gas. `SafeMath` is no longer needed starting with Solidity 0.8. The compiler now has built in overflow checking
    /// @param addresses_ Array of addresses
    /// @return number of new valid addresses added 
    function addToWhitelist(address[] memory addresses_) external onlyOwner returns (uint) {
        require(currentPeriod == Period.PRESALE, "Invalid period");
        require(addresses_.length <= 50, "Limit array size is 50");
        uint count;
        for(uint256 i = 0; i < addresses_.length; i++) {
            if (addresses_[i] != address(0) && addresses_[i] != owner() && !_presaleWhiteList[addresses_[i]]) {
                _presaleWhiteList[addresses_[i]] = true;
                count++;
            }
        }
        if (count > 0) {
            _whitelistSize += count;
        }
        return count;
    }

    /// @notice Check if given address is in whitelist (! when tokens are claimed, address considered as removed from list)
    /// @param address_ Unique Address
    /// @return bool 
    function isWhiteListed(address address_) external view onlyOwner returns (bool) {
        return _presaleWhiteList[address_];
    }

    /// @notice Check if sender address is in whitelist (! when tokens are claimed, address considered as removed from list)
    /// @return bool 
    function amIWhiteListed() external view returns (bool) {
        return _presaleWhiteList[_msgSender()];
    }

    /// @notice Count addresses in whitelist
    /// @return uint
    function getWhitelistSize() external view onlyOwner() returns (uint) {
        return _whitelistSize;
    }

    /// @notice Start the sale process and initialize reserved period for whitelisted addresses when requested
    function startSale(uint maxNbrTokenClaimable_, uint whitelistOnlySaleDuration_) public onlyOwner {
        require(currentPeriod == Period.INIT || currentPeriod == Period.PRESALE, "Invalid period");
        require(maxNbrTokenClaimable_ > 0 && maxNbrTokenClaimable_< maxSupply && maxNbrTokenClaimable_ <= SECURITY_MAX_NBR_TOKEN_CLAIMABLE, "Invalid maxNbrTokenClaimable");
        if (_whitelistSize == 0) {
            require(whitelistOnlySaleDuration_ == 0, "Invalid duration - WHList empty");   
        } else {
            require(whitelistOnlySaleDuration_ > 0 && whitelistOnlySaleDuration_ <= SECURITY_MAX_WHITELIST_ONLY_SALE_DURATION, "Invalid duration - too long");
        }
        
        currentPeriod = Period.SALE;
        _maxNbrTokenClaimable = maxNbrTokenClaimable_;
        if (whitelistOnlySaleDuration_ > 0) {
            whitelistOnlySaleEndTimestamp = block.timestamp + whitelistOnlySaleDuration_;
        }
        emit SaleStarted();
    }

    /*
    function mint(uint256 tokenId_, string memory tokenURI_) { // string memory name
        il faut hériter de ERC721URIStorage pour gérer les URI dans ipfs 
        pour appeler _setTokenURI(tokenId_, tokenURI_)
        si on veut gérer les noms il faut un mapping
    }

    function _baseURI() override internal view returns (string memory) {
        return "";
    }*/

    function tokenURI(uint256 tokenId_) override public view returns (string memory) {
        require(_exists(tokenId_), "Nonexistent token");

        //string memory baseURI = _baseURI();
        //return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId_)) : "";
        
        // uniquement si token owner ou authorized or contract owner
        // if (_msgSender() == ownerOf(tokenId_) || _msgSender() == owner())

        // ownerOf(tokenId_) ou _isApprovedOrOwner(tokenId_)

        bytes memory svg = "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 100 200'><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width='100%' height='100%' fill='black' />";
        svg = abi.encodePacked(svg, "<text x='10' y='20' class='base'>", tokenId_, "</text></svg>");
        bytes memory json = encode(abi.encodePacked("{'name': 'Piece #", tokenId_, "', 'description': 'Best NFT collection ever', 'image': 'data:image/svg+xml;base64,", encode(svg), "'}"));
        
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function encode(bytes memory data) internal pure returns (bytes memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = (4 * (len + 2)) / 3;

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return result; //string(result);
    }

}
