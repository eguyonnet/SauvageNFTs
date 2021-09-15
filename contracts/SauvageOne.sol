//SPDX-License-Identifier: None
pragma solidity 0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SauvageOne is ERC721Enumerable, ReentrancyGuard, Ownable {

    // Maximum number of token mintable
    uint256 private _maxSupply;

    constructor(string memory name_, string memory symbol_, uint256 maxSupply_) ERC721(name_, symbol_) Ownable() {
        _maxSupply = maxSupply_;
        //console.log("Initializing with name '%s' symbol '%s' and maxtotalSupply '%s'", name_, symbol_, maxSupply_);
    }

    function claim(uint256 tokenId_) public nonReentrant {
        require(tokenId_ >= 0 && tokenId_ < _maxSupply, "Invalid token Id");
        _safeMint(_msgSender(), tokenId_);
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
        require(_exists(tokenId_), "ERC721Metadata: URI query for nonexistent token");

        //string memory baseURI = _baseURI();
        //return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId_)) : "";
        
        // uniquement si token owner ou authorized or contract owner
        // if (_msgSender() == ownerOf(tokenId_) || _msgSender() == owner())

        // ownerOf(tokenId_) ou _isApprovedOrOwner(tokenId_)

        bytes memory svg = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 100 200"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" />';
        svg = abi.encodePacked(svg, '<text x="10" y="20" class="base">', tokenId_, '</text></svg>');
        bytes memory json = encode(abi.encodePacked('{"name": "Piece #', tokenId_, '", "description": "Best NFT collection ever", "image": "data:image/svg+xml;base64,', encode(svg), '"}'));
        
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function maxSupply() public view virtual returns (uint256) {
        return _maxSupply;
    }

    function encode(bytes memory data) internal pure returns (bytes memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

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
