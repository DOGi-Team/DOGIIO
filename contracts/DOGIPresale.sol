pragma solidity ^0.4.18;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}

// dogi crowdsale main contract
contract DogiPresale is Pausable {
  using SafeMath for uint256;

  // sell item struct
  struct RewardItem {
    bool exist;
    bool paused; // is paused
    string id; // item id
    uint256 price; // item price
    uint256 stock; // 库存数量 为0表示不限制数量
    uint256 soldCount; // 已售数量
    uint256 startTime; // 发售开始时间
    uint256 endTime; // 发售结束时间
  }

  // 购买记录数据结构
  struct BuyRecord {
    string itemId; // 购买的itemId
    address buyer; // 购买人账号
    bool refund; // 是否已退款
    uint256 amount; // 金额
  }

  /**
  开发者编辑字段 Part 1
  ----------------start----------------
  **/

  // Address where funds are collected
  address public wallet = 0x531a05a10259EbD3885880FC3a522A45dF2C9A53;

  // 合约发布者名称
  string public ownerName = "Owner Name";

  // 筹集目标 单位:wei
  uint256 public goal = 10 ether;

  // 预售开始时间 使用时间戳
  uint256 public startTime = now;

  // 预售截止时间 使用时间戳
  uint256 public endTime = now + 30 days;

  /**
  ----------------end----------------
  开发者编辑字段 Part 1
  **/

   // 当前筹集金额
  uint256 public weiRaised;

  // 众筹是否成功
  bool public fundingGoalReached = false;

  // 是否已提款
  bool public isWithdrawed = false;

  // 奖励项目集合 项目id -> 项目
  mapping (string => RewardItem) rewardItems;

  // 投资记录  订单号 -> 购买信息
  mapping (string => BuyRecord) buyRecordOf;

  // 投资人金额集合 投资人账号 -> 已投金额
  mapping(address => uint256) public balanceOf;

  // 投资人数
  uint256 public buyAddressCount;

  event TokenPurchase(address indexed purchaser, uint256 value, string itemId);

  event Withdraw(address sender, uint amount);

  event TransferTokenId(address _address, uint256 tokenId);

  event Refund(address _address, uint256 amount);


  modifier afterDeadline() {
    require(now >= endTime);
    _;
  }

  modifier beforeDeadline() {
    require(now < endTime);
    _;
  }

  modifier onlyWallet() {
      require(msg.sender == wallet);
      _;
  }

  modifier onlyFundingSuccess() {
      require(fundingGoalReached);
      _;
  }

  modifier onlyFundingFail() {
      require(!fundingGoalReached);
      _;
  }

  /**
  开发者编辑字段 Part 2
  ----------------start----------------
  **/

  constructor() public {
    owner = msg.sender;
    //请使用以下方法添加项目回报，务必保持和dogi.io网站中提交的回报数据一致
    addRewardItem("001", 1000, 100, 0, 0);
    addRewardItem("002", 1000, 100, 0, 0);
  }

  /**
  ----------------end----------------
  开发者编辑字段 Part 2
  **/

  /**
    * 添加项目回报
    * _rewardItemId：回报标识
    * _price：回报价格 单位wei
    * _count：数量限制 0为无限制
    * _startTime：开始时间，0为无限制
    * _endTime：结束时间，0为无限制
    **/
  function addRewardItem(string _rewardItemId, uint256 _price, uint256 _count, uint256 _startTime, uint256 _endTime) internal {
    require(_price >= uint(0) && _count >= uint(0));
    RewardItem memory _item = RewardItem({
      exist:true,
      paused: false,
      id: _rewardItemId,
      price: _price,
      stock: _count,
      soldCount: 0,
      startTime: _startTime,
      endTime: _endTime
    });
    rewardItems[_rewardItemId] = _item;
  }

  function getRewardItem(string _rewardItemId) public constant returns (bool paused_, string id_,
    uint256 price_, uint256 stock_, uint256 soldCount_, uint256 startTime_, uint256 endTime_) {
    paused_ = rewardItems[_rewardItemId].paused;
    id_ = rewardItems[_rewardItemId].id;
    price_ = rewardItems[_rewardItemId].price;
    stock_ = rewardItems[_rewardItemId].stock;
    soldCount_ = rewardItems[_rewardItemId].soldCount;
    startTime_ = rewardItems[_rewardItemId].startTime;
    endTime_ = rewardItems[_rewardItemId].endTime;
  }

  
  /**
  *  获取购买记录
  *  _orderId:dogi官网生成的订单id
  */
  function getBuyRecord(string _orderId) public constant returns (string itemId_,
    address buyer_, bool refund_, uint256 amount_) {
    itemId_ = buyRecordOf[_orderId].itemId;
    buyer_ = buyRecordOf[_orderId].buyer;
    refund_ = buyRecordOf[_orderId].refund;
    amount_ = buyRecordOf[_orderId].amount;
  }


  /**
  *  购买商品接口
  *  _orderId:dogi官网生成的订单id
  *  _rewardItemId:商品标识
  */
  function buyTokens(string _orderId, string _rewardItemId) public payable whenNotPaused beforeDeadline {

    BuyRecord memory buyRecord = buyRecordOf[_orderId];
    require(buyRecord.amount == 0);

    uint256 weiAmount = msg.value;

    RewardItem storage item = rewardItems[_rewardItemId];
    _preValidatePurchase(msg.sender, weiAmount, item);

    weiRaised = weiRaised.add(item.price);

    buyAddressCount = buyAddressCount.add(1);

    balanceOf[msg.sender] = balanceOf[msg.sender].add(item.price);

    item.soldCount = item.soldCount.add(1);

    if (weiAmount > item.price) {
      msg.sender.transfer(weiAmount.sub(item.price));
    }

    _processPurchase(_orderId, msg.sender, item.id, item.price);

    emit TokenPurchase(msg.sender, weiAmount, item.id);

    if (!fundingGoalReached && weiRaised >= goal) {
        fundingGoalReached = true;
    }
  }

  // validate
  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount, RewardItem item) view internal {
    require(_beneficiary >= address(0));
    require(_weiAmount >= 0);
    require(item.exist);
    require(!item.paused);
    require(now >= item.startTime);
    require(item.endTime == 0 || now < item.endTime);
    require(item.stock == 0 || (item.stock > item.soldCount));
    require(item.price >= 0 && _weiAmount >= item.price );
  }

  function _processPurchase(string _orderId, address _beneficiary, string _itemId, uint256 _price) internal {
    _recordPurchase(_orderId, _beneficiary, _itemId, _price);
  }

  function _recordPurchase(string _orderId, address _beneficiary, string _itemId, uint256 _price) internal {
    BuyRecord memory _record = BuyRecord({
        itemId: _itemId,
        buyer: _beneficiary,
        refund: false,
        amount: _price
    });
    buyRecordOf[_orderId] = _record;
  }

  /**
  *  提现接口，发布合约的账户可以提取
  */
  function safeWithdrawal() public whenNotPaused onlyOwner onlyFundingSuccess afterDeadline {
    require(!isWithdrawed);
    isWithdrawed = true;
    wallet.transfer(weiRaised);
    emit Withdraw(wallet, weiRaised);
  }

  /**
  *   退款接口，用户退款，必须众筹结束，并且失败由购买者调用
  *   orderId：dogi官网生成的订单id
  */
  function refund(string _orderId) public whenNotPaused afterDeadline onlyFundingFail {
    BuyRecord storage record = buyRecordOf[_orderId];
    require(msg.sender == record.buyer);
    require(!record.refund && record.amount != 0);
    require(balanceOf[record.buyer] > 0);
    record.refund = true;
    uint amount = record.amount;
    record.buyer.transfer(amount);
    balanceOf[record.buyer] = balanceOf[record.buyer].sub(amount);
    emit Refund(record.buyer, amount);
  }
}
