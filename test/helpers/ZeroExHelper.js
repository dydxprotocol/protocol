const ZeroExExchange = artifacts.require("ZeroExExchange");
const ZeroEx = require('0x.js').ZeroEx;
const Web3 = require('web3');
const BigNumber = require('bignumber.js');
const HeldToken = artifacts.require("TokenA");
const OwedToken = artifacts.require("TokenB");
const promisify = require("es6-promisify");
const ethUtil = require('ethereumjs-util');
const { DEFAULT_SALT, ORDER_TYPE } = require('./Constants');

const web3Instance = new Web3(web3.currentProvider);

const BASE_AMOUNT = new BigNumber('1098623452345987123')

async function createSignedSellOrder(
  accounts,
  {
    salt = DEFAULT_SALT,
    feeRecipient,
  } = {}
) {
  let order = {
    type: ORDER_TYPE.ZERO_EX,
    exchangeContractAddress: ZeroExExchange.address,
    expirationUnixTimestampSec: new BigNumber(100000000000000),
    feeRecipient: feeRecipient || accounts[6],
    maker: accounts[5],
    makerFee: BASE_AMOUNT.times(0.010928345).floor(),
    salt: new BigNumber(salt),
    taker: ZeroEx.NULL_ADDRESS,
    takerFee: BASE_AMOUNT.times(0.109128341).floor(),

    // owedToken
    makerTokenAddress: OwedToken.address,
    makerTokenAmount: BASE_AMOUNT.times(6.382472).floor(),

    // heldToken
    takerTokenAddress: HeldToken.address,
    takerTokenAmount: BASE_AMOUNT.times(19.123475).floor()
  };

  order.ecSignature = await signOrder(order);

  return order;
}

async function createSignedBuyOrder(
  accounts,
  {
    salt = DEFAULT_SALT,
    feeRecipient,
  } = {}
) {
  let order = {
    type: ORDER_TYPE.ZERO_EX,
    exchangeContractAddress: ZeroExExchange.address,
    expirationUnixTimestampSec: new BigNumber(100000000000000),
    feeRecipient: feeRecipient || accounts[4],
    maker: accounts[2],
    makerFee: BASE_AMOUNT.times(.02012398).floor(),
    salt: new BigNumber(salt),
    taker: ZeroEx.NULL_ADDRESS,
    takerFee: BASE_AMOUNT.times(.1019238).floor(),

    // heldToken
    makerTokenAddress: HeldToken.address,
    makerTokenAmount: BASE_AMOUNT.times(30.091234687).floor(),

    // owedToken
    takerTokenAddress: OwedToken.address,
    takerTokenAmount: BASE_AMOUNT.times(10.092138781).floor(),
  };

  order.ecSignature = await signOrder(order);

  return order;
}

async function signOrder(order) {
  const signature = await promisify(web3Instance.eth.sign)(
    getOrderHash(order), order.maker
  );

  const { v, r, s } = ethUtil.fromRpcSig(signature);

  return {
    v,
    r: ethUtil.bufferToHex(r),
    s: ethUtil.bufferToHex(s)
  };
}

function getOrderHash(order) {
  return web3Instance.utils.soliditySha3(
    ZeroExExchange.address,
    order.maker,
    order.taker,
    order.makerTokenAddress,
    order.takerTokenAddress,
    order.feeRecipient,
    order.makerTokenAmount,
    order.takerTokenAmount,
    order.makerFee,
    order.takerFee,
    order.expirationUnixTimestampSec,
    order.salt
  )
}

module.exports = {
  createSignedSellOrder,
  createSignedBuyOrder,
  signOrder,
  getOrderHash
}
