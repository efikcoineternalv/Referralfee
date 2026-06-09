// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IPancakeRouter {
    function WETH() external pure returns (address);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

contract EFIKCOINReferral {
    address public constant EFC = 0x677ce9cba67f7484ea951a12897ce780cfd8fed1;
    address public constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // PancakeSwap V2
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    address public treasury = 0x676cCf34C191a9D6EFE4B265b84877C619A559d0;
    uint256 public referralFee = 200; // 2%
    uint256 public treasuryFee = 200; // 2%
    uint256 public constant FEE_BASE = 10000;

    mapping(address => address) public referrerOf;

    event Bought(address indexed buyer, address indexed referrer, uint256 bnbIn, uint256 efcOut);
    event Donated(address indexed from, uint256 amount, string currency);

    function setReferrer(address _referrer) external {
        require(_referrer!= msg.sender, "Cannot refer yourself");
        require(referrerOf[msg.sender] == address(0), "Already set");
        referrerOf[msg.sender] = _referrer;
    }

    function buyWithReferral(address _referrer) external payable {
        require(msg.value > 0, "Send BNB");
        if (referrerOf[msg.sender] == address(0) && _referrer!= address(0) && _referrer!= msg.sender) {
            referrerOf[msg.sender] = _referrer;
        }

        address ref = referrerOf[msg.sender];
        uint256 refAmount = 0;
        uint256 treasuryAmount = msg.value * treasuryFee / FEE_BASE;

        if (ref!= address(0)) {
            refAmount = msg.value * referralFee / FEE_BASE;
            payable(ref).transfer(refAmount);
        }

        payable(treasury).transfer(treasuryAmount);
        uint256 swapAmount = msg.value - refAmount - treasuryAmount;

        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = EFC;

        IPancakeRouter(ROUTER).swapExactETHForTokensSupportingFeeOnTransferTokens{value: swapAmount}(
            0, path, msg.sender, block.timestamp + 300
        );

        emit Bought(msg.sender, ref, msg.value, 0);
    }

    function donateBNB() external payable {
        require(msg.value > 0, "Send BNB");
        payable(treasury).transfer(msg.value);
        emit Donated(msg.sender, msg.value, "BNB");
    }

    function donateEFC(uint256 _amount) external {
        IERC20(EFC).transferFrom(msg.sender, treasury, _amount);
        emit Donated(msg.sender, _amount, "EFC");
    }

    // Owner can update treasury if needed for legacy
    function updateTreasury(address _newTreasury) external {
        require(msg.sender == treasury, "Only treasury");
        treasury = _newTreasury;
    }

    receive() external payable {
        payable(treasury).transfer(msg.value);
    }
}
