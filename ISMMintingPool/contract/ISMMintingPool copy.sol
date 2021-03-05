pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;
import "./Ownable.sol";
import './IERC20.sol';
import './SafeMath.sol';
import "./SafeERC20.sol";

/*
*minting pool
*/
interface IISMFactory {

    function getproductTokens(address productAddress) external view returns(address,address);
    function getexpirationTimestamps(address productAddress) external view returns(uint256);
    function getexpirationTimestampsAndName(address productAddress) external view returns(uint256,string memory,string memory);
}
 
contract ISMMintingPool is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath  for uint256;
    IERC20 public   erc20BounsToken; 
    address public  LSPXContract;
    uint256   public   baseNumner = 1e18;
    address public monetaryPolicy;
    IISMFactory  public ismFactory;
    constructor(IERC20 _erc20BounsToken,IISMFactory _ISMFactory) public {
        initializeOwner();
        monetaryPolicy = msg.sender;
        erc20BounsToken = _erc20BounsToken;
        ismFactory = _ISMFactory;
    }
    
    struct minerInfo{
        uint256         timestamps;
        address         lpToken;         
        uint256         amount;          
        uint256         bonus;           
        uint256         rewardDebt;      
    }    
    struct BonusTokenInfo {
        uint256         timestamps;
        string          name;
        uint256         totallpToken;              
        address         bonusAddr;                
        uint256         totalBonus;                        
        uint256         lastBonus;
        uint256         accBonusPerShare;            
        uint256         expirationTimestamps;
        uint256         lastRewardTime;              
        uint256         ismPerBlock;
        uint256         startTime;
        uint256         updatePoolTime;
        uint256         passBonus;
    }
    struct mintingPoolInfo{
        uint256         timestamps;
        address         lpToken;
        string          lpTokensymbol;
    }
    mapping(address => mapping(address => minerInfo)) miner;
    mapping(address => BonusTokenInfo) BonusToken;
    mapping(address => mintingPoolInfo ) mintingPool;
    address []  listmintingPool;
    mapping(address => address[] ) minerLpTokenList;

    event AddBonusToken(address who,IERC20 token,uint256 amount,address lpToken);
    event SubBonusToken(address who,IERC20 token,uint256 amount,address lpToken);
    event AddmintingPool(address who,address lpToken);
    event Deposit(address who,address lpToken,uint256 amount);
    event Withdraw(address who,address lpToken,uint256 amount,address bounsToken, uint256 bonus);
    event LogMonetaryPolicyUpdated(address policy);
    
    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy);
        _;
    }
    /**
     * @param monetaryPolicy_ The address of the monetary policy contract to use for authentication.
     */
    function setMonetaryPolicy(address monetaryPolicy_)
        external
        onlyOwner
    {
        monetaryPolicy = monetaryPolicy_;
        emit LogMonetaryPolicyUpdated(monetaryPolicy_);
    }
    function setismFactory(IISMFactory _ismFactory) public onlyOwner returns(bool){
        ismFactory = _ismFactory;
        return true;
    }
    function getminerLpTokenList(address who) public view returns(uint){
        require(who != address(0));
        return minerLpTokenList[who].length;
    }
    function getminerLpTokenListData(address who,uint index) public view returns(address){
        require(who != address(0));
        require(index < minerLpTokenList[who].length );
        return minerLpTokenList[who][index];
    }
    function getexpirationTimestamps(address productAddress) public view returns(uint256){
        require(productAddress != address(0));
        return ismFactory.getexpirationTimestamps(productAddress);
    }
    function getexpirationTimestampsAndName(address productAddress)public view returns(uint256,string memory,string memory){
        require(productAddress != address(0));
        uint256 expirationTimestamps;
        string memory name ;
        string memory protocolName;
        (expirationTimestamps,name,protocolName) = ismFactory.getexpirationTimestampsAndName(productAddress);
        return (expirationTimestamps,name,protocolName);
    }
    function getlistmintingPool() public view returns(uint){
        return listmintingPool.length;
    }
    function getlistmintingPooldata(uint index) public view returns(address){
        require(index < listmintingPool.length);
        return listmintingPool[index];
    }
    function getBonusToken(address lpToken) public view returns(BonusTokenInfo memory){
        require(lpToken != address(0));
        return BonusToken[lpToken];
    }
    function getminerInfo(address who,address lpToken ) public view returns(minerInfo memory){
        require(who != address(0));
        return miner[who][lpToken];
    }
    
    function addmintingPool(address lpToken) public onlyMonetaryPolicy returns(bool){
        require(lpToken != address(0));
        require(mintingPool[lpToken].lpToken == address(0));

        mintingPoolInfo memory newmintingPoolInfo= mintingPoolInfo({
            timestamps:         block.timestamp,
            lpToken:            lpToken,
            lpTokensymbol:      IERC20(lpToken).symbol()
        });
        mintingPool[lpToken] = newmintingPoolInfo;
        listmintingPool.push(lpToken);
        emit AddmintingPool(msg.sender,lpToken);
        return true;
    }
    function addBonusToken(string memory name, address lpToken,uint256 amount,uint256 expirationTimestamps) public   onlyMonetaryPolicy returns(bool){
 
        require(lpToken != address(0));
        require(amount >0);
        require(block.timestamp < expirationTimestamps );
        if(mintingPool[lpToken].lpToken == address(0)){
            addmintingPool( lpToken );
        }
        updateBonusShare(lpToken);
        uint256 ismPerBlock;
        uint256 passBonus;
        uint256 startTime = BonusToken[lpToken].startTime == 0 ? block.timestamp:BonusToken[lpToken].startTime;
        uint256 lastRewardTime = BonusToken[lpToken].lastRewardTime == 0 ? block.timestamp:BonusToken[lpToken].lastRewardTime;

        if( BonusToken[lpToken].totalBonus != 0 ){
            require( expirationTimestamps >= BonusToken[lpToken].expirationTimestamps );
            name = BonusToken[lpToken].name;
            if( BonusToken[lpToken].expirationTimestamps > block.timestamp ){
                passBonus = BonusToken[lpToken].ismPerBlock.mul(block.timestamp.sub(BonusToken[lpToken].updatePoolTime)); 
                BonusToken[lpToken].passBonus = passBonus.add(BonusToken[lpToken].passBonus); 
            } 
            else{  
                BonusToken[lpToken].passBonus = BonusToken[lpToken].totalBonus;
            }
            passBonus = BonusToken[lpToken].passBonus;
            ismPerBlock = (amount.add(BonusToken[lpToken].totalBonus).sub(passBonus)).div(expirationTimestamps.sub(block.timestamp));
        }
        else{
            ismPerBlock = amount.div(expirationTimestamps.sub(startTime)); 
            passBonus = 0;
        }
        BonusTokenInfo memory newBonusTokenInfo = BonusTokenInfo({
            timestamps:                 block.timestamp,
            name:                       name,
            totallpToken:               BonusToken[lpToken].totallpToken,
            bonusAddr:                  address(erc20BounsToken),
            totalBonus:                 amount.add(BonusToken[lpToken].totalBonus),
            lastBonus:                  amount.add(BonusToken[lpToken].lastBonus),
            accBonusPerShare:           BonusToken[lpToken].accBonusPerShare,
            expirationTimestamps:       expirationTimestamps,
            lastRewardTime:             lastRewardTime,
            ismPerBlock:                ismPerBlock,
            startTime:                  startTime,
            updatePoolTime:             block.timestamp,
            passBonus:                  passBonus
        });
        BonusToken[lpToken] = newBonusTokenInfo;
        erc20BounsToken.safeTransferFrom(msg.sender, address(this), amount);
        emit AddBonusToken(msg.sender,erc20BounsToken,amount,lpToken);
        return true;
    }
    function subBonusToken(address lpToken,uint256 amount) public   onlyMonetaryPolicy returns(bool){
        require(lpToken != address(0));
        require(amount >0);  
        require(block.timestamp < BonusToken[lpToken].expirationTimestamps);
        updateBonusShare(lpToken);
        uint256 passBonus;
        if( BonusToken[lpToken].expirationTimestamps > block.timestamp ){  
            passBonus = BonusToken[lpToken].ismPerBlock.mul(block.timestamp.sub(BonusToken[lpToken].updatePoolTime));
            BonusToken[lpToken].passBonus = passBonus.add(BonusToken[lpToken].passBonus);  
        }
        else{
            BonusToken[lpToken].passBonus = BonusToken[lpToken].totalBonus;
        }
        passBonus = BonusToken[lpToken].passBonus;
        require( BonusToken[lpToken].totalBonus.sub(passBonus) >= amount  );
        BonusToken[lpToken].timestamps = block.timestamp; 
        BonusToken[lpToken].totalBonus = BonusToken[lpToken].totalBonus.sub(amount);
        BonusToken[lpToken].lastBonus = BonusToken[lpToken].lastBonus.sub(amount);
        BonusToken[lpToken].updatePoolTime = block.timestamp;
        uint256 ismPerBlock = (BonusToken[lpToken].totalBonus.sub(passBonus)).div(BonusToken[lpToken].expirationTimestamps.sub(block.timestamp));   
        BonusToken[lpToken].ismPerBlock = ismPerBlock;  
        erc20BounsToken.safeTransfer(msg.sender, amount);
        emit SubBonusToken(msg.sender,erc20BounsToken,amount,lpToken);

        return true;
    }
    function updateBonusAmount(address lpToken,uint256 bonusAmount) private {
        BonusToken[lpToken].totalBonus = bonusAmount.add(BonusToken[lpToken].totalBonus);
        BonusToken[lpToken].lastBonus = bonusAmount.add(BonusToken[lpToken].lastBonus);
    }
    function getspacingTime(address lpToken) private view returns(uint256){
        if( BonusToken[lpToken].expirationTimestamps >= BonusToken[lpToken].lastRewardTime ){
            if( block.timestamp < BonusToken[lpToken].lastRewardTime ){
                return 0;
            }
            else{
                if(block.timestamp <= BonusToken[lpToken].expirationTimestamps){
                    return block.timestamp.sub( BonusToken[lpToken].lastRewardTime);
                }else{
                    return BonusToken[lpToken].expirationTimestamps.sub(BonusToken[lpToken].lastRewardTime);
                }
            }
        }else{
            return 0;
        }
    }
    function updateBonusShare(address lpToken) private{        
        uint256 lpSupply = BonusToken[lpToken].totallpToken;  
        if(lpSupply == 0){
            return;
        } 
        uint256 spacingTime = getspacingTime(lpToken);  
        uint256 ISMReward = spacingTime.mul(BonusToken[lpToken].ismPerBlock).mul(1e18).div(lpSupply);  
        BonusToken[lpToken].accBonusPerShare = ISMReward.add(BonusToken[lpToken].accBonusPerShare); 
     
        BonusToken[lpToken].lastRewardTime = block.timestamp;  
    }
    function deposit(address lpToken,uint256 amount) public returns(bool) {
        require(lpToken != address(0));
        require(amount >0);
        require(IERC20(lpToken).balanceOf(msg.sender) >= amount);
        updateBonusShare(lpToken);   
        uint256 bonus = 0;
        uint256 accBonusPerShare = BonusToken[lpToken].accBonusPerShare;
        if( miner[msg.sender][lpToken].amount > 0 ){
            bonus = miner[msg.sender][lpToken].amount.mul(accBonusPerShare).div(1e18);
            bonus = bonus.sub(miner[msg.sender][lpToken].rewardDebt);
        }
        if( miner[msg.sender][lpToken].lpToken == address(0) ){
            minerLpTokenList[msg.sender].push(lpToken);
        }
        uint256 rewardDebt = 0;

        minerInfo memory newminerInfo = minerInfo({
            timestamps:         block.timestamp,
            lpToken:            lpToken,
            amount:             amount.add(miner[msg.sender][lpToken].amount),
            bonus:              bonus.add(miner[msg.sender][lpToken].bonus),
            rewardDebt:         rewardDebt
        });
        miner[msg.sender][lpToken] = newminerInfo;
        miner[msg.sender][lpToken].rewardDebt = miner[msg.sender][lpToken].amount.mul(accBonusPerShare).div(1e18);  
        BonusToken[lpToken].totallpToken = amount.add(BonusToken[lpToken].totallpToken);  
        
        IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender,lpToken,amount);
        return true;
    }
    
    function withdraw(address lpToken,uint256 amount) public returns(bool){
        require(lpToken != address(0));
        require(amount >= 0);
        require(miner[msg.sender][lpToken].amount >= amount);
        require(BonusToken[lpToken].totallpToken >= amount );
        updateBonusShare(lpToken);
        uint256 bonus = 0;
        uint256 accBonusPerShare = BonusToken[lpToken].accBonusPerShare;
        if( miner[msg.sender][lpToken].amount > 0 ){
            bonus = miner[msg.sender][lpToken].amount.mul(accBonusPerShare).div(1e18);
            bonus = bonus.sub(miner[msg.sender][lpToken].rewardDebt);
        }
        miner[msg.sender][lpToken].bonus = bonus.add(miner[msg.sender][lpToken].bonus);
        miner[msg.sender][lpToken].amount = (miner[msg.sender][lpToken].amount).sub(amount);
        miner[msg.sender][lpToken].timestamps = block.timestamp;
        miner[msg.sender][lpToken].rewardDebt = miner[msg.sender][lpToken].amount.mul(accBonusPerShare).div(1e18);  

        BonusToken[lpToken].totallpToken = (BonusToken[lpToken].totallpToken).sub(amount);
        bonus = miner[msg.sender][lpToken].bonus;
        miner[msg.sender][lpToken].bonus = 0;
        BonusToken[lpToken].lastBonus = BonusToken[lpToken].lastBonus.sub(bonus);
        
        if(amount > 0 ){
            IERC20(lpToken).safeTransfer(msg.sender,amount);
        }
        if( bonus > 0 ){
            erc20BounsToken.safeTransfer(msg.sender,bonus);
        }          
        emit Withdraw(msg.sender,lpToken,amount,address(erc20BounsToken),bonus);
        return true;
    }
    function viewMinting(address who,address lpToken) public view returns (uint256){
        require(lpToken != address(0));
        uint256 bonus = 0;
        uint256 accBonusPerShare = BonusToken[lpToken].accBonusPerShare; 
        if( miner[who][lpToken].amount > 0 ){

            uint256 spacingTime = getspacingTime(lpToken);  

            uint256 lpSupply = BonusToken[lpToken].totallpToken;
            uint256 ISMReward = spacingTime.mul(BonusToken[lpToken].ismPerBlock).mul(1e18).div(lpSupply);  
            
            accBonusPerShare = accBonusPerShare.add(ISMReward);
            
            bonus = miner[who][lpToken].amount.mul(accBonusPerShare).div(1e18);
            bonus = bonus.sub(miner[who][lpToken].rewardDebt);
        }
        bonus = bonus.add(miner[who][lpToken].bonus);
        return bonus;
    }
}
