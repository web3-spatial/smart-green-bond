pragma solidity 0.4.24;

import "contracts/zeppelin/ownership/Ownable.sol";
import "contracts/zeppelin/SafeMath.sol";
import "contracts/zeppelin/ERC20/BasicToken.sol";
import "contracts/interfaces/IDAOBond.sol";

contract DAOBond is IDAOBond, Ownable {

  using SafeMath for uint256;

  string name;

  address tokenToRedeem;

  uint256 totalDebt;

  uint256 parDecimals;

  uint256 bondsNumber;

  uint256 cap;

  uint256 parValue;

  uint256 couponRate;

  uint256 term;

  uint256 timesToRedeem;

  uint256 nonce = 0;

  uint256 couponThreshold = 0;

  uint256 maxCouponsToRedeem = 0;

  BasicToken token;

  mapping(uint256 => address) bonds;
  mapping(uint256 => uint256) maturities;
  mapping(uint256 => uint256) couponsRedeemed;
  mapping(address => uint256) bondsAmount;

  constructor(string _name, uint256 _par, uint256 _parDecimals, uint256 _coupon,
              uint256 _term, uint256 _cap, uint256 _timesToRedeem, address _tokenToRedeem) {

    require(_coupon > 0);
    require(_par > 0);
    require(_timesToRedeem >= 1);

    name = _name;

    parValue = _par;

    cap = _cap;

    parDecimals = _parDecimals;

    timesToRedeem = _timesToRedeem;

    couponRate = _coupon;

    term = _term;

    couponThreshold = term / timesToRedeem;

    if (_tokenToRedeem == address(0))
      tokenToRedeem = _tokenToRedeem;

    else
      token = BasicToken(_tokenToRedeem);

  }

  function mintBond(address buyer, uint256 _bondsAmount) public onlyOwner {

    require(buyer != address(0));
    require(_bondsAmount >= 1);

    if (cap > 0)
      require(bondsNumber + _bondsAmount <= cap);

    bondsNumber = bondsNumber.add(_bondsAmount);

    nonce = nonce.add(_bondsAmount);

    for (uint256 i = 0; i < _bondsAmount; i++) {

      maturities[nonce.sub(i)] = now.add(term);
      bonds[nonce.sub(i)] = buyer;
      couponsRedeemed[nonce.sub(i)] = 0;
      bondsAmount[buyer] = bondsAmount[buyer].add(_bondsAmount);

    }

    totalDebt = totalDebt.add(parValue).add(parValue * couponRate / 100);

    emit MintedBond(buyer, _bondsAmount);

  }

  function redeemCoupons(uint256[] _bonds) public {

    require(_bonds.length > 0);

    uint256 issueDate = 0;
    uint256 lastThresholdRedeemed = 0;
    uint256 toRedeem = 0;

    for (uint256 i = 0; i < _bonds.length; i++) {

      if (bonds[_bonds[i]] != msg.sender
          || couponsRedeemed[_bonds[i]] == timesToRedeem) continue;

      issueDate = maturities[_bonds[i]].sub(term);

      lastThresholdRedeemed = issueDate.add(couponsRedeemed[_bonds[i]] * couponThreshold);

      if (lastThresholdRedeemed.add(couponThreshold) >= maturities[_bonds[i]] ||
          now < lastThresholdRedeemed.add(couponThreshold)) continue;

      toRedeem = (now.sub(lastThresholdRedeemed)) / couponThreshold;

      if (toRedeem == 0) continue;

      couponsRedeemed[_bonds[i]] = couponsRedeemed[_bonds[i]].add(toRedeem);

      getMoney( toRedeem * (parValue * couponRate / 10 ** (parDecimals + 2) ) );

      if (couponsRedeemed[_bonds[i]] == timesToRedeem) {

        bonds[_bonds[i]] = address(0);
        maturities[_bonds[i]] = 0;
        bondsAmount[msg.sender]--;

        getMoney(parValue / (10 ** parDecimals));

      }

    }

    emit RedeemedCoupons(msg.sender, _bonds);

  }

  function transfer(address receiver, uint256[] _bonds) public {

    require(_bonds.length > 0);
    require(receiver != address(0));

    for (uint256 i = 0; i < _bonds.length; i++) {

      if (bonds[_bonds[i]] != msg.sender
          || couponsRedeemed[_bonds[i]] == timesToRedeem) continue;

      bonds[_bonds[i]] = receiver;
      bondsAmount[msg.sender] = bondsAmount[msg.sender].sub(1);

    }

    emit Transferred(msg.sender, receiver, _bonds);

  }

  function() {}

  //PRIVATE

  function getMoney(uint256 amount) private {

    if (address(token) == address(0))
      msg.sender.transfer(amount);

    else
      token.transfer(msg.sender, amount);

    totalDebt = totalDebt.sub(amount);

  }

  //GETTERS

  function getLastTimeRedeemed(uint256 bond) public view returns (uint256) {

    uint256 issueDate = maturities[bond].sub(term);

    uint256 lastThresholdRedeemed = issueDate.add(couponsRedeemed[bond] * couponThreshold);

    return lastThresholdRedeemed;

  }

  function getOwner(uint256 bond) public view returns (address) {

    return bonds[bond];

  }

  function getRemainingCoupons(uint256 bond) public view returns (int256) {

    address owner = getOwner(bond);

    if (owner == address(0)) return -1;

    uint256 redeemed = getCouponsRedeemed(bond);

    return int256(timesToRedeem - redeemed);

  }

  function getCouponsRedeemed(uint256 bond) public view returns (uint256) {

    return couponsRedeemed[bond];

  }

  function getTokenAddress() public view returns (address) {

    return (address(token));

  }

  function getTimesToRedeem() public view returns (uint256) {

    return timesToRedeem;

  }

  function getTerm() public view returns (uint256) {

    return term;

  }

  function getMaturity(uint256 bond) public view returns (uint256) {

    return maturities[bond];

  }

  function getSimpleInterest() public view returns (uint256) {

    uint256 rate = getCouponRate();

    uint256 par = getParValue();

    return par * rate / 100;

  }

  function getCouponRate() public view returns (uint256) {

    return couponRate;

  }

  function getParValue() public view returns (uint256) {

    return parValue;

  }

  function getCap() public view returns (uint256) {

    return cap;

  }

  function getBondsNumber(address who) public view returns (uint256) {

    return bondsAmount[who];

  }

  function getParDecimals() public view returns (uint256) {

    return parDecimals;

  }

  function getTokenToRedeem() public view returns (address) {

    return tokenToRedeem;

  }

  function getName() public view returns (string) {

    return name;

  }

  function getTotalDebt() public view returns (uint256) {

    return totalDebt;

  }

  function getTotalBonds() public view returns (uint256) {

    return bondsNumber;

  }

  function getNonce() public view returns (uint256) {

    return nonce;

  }

  function getCouponThreshold() public view returns (uint256) {

    return couponThreshold;

  }

  function getMaxCouponsToRedeem() public view returns (uint256) {

    return maxCouponsToRedeem;

  }

}
