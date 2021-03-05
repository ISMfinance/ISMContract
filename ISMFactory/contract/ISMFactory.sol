pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;
import "./Ownable.sol";
import "./InitializableAdminUpgradeabilityProxy.sol";
import "./Create2.sol";
import './IISMFactory.sol';
import './IERC20.sol';
import './IISMERC20.sol';
import './SafeMath.sol';
import "./SafeERC20.sol";


contract ISMFactory is Ownable {
    address     public  ISMERC20Implementation;
    bytes4 private constant ISMRERC20_INIT_SIGNITURE = bytes4(keccak256("initialize(string)"));
    constructor(
        address _ISMERC20Implementation
    ){
        initializeOwner();
        ISMERC20Implementation  =   _ISMERC20Implementation;
    }
    event AddProtocol(address protocolAddress,address coverAddress);
    event Addproduct(address who,address protocolAddress,address productAddress);
    event CreateToken(address who,address tokenAddress);
    event CreatePremiumToken(address who,address productAddress,address CLAIMAddr, address UNCLAIMAddr);
    event LogISMPolicyUpdated(address ISMPolicy);
    event SetProtocols(address who,address protocolAddress,bool active);
    event Setproduct(address who,address productAddress,bool active);
    event LogISMActuaryUpdated(address ISMActuary);

    struct protocolInfo{
        uint256     timestamps;
        string      protocolName;
        address     coverAddress;                    
        uint256     coverdecimals;                  
        bool        active;
    }
    mapping(address => protocolInfo)  protocols;
    mapping(string =>address)  protocolNames;
    address [] private protocolAddress;
    struct productInfoHead{
        address     protocolAddress;                
        string      productName;                    
        address     coverAddress;                    
        uint256     coverdecimals;                      
        uint48      expirationTimestamps;           
        string      expirationTimestampsName;
        uint        noice;
        address     collateral;                         
        uint256     collateralPrice;                     
        uint        collateraldecimals;                   
        bool        usdtType;
    }
    struct productInfo{
        productInfoHead     productHead; 
        uint256             timestamps;
        bool                active;
        address             productAddress;
        address             CLAIMTOKEN;
        address             UNCLAIMTOKEN;
    }
    struct collateralInfo{
        uint256     timestamps;
        address     collateral;
        string      symbol;
        uint256     decimals;
        uint256     collateralTotal;
    }
    mapping(address=>collateralInfo)  stcollateral;
    mapping(address=>productInfo) products;
    mapping(string=>address) productNames;
    mapping(address =>address[])  protocolProductAdddress;
    mapping (address => productTokenInfo) productTokens;
    address [] collaterallist;
    struct productTokenInfo{
        address     productAddress;
        uint256     timestamps;
        address     CLAIMTOKEN;
        address     UNCLAIMTOKEN;
    }
    address public ISMPolicy;

    modifier onlyISMPolicy() {
        require(msg.sender == ISMPolicy);
        _;
    }
    /**
     * @param ISMPolicy_ The address of the monetary policy contract to use for authentication.
     */
    function setISMPolicy(address ISMPolicy_)
        external
        onlyOwner
    {
        ISMPolicy = ISMPolicy_;
        emit LogISMPolicyUpdated(ISMPolicy);
    }
    address public ISMActuary;

    modifier onlyISMActuary() {
        require(msg.sender == ISMActuary || msg.sender == owner() );
        _;
    }
    /**
     * @param ISMActuary_ The address of the monetary Actuary contract to use for authentication.
     */
    function setISMActuary(address ISMActuary_)
        external
        onlyOwner
    {
        ISMActuary = ISMActuary_;
        emit LogISMActuaryUpdated(ISMPolicy);
    }

    function addcollateral(address collateral ) public onlyISMActuary returns(bool){
        require(collateral != address(0));
        require(stcollateral[collateral].collateral == address(0));
        collateralInfo memory newcollateralInfo = collateralInfo({
            timestamps:         block.timestamp,
            collateral:         collateral,
            symbol:             IERC20(collateral).symbol(),
            decimals:           IERC20(collateral).decimals(),
            collateralTotal:    0
        });
        collaterallist.push(collateral);
        stcollateral[collateral]= newcollateralInfo;
    } 
    function getcollaterallist() public view returns(uint256){
        return collaterallist.length;
    }
    function getcollaterallistData(uint256 index) public view returns(address) {
        require(index < collaterallist.length ) ;
        return collaterallist[index];
    }
    function getcollateral(address collateral) public view returns(collateralInfo memory){
        require(collateral != address(0));
        return stcollateral[collateral];
    }
    function getprotocolProductAdddress(address addr) public view returns(uint){
        return protocolProductAdddress[addr].length;
    }
    function getprotocolProductAdddressData(address addr,uint index) public view returns(address){
        require(index < protocolProductAdddress[addr].length);
        return protocolProductAdddress[addr][index];
    }
    function getproducts(address addr) public view returns(productInfo memory){
        require(addr != address(0));
        return products[addr];
    }
    function getprotocolAddress() public view returns(uint){
        return protocolAddress.length;
    }
    function getprotocolAddressData(uint index) public view returns(address){
        require(index < protocolAddress.length);
        return protocolAddress[index];
    }
    function computeAddress(bytes32 salt, address deployer) private pure returns (address) {
        bytes memory bytecode = type(InitializableAdminUpgradeabilityProxy).creationCode;
        return Create2.computeAddress(salt, keccak256(bytecode), deployer);
    }
    function getProtocols(address addr) public view returns(protocolInfo memory){
        require(addr != address(0));
        return protocols[addr];
    } 
    function getAddress(string memory name) private view returns(address){
        bytes32 salt = keccak256(abi.encodePacked(name,block.timestamp,block.number,block.difficulty));
        return computeAddress(salt, address(this));
    }
    function getProtocolAddr(string memory name) private view returns(address){
        bytes32 salt = keccak256(abi.encodePacked(name));
        return computeAddress(salt, address(this));
    }
    function getproductTokens(address productAddress) public view returns(productTokenInfo memory){
        require(productAddress != address(0));
        return productTokens[productAddress];
    }
    function addProtocols(string memory protocolName,address coverAddress,uint256 coverdecimals )  public onlyISMActuary returns(address){
        require( protocolNames[protocolName] == address(0) );
        address addr =  getProtocolAddr(protocolName);
        protocolInfo memory newprotocolInfo = protocolInfo({
            timestamps      : block.timestamp,
            protocolName    : protocolName,
            coverAddress    : coverAddress,
            coverdecimals   : coverdecimals,
            active          : true
        });
        protocols[addr] = newprotocolInfo;
        protocolNames[protocolName] = addr;
        protocolAddress.push(addr);
        emit AddProtocol(addr,coverAddress);
        return addr;
    }
    function setProtocols(address protocolAddress,bool active) public onlyISMActuary returns(bool){
        require(protocolAddress != address(0));
        protocols[protocolAddress].active = active;
        emit SetProtocols(msg.sender,protocolAddress,active);
        return true;
    }  
    function addproduct(productInfoHead memory productHead) public onlyISMActuary returns(address){
        require(productHead.protocolAddress != address(0));
        require(productNames[productHead.productName] == address(0));
        require(protocols[productHead.protocolAddress].timestamps != 0 );  
        require(protocols[productHead.protocolAddress].active);  
        require(stcollateral[productHead.collateral].collateral == productHead.collateral );  

        address addr = getAddress(productHead.productName);
        productInfo memory newproductInfo = productInfo({
            productHead:        productHead,
            timestamps:         block.timestamp,
            active:             true,
            productAddress:     addr,
            CLAIMTOKEN:         address(0),    
            UNCLAIMTOKEN:       address(0)    
        });
        newproductInfo.productHead.coverAddress = protocols[productHead.protocolAddress].coverAddress;
        newproductInfo.productHead.coverdecimals = protocols[productHead.protocolAddress].coverdecimals;
        newproductInfo.productHead.collateraldecimals = IERC20(productHead.collateral).decimals();

        products[addr] = newproductInfo;
        productNames[productHead.productName] = addr;
        protocolProductAdddress[productHead.protocolAddress].push(addr);

        emit Addproduct(msg.sender,productHead.protocolAddress,addr);
        createPremiumToken(addr);
        return addr;
    } 
    function setproduct(address productAddress,bool active) public onlyISMActuary returns(bool){
        require(productAddress != address(0));
        products[productAddress].active = active; 
        emit Setproduct(msg.sender,productAddress,active);
        return true;
    }
    function createToken(address productAddress,string memory name) private returns(address){
        string memory productName = products[productAddress].productHead.productName;
        bytes memory byteCode = type(InitializableAdminUpgradeabilityProxy).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(products[productAddress].productHead.productName,
                    products[productAddress].productHead.expirationTimestamps,products[productAddress].productHead.noice,name));
        address payable proxyAddr = Create2.deploy(0, salt, byteCode);
        bytes memory initData = abi.encodeWithSelector(ISMRERC20_INIT_SIGNITURE,string(abi.encodePacked(productName,"_",name))); 
        InitializableAdminUpgradeabilityProxy(proxyAddr).initialize(
            ISMERC20Implementation,
            address(this),
            initData);
        emit CreateToken(msg.sender,proxyAddr);
        return proxyAddr;
    }
    function createPremiumToken(address productAddress) public onlyISMActuary returns (bool){
        require(productAddress != address(0));
        require(products[productAddress].active);

        require(productTokens[productAddress].productAddress == address(0));
        

        address CLAIMAddr =  createToken(productAddress,"CLAIM");
        address UNCLAIMAddr = createToken(productAddress,"UNCLAIM");
        productTokenInfo memory newproductTokenInfo = productTokenInfo({
            productAddress:         productAddress,
            timestamps:             block.timestamp,
            CLAIMTOKEN:             CLAIMAddr,
            UNCLAIMTOKEN:           UNCLAIMAddr
        });
        productTokens[productAddress] = newproductTokenInfo;
        products[productAddress].CLAIMTOKEN = CLAIMAddr;
        products[productAddress].UNCLAIMTOKEN = UNCLAIMAddr;
        emit CreatePremiumToken(msg.sender,productAddress,CLAIMAddr,UNCLAIMAddr);
        return true;
    }
 
    function mintClaimAndUnclaim(address token,address who,uint256 amount) public onlyISMPolicy returns(bool){
        require(token != address(0));
        require(who != address(0));
        require(amount >0);
        IISMERC20(token).mint(who,amount);
        return true;
    }
    function burnClaimAndUnclaim(address token, address who,uint256 amount) public onlyISMPolicy returns(bool){
        require(token != address(0));
        require(who != address(0));
        require(amount >0);
        IISMERC20(token).burn(who,amount);
        return true;
    } 
    function getexpirationTimestamps(address productAddress) public view returns(uint256){
        require(productAddress != address(0));
        uint256 expirationTimestamps = products[productAddress].productHead.expirationTimestamps;
        return expirationTimestamps;
    }
    function getexpirationTimestampsAndName(address productAddress) public view returns(uint256,string memory,string memory){
        require(productAddress != address(0));
        uint256 expirationTimestamps = products[productAddress].productHead.expirationTimestamps;
        string memory name = products[productAddress].productHead.productName;
        string memory protocolName = protocols[ products[productAddress].productHead.protocolAddress ].protocolName;
        return (expirationTimestamps,name,protocolName);
    }
}

contract ISMContract is Ownable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20      public  USDT;
    uint16      public  redeemFeeNumerator;  
    uint16      public  redeemFeeDenominator;  
    uint256     public  base1e18 = 1e18;
    ISMFactory  public  ismFactory;
    
    constructor(ISMFactory _ISMFactory){
        initializeOwner();
        ismFactory = _ISMFactory;
        redeemFeeNumerator = 200;  
        redeemFeeDenominator = 10000;  
    }
    struct productCoverInfo{
        uint256             timestamps;
        uint256             redeemFee;
        address             collateral;
        bool                usdtType;
        uint256             allCollateralAmount;            
        uint256             collateralAmount;               
        address             CLAIMTOKEN;                  
        address             UNCLAIMTOKEN;                
        uint256             allClaimAmount;                
        uint256             claimAmount;                   
        uint256             allUnclaimAmount;               
        uint256             unclaimAmount;                  
        address             coverAddress;                
        uint256             allCoverAmount;                
        uint256             coverAmount;                                          
    }
    mapping(address=>productCoverInfo) productCovers;
    mapping (address=>uint256) collateralTotal;
    mapping (address=>bool) collateralStatus;
    address [] collateralList;
    mapping(address=>uint256) TotalRedeemFee;

    event Addcollateral(address who,address productAddress,address collateral,uint256 amount);
    event RedeemCollateral(address who,address productAddres,uint256 amount ,address collateral,uint256 collateralAmount);
    event RedeemClaim(address who,address productAddress,address CLAIMTOKEN,uint256 amount,address coverAddress,uint256 coverAmount);
    event RedeemUnClaim(address who,address productAddress,address collateral,uint256 collateralAmount,address coverAddress,uint256 coverAmount); 
    event TakeRedeemFee(address who,address collateral,uint256 redeemFee);
    
    function getcollateralTotal(address collateral) public view returns(uint256){
        require(collateral != address(0));
        return collateralTotal[collateral];
    }
    function getcollateralList() public view returns(uint256){
        return collateralList.length;
    }
    function getcollateralListData(uint256 index) public view returns(address){
        require(index < collateralList.length);
        return collateralList[index];
    }
    function getredeemFeeNumerator() public view returns(uint){
        return redeemFeeNumerator;
    } 
    function setredeemFeeNumerator(uint16 _number) public onlyOwner returns(bool){
        require(_number>0);
        redeemFeeNumerator = _number;
        return true;
    }
    function getredeemFeeDenominator() public view returns(uint) {
        return redeemFeeDenominator;        
    }
    function setredeemFeeDenominator(uint16 _number) public onlyOwner  returns(bool){
        require(_number>0);
        redeemFeeDenominator = _number;
        return true;
    }
    function getproductCovers(address productAddress) public view returns(productCoverInfo memory){
        require(productAddress != address(0));
        return productCovers[productAddress];
    }
    function calculatecollateralAmount(address productAddress,uint256 amount) public view returns(uint256){
        uint256 collateraldecimals = ismFactory.getproducts(productAddress).productHead.collateraldecimals;
        uint256 claimdecimals = 18;
        uint256 collateralAmount =  (amount.mul(10 ** collateraldecimals)).div(10 ** claimdecimals);
        return  collateralAmount;
    }
    function calculatecoverAmount(address productAddress,uint256 amount) public view returns(uint256){
        uint256 coverdecimals = ismFactory.getproducts(productAddress).productHead.coverdecimals;
        uint256 claimdecimals = 18;
        uint256 coverAmount = (amount.mul(10 ** coverdecimals)).div(10 ** claimdecimals);
        uint256 collateralPrice = ismFactory.getproducts(productAddress).productHead.collateralPrice;
        coverAmount =  coverAmount.mul(1e18).div(collateralPrice).mul(1e6); 
        return coverAmount.div(1e18);
    }
    function calculateClaimAmount(address productAddress,uint256 amount)public view returns(uint256){
        uint256 collateraldecimals = ismFactory.getproducts(productAddress).productHead.collateraldecimals;
        uint256 claimdecimals = 18;
        uint256 claimAmount =  (amount.mul(10 ** claimdecimals)).div(10 ** collateraldecimals);
        return  claimAmount;
    }
    function addcollateral(address productAddress, uint256 amount) public returns(bool){
        require(amount >0);
        require(block.timestamp <= ismFactory.getproducts(productAddress).productHead.expirationTimestamps);
        IERC20 collateral = IERC20(ismFactory.getproducts(productAddress).productHead.collateral); 
        require( collateral.balanceOf(msg.sender) >= amount );
        require(ismFactory.getproducts(productAddress).active);
        address protocolAddress =  ismFactory.getproducts(productAddress).productHead.protocolAddress;
        require(ismFactory.getProtocols(protocolAddress).active); 
        
        if( collateralStatus[address(collateral)] == false ){
            collateralList.push(address(collateral));
            collateralStatus[address(collateral)] = true;
        }  
        uint256 collateralAmount = amount;
        uint256 claimAmount = calculateClaimAmount(productAddress,collateralAmount);
        uint256 unclaimAmout = calculateClaimAmount(productAddress,collateralAmount);
        uint256 timestamp = productCovers[productAddress].timestamps == 0 ? block.timestamp : productCovers[productAddress].timestamps;
        productCoverInfo memory newproductCoverInfo = productCoverInfo({
            timestamps:             timestamp,
            redeemFee:              productCovers[productAddress].redeemFee,
            collateral:             address(collateral),
            usdtType:               ismFactory.getproducts(productAddress).productHead.usdtType,
            allCollateralAmount:    collateralAmount.add(productCovers[productAddress].allCollateralAmount ),
            collateralAmount:       collateralAmount.add(productCovers[productAddress].collateralAmount),
            CLAIMTOKEN:             ismFactory.getproductTokens(productAddress).CLAIMTOKEN,
            UNCLAIMTOKEN:           ismFactory.getproductTokens(productAddress).UNCLAIMTOKEN,
            allClaimAmount:         claimAmount.add( productCovers[productAddress].allClaimAmount),
            claimAmount:            claimAmount.add( productCovers[productAddress].claimAmount),
            allUnclaimAmount:       unclaimAmout.add( productCovers[productAddress].allUnclaimAmount ),
            unclaimAmount:          unclaimAmout.add( productCovers[productAddress].unclaimAmount ),
            coverAddress:           ismFactory.getproducts(productAddress).productHead.coverAddress,
            allCoverAmount:         productCovers[productAddress].allCoverAmount,
            coverAmount:            productCovers[productAddress].coverAmount
        });
        productCovers[productAddress] = newproductCoverInfo;
        IERC20(collateral).safeTransferFrom(msg.sender,address(this),amount);  
        ismFactory.mintClaimAndUnclaim(ismFactory.getproductTokens(productAddress).CLAIMTOKEN, msg.sender,claimAmount );
        ismFactory.mintClaimAndUnclaim(ismFactory.getproductTokens(productAddress).UNCLAIMTOKEN, msg.sender,unclaimAmout );
        
        collateralTotal[address(collateral)] = amount.add(collateralTotal[address(collateral)]);

        emit Addcollateral(msg.sender,productAddress,address(collateral),amount);
        return true;
    }
    
    function redeemCollateral(address productAddress,uint256 amount) public returns(bool) {
        require(amount>0);
        require(block.timestamp <= ismFactory.getproducts(productAddress).productHead.expirationTimestamps);
        IERC20 CLAIMTOKEN = IERC20(productCovers[productAddress].CLAIMTOKEN);
        IERC20 UNCLAIMTOKEN = IERC20(productCovers[productAddress].UNCLAIMTOKEN);
        require(CLAIMTOKEN.balanceOf(msg.sender)>= amount);
        require(UNCLAIMTOKEN.balanceOf(msg.sender)>= amount);
        require(productCovers[productAddress].claimAmount >= amount);
        require(productCovers[productAddress].unclaimAmount >= amount);
      
        
        productCovers[productAddress].claimAmount = (productCovers[productAddress].claimAmount).sub(amount);
        productCovers[productAddress].unclaimAmount = (productCovers[productAddress].unclaimAmount).sub(amount);
        uint256 collateralAmount = calculatecollateralAmount(productAddress,amount);
        productCovers[productAddress].collateralAmount = (productCovers[productAddress].collateralAmount).sub(collateralAmount);

        uint256 redeemFee = (collateralAmount.mul(redeemFeeNumerator)).div(redeemFeeDenominator);
        productCovers[productAddress].redeemFee = redeemFee.add(productCovers[productAddress].redeemFee); 

        IERC20 collateral = IERC20(ismFactory.getproducts(productAddress).productHead.collateral);
        collateral.safeTransfer(msg.sender,collateralAmount.sub(redeemFee));  

        TotalRedeemFee[address(collateral)] = redeemFee.add(TotalRedeemFee[address(collateral)]);    
        

        collateralTotal[address(collateral)] = collateralTotal[address(collateral)].sub(collateralAmount);

        ismFactory.burnClaimAndUnclaim(ismFactory.getproductTokens(productAddress).CLAIMTOKEN, msg.sender,amount );
        ismFactory.burnClaimAndUnclaim(ismFactory.getproductTokens(productAddress).UNCLAIMTOKEN, msg.sender,amount );
        emit RedeemCollateral(msg.sender,productAddress,amount,address(collateral),collateralAmount);
        return true;
    }
    
    function redeemClaim( address productAddress,uint256 amount,uint256 coverAmount ) public payable returns(bool) {
        require(productAddress != address(0));
        require(amount >0 );
        IERC20 CLAIMTOKEN = IERC20(productCovers[productAddress].CLAIMTOKEN);
        require(CLAIMTOKEN.balanceOf(msg.sender) >= amount);
        uint256 calcoverAmount = calculatecoverAmount(productAddress,amount);  
        require(calcoverAmount == coverAmount);
        if( productCovers[productAddress].coverAddress == address(0) ){
            require(msg.value >= coverAmount);
        }else{
            IERC20(ismFactory.getproducts(productAddress).productHead.coverAddress).balanceOf(msg.sender) >= coverAmount;
            IERC20(productCovers[productAddress].coverAddress).safeTransferFrom(msg.sender, address(this),calcoverAmount); 
        }
        require(productCovers[productAddress].claimAmount >= amount);
        require(block.timestamp <= ismFactory.getproducts(productAddress).productHead.expirationTimestamps ); 
        
        productCovers[productAddress].claimAmount = (productCovers[productAddress].claimAmount).sub(amount);
        productCovers[productAddress].coverAmount =  calcoverAmount.add(productCovers[productAddress].coverAmount);
        productCovers[productAddress].allCoverAmount = calcoverAmount.add(productCovers[productAddress].allCoverAmount);
      
        uint256 collateralAmount = calculatecollateralAmount(productAddress,amount); 

        productCovers[productAddress].collateralAmount = (productCovers[productAddress].collateralAmount).sub(collateralAmount);

        uint256 redeemFee = (collateralAmount.mul(redeemFeeNumerator)).div(redeemFeeDenominator);
        productCovers[productAddress].redeemFee = redeemFee.add(productCovers[productAddress].redeemFee);  

        TotalRedeemFee[address(productCovers[productAddress].collateral)] = redeemFee.add(TotalRedeemFee[address(productCovers[productAddress].collateral)]); 
        
        IERC20(productCovers[productAddress].collateral).safeTransfer(msg.sender, collateralAmount.sub(redeemFee));

        collateralTotal[productCovers[productAddress].collateral] = collateralTotal[productCovers[productAddress].collateral].sub(collateralAmount);
        ismFactory.burnClaimAndUnclaim(productCovers[productAddress].CLAIMTOKEN, msg.sender,amount );

        emit RedeemClaim(msg.sender,productAddress,productCovers[productAddress].CLAIMTOKEN,amount,
                        productCovers[productAddress].coverAddress,calcoverAmount);
        return true;
    }
    function calculateRedeemcollateral(address productAddress,uint amount) public view returns(uint256){
        uint256 percentunclaim = amount.mul(1e18).div(productCovers[productAddress].unclaimAmount);
        uint256 collateralAmount = productCovers[productAddress].collateralAmount.mul(percentunclaim).div(1e18);
        return collateralAmount;
    }
    function calculateRedeemcover(address productAddress,uint amount) public view returns(uint256){
        uint256 percentunclaim = amount.mul(1e18).div(productCovers[productAddress].unclaimAmount);
        uint256 coveramount = productCovers[productAddress].coverAmount.mul(percentunclaim).div(1e18);
        return coveramount;
    }
    function redeemUnClaim( address productAddress,uint amount) public returns(bool){
        require(productAddress != address(0));
        require(amount >0 );
        IERC20 UNCLAIMTOKEN = IERC20(productCovers[productAddress].UNCLAIMTOKEN);
        require(UNCLAIMTOKEN.balanceOf(msg.sender)>= amount);
        require(block.timestamp > ismFactory.getproducts(productAddress).productHead.expirationTimestamps );  

        uint256 collateralAmount = calculateRedeemcollateral(productAddress,amount);
        uint256 coverAmount = calculateRedeemcover(productAddress,amount);
        productCovers[productAddress].unclaimAmount = (productCovers[productAddress].unclaimAmount).sub(amount);
        productCovers[productAddress].collateralAmount =(productCovers[productAddress].collateralAmount).sub(collateralAmount);
        productCovers[productAddress].coverAmount = (productCovers[productAddress].coverAmount).sub(coverAmount); 

        if(collateralAmount>0){
            uint256 redeemFee = (collateralAmount.mul(redeemFeeNumerator)).div(redeemFeeDenominator);
            productCovers[productAddress].redeemFee = redeemFee.add(productCovers[productAddress].redeemFee);  
            TotalRedeemFee[address(productCovers[productAddress].collateral)] = redeemFee.add(TotalRedeemFee[address(productCovers[productAddress].collateral)]);   

            IERC20(productCovers[productAddress].collateral).safeTransfer(msg.sender, collateralAmount.sub(redeemFee));
            collateralTotal[productCovers[productAddress].collateral] = collateralTotal[productCovers[productAddress].collateral].sub(collateralAmount);
        }
        if(coverAmount>0){
            if( productCovers[productAddress].coverAddress == address(0) ){
                msg.sender.transfer(coverAmount);
            }
            else{
                IERC20(productCovers[productAddress].coverAddress).safeTransfer(msg.sender, coverAmount);
            }
        }
        ismFactory.burnClaimAndUnclaim(productCovers[productAddress].UNCLAIMTOKEN, msg.sender,amount );

        emit RedeemUnClaim(msg.sender,productAddress,productCovers[productAddress].collateral,collateralAmount,
                          productCovers[productAddress].coverAddress,coverAmount);
        return true;
    }
    function takeRedeemFee(address collateral) public onlyOwner returns(bool){
        require(collateral != address(0));
        require(collateralStatus[collateral] == true);          
        uint256 redeemFee = TotalRedeemFee[collateral];
        require(redeemFee >0);
        TotalRedeemFee[collateral] = 0;
        IERC20(collateral).safeTransfer(msg.sender,redeemFee);
        emit TakeRedeemFee(msg.sender,collateral,redeemFee);
        return true;
    }
    function getRedeemFee(address collateral) public view returns(uint256){
        require(collateral != address(0));
        require(collateralStatus[collateral] == true);           
        return TotalRedeemFee[collateral];
    }            
}