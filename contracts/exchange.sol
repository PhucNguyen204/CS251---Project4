// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "Chill Exchange";

    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // TODO: paste token contract address here
    Token public token = Token(tokenAddr);

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    mapping(address => uint) private lps;

    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    uint private total_shares = 0;

    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require(token_reserves == 0, "Token reserves was not 0");
        require(eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require(msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        //lp shares
        total_shares = 10 ** 5;
        //số shares của người gọi hợp đồng
        lps[msg.sender] = 100;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    //***** số lượng token khi có sự thay đổi ETH trong contract  *****/
    function calcDeltaToken(uint delta_ETH) private view returns (uint) {
        uint delta_token = (token.balanceOf(address(this)) * delta_ETH) /
            address(this).balance; // (token * ∆eth) / eth
        return delta_token;
    }

    //Thêm thanh khoản vào pool
    function addLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        require(msg.value > 0, "not enough");
        uint delta_token = calcDeltaToken(msg.value);
        uint token_amount = token.balanceOf(msg.sender);
        require(
            token_amount >= delta_token,
            unicode"Không đủ token để thêm vào pool"
        );
        // kiểm tra slippage
        uint exchange_rate = (token_reserves * 1e18) / eth_reserves;
        require(
            exchange_rate <= max_exchange_rate &&
                min_exchange_rate <= exchange_rate,
            "Loi slippage"
        );

        // cập nhập số share
        uint lp_shares;
        if (total_shares == 0) {
            lp_shares = msg.value;
        } else {
            lp_shares = (msg.value * total_shares) / eth_reserves;
        }
        lps[msg.sender] += lp_shares;
        total_shares += lp_shares;
        //cập nhập eth, token trong pool
        eth_reserves += msg.value;
        token_reserves += delta_token;
        //update k
        k = eth_reserves * token_reserves;
        //chuyển token vào contract
        token.transferFrom(msg.sender, address(this), delta_token);
    }

    // Function removeLiquidity:
    function removeLiquidity(
        uint amountETH,
        uint max_exchange_rate,
        uint min_exchange_rate
    ) public payable {
        //đảm bảo còn eth trong pool
        require(amountETH <= eth_reserves - 1, "khong du eth trong pool");
        uint delta_token = calcDeltaToken(amountETH);
        //cập nhập shares
        uint lp_shares = (amountETH * total_shares) / eth_reserves;
        total_shares -= lp_shares;
        // kiểm tra share có đủ để rút không
        require(lps[msg.sender] >= lp_shares, "khong du share de rut");
        uint exchange_rate = (token_reserves * 1e18) / eth_reserves;
        require(
            exchange_rate <= max_exchange_rate &&
                min_exchange_rate <= exchange_rate,
            "loi slippage"
        );

        //cập nhập eth, token trong pool
        uint diff_eth = address(this).balance - eth_reserves; //eth chênh lệch giữa contract và pool
        uint diff_token = token.balanceOf(address(this)) - token_reserves; //token chệnh lệch giữa contract và pool

        uint entitled_eth = diff_eth * (lp_shares / total_shares); // phí eth cho LP
        uint entitled_token = diff_token * (lp_shares / total_shares); // phí token cho LP

        lps[msg.sender] -= lp_shares;
        eth_reserves -= amountETH;
        token_reserves -= delta_token;

        k = eth_reserves * token_reserves;

        //chuyển eth, token cho người rút
        token.transfer(msg.sender, delta_token + entitled_token);
        payable(msg.sender).transfer(amountETH + entitled_eth);
    }

    //Hàm loại bỏ toàn bộ thanh khoản
    function removeAllLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        uint all_amount_eth;
        all_amount_eth = eth_reserves * (lps[msg.sender] / total_shares); // eth khi rút toàn bộ shares
        removeLiquidity(all_amount_eth, max_exchange_rate, min_exchange_rate);
    }

    function swapTokensForETH(
        uint amountTokens,
        uint max_exchange_rate
    ) external payable {
        // token của người gọi hàm
        uint callerSupply = token.balanceOf(msg.sender);
        require(amountTokens <= callerSupply, "khong du token de swap");

        //số lượng token cuối cùng sau khi swap
        uint last_token = amountTokens -
            amountTokens *
            (swap_fee_numerator / swap_fee_denominator);

        // token mới trong pool
        uint new_token_reserves = token_reserves + last_token;
        //eth mới trong pool
        uint new_eth_reserves = k / new_token_reserves;
        uint amountEth = eth_reserves - new_eth_reserves;

        //kiểm tra slippage
        uint exchange_rate = (token_reserves * 1e18) / eth_reserves;
        require(exchange_rate <= max_exchange_rate, "loi slippage");
        require(amountEth <= eth_reserves - 1, "khong du eth trong pool");

        eth_reserves = new_eth_reserves;
        token_reserves = new_token_reserves;

        payable(msg.sender).transfer(amountEth);
        token.transferFrom(msg.sender, address(this), amountTokens);
    }

    // ETH is sent to contract as msg.value

    function swapETHForTokens(uint max_exchange_rate) external payable {
        uint amountEth = msg.value;
        //số lượng eth cuối cùng sau khi swap
        uint last_eth = amountEth - (amountEth * swap_fee_numerator) / swap_fee_denominator;

        // eth mới trong pool
        uint new_eth_reserves = eth_reserves + last_eth;
        uint new_token_reserves = k / new_eth_reserves;

        uint amountTokens = token_reserves - new_token_reserves;

        //kiểm tra slippage
        uint exchange_rate = (eth_reserves * 1e18) / token_reserves;
        require(exchange_rate <= max_exchange_rate, "Loi slippage");

        require(
            amountTokens <= token_reserves - 1,
            "khong du token trong pool"
        );

        eth_reserves = new_eth_reserves;
        token_reserves = new_token_reserves;

        token.transfer(msg.sender, amountTokens);
        //payable(msg.sender).transfer(amountEth);
    }
}
