pragma solidity ^0.7.3;
interface IISMFactory {
    function getproductTokens(address productAddress) external view returns(address,address);
    
}