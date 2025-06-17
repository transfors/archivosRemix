// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TransforNFT is ERC721 {
    uint256 token_count;

    constructor() ERC721("Transfor NFT", "TNFT") {}

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        return "https://ipfs.io/ipfs/bafkreifg7hpytrm5piezni2mtvwmfo7d6mqzhoxb7ftf6gm2kbtk5omr2u";
    }

    function mintNFT(address to) public
    {
        token_count  += 1;
        _mint(to, token_count);
    }
}