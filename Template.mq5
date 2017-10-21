//+------------------------------------------------------------------+
//|                                                     Template.mq5 |
//|                                                      Akihiro Ito |
//|                                       http://www.peano-system.jp |
//+------------------------------------------------------------------+
#property copyright "Akihiro Ito"
#property link      "http://www.peano-system.jp"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input double leverage = 20.0;
input double periodIdx = 0;
input double periodStep = 3;
input double thresho = 100;
input double stopLoss = 300;
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//| Definitons                                                       |
//+------------------------------------------------------------------+
struct PositionStatus {
    datetime time;
    long timeMsc;
    long timeUpdate;
    long timeUpdateMsc;
    ENUM_POSITION_TYPE type;
    long magic;
    long identifier;
    double volume;
    double priceOpen;
    double sl;
    double tp;
    double priceCurrent;
    double commision;
    double swap;
    double profit;
    string symbol;
    string comment;
    int sign;
    long pips;
    long maxPips;
    long minPips;
    datetime closedAt;
};

PositionStatus pSt;
PositionStatus lSt;
int hdlr1, hdlr2;
ENUM_TIMEFRAMES period1 = 0;
ENUM_TIMEFRAMES period2 = 0;
ENUM_TIMEFRAMES period3 = 0;
int prevMagic = 0;

ENUM_TIMEFRAMES periods[] = {
    PERIOD_M1, PERIOD_M10, PERIOD_M12, PERIOD_M15,
    PERIOD_H1, PERIOD_H2, PERIOD_H3, PERIOD_H4, PERIOD_H6, PERIOD_H12,
    PERIOD_D1, PERIOD_W1, PERIOD_MN1
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    int ret = INIT_SUCCEEDED;

    period1 = periods[(int)periodIdx];
    period2 = periods[(int)(periodIdx + periodStep)];

    // check whether eleverage can be calculatable.
    string currA = AccountInfoString(ACCOUNT_CURRENCY);
    string currB = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
    string bases;
    if (currA != "JPY" && currA != "USD") {
        ret = INIT_FAILED;
    }
    if (currB != currA && !SymbolInfoString(currB + currA, SYMBOL_CURRENCY_BASE, bases)) {
        ret = INIT_FAILED;
    }

    // example of import indicators
    hdlr1 = iCustom(_Symbol, period1, "Examples\\BB", 20, 0, 1.0);
    if (hdlr1 == INVALID_HANDLE) {
        ret = INIT_FAILED;
    }
    hdlr2 = iCustom(_Symbol, period2, "Examples\\Heiken_Ashi");
    if (hdlr2 == INVALID_HANDLE) {
        ret = INIT_FAILED;
    }
    
    prevMagic = MathRand();
    return ret;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if (hdlr1 != INVALID_HANDLE) {
        IndicatorRelease(hdlr1);
    }
    if (hdlr2 != INVALID_HANDLE) {
        IndicatorRelease(hdlr2);
    }
    return;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    MqlTradeRequest req = {0};
    
    updatePositionStatus();
    // if you have no position.
    if (pSt.volume == 0.0) {
        if (judgeEntry(req)) {
            order(req);
        }
    }
    // if you have an position (buy or sell).
    else {
        if (judgeClose()) {
            CTrade t;
            t.PositionClose(_Symbol);
        }
    }
    return;
}

//+------------------------------------------------------------------+
//| judgeEntry                                                       |
//+------------------------------------------------------------------+
bool judgeEntry(MqlTradeRequest &req)
{
    bool ret = false;

    MqlTick tick = {0};
    SymbolInfoTick(_Symbol, tick);
  
    // Wirte here your own judge code.
    // This is an example.
    int tr1 = judgeTrend1();
    int tr2 = judgeTrend2();
    if (tr1 == 1 && tr2 == 1) {
        req.price = tick.ask;
        req.sl    = NormalizeDouble(tick.bid - stopLoss * _Point, _Digits);
        req.tp    = 0.0;
        req.type  = ORDER_TYPE_BUY;
        ret = true;
    }
    if (tr1 == -1 && tr2 == -1) {
        req.price = tick.bid;
        req.sl    = NormalizeDouble(tick.ask + stopLoss * _Point, _Digits);
        req.tp    = 0.0;
        req.type  = ORDER_TYPE_SELL;
        ret = true;
    }
    if (ret) {
        req.action = TRADE_ACTION_DEAL;
        req.magic  = ++prevMagic;
        req.symbol = _Symbol;
        req.volume = createLots();
        req.deviation = 20;
        req.type_filling = ORDER_FILLING_FOK;
        req.comment = "Yha!";
    }
    return ret;
}

//+------------------------------------------------------------------+
//| judgeClose                                                       |
//+------------------------------------------------------------------+
bool judgeClose()
{
    bool ret = false;
    if ((pSt.sign * judgeTrend1() == -1 && pSt.sign * judgeTrend2() == -1)) {
        ret = true;
    }
    return ret;
}

//+------------------------------------------------------------------+
//| judgeTrend1                                                      |
//+------------------------------------------------------------------+
int judgeTrend1()
{
    int tr = 0;
    double opn[1], hgh[1], low[1], cls[1];
    int oCnt, hCnt, lCnt, cCnt;
    oCnt = CopyOpen (_Symbol, period1, 0, 1, opn);
    hCnt = CopyHigh (_Symbol, period1, 0, 1, hgh);
    lCnt = CopyLow  (_Symbol, period1, 0, 1, low);
    cCnt = CopyClose(_Symbol, period1, 0, 1, cls);
    if (oCnt == 1 && hCnt == 1&& lCnt == 1 && cCnt == 1 ) {
        if ((hgh[0] - low[0]) / _Point > thresho) {
            if ((hgh[0] - cls[0]) < (cls[0]) - low[0]) {
                tr = 1;
            } else {
                tr = -1;
            }
        }
    }
    return tr;
}

//+------------------------------------------------------------------+
//| judgeTrend2                                                      |
//+------------------------------------------------------------------+
int judgeTrend2()
{
    int tr = 0;
    double opn[1], hgh[1], low[1], cls[1];
    int oCnt, hCnt, lCnt, cCnt;
    oCnt = CopyBuffer(hdlr2, 0, 0, 1, opn);
    hCnt = CopyBuffer(hdlr2, 1, 0, 1, hgh);
    lCnt = CopyBuffer(hdlr2, 2, 0, 1, low);
    cCnt = CopyBuffer(hdlr2, 3, 0, 1, cls);
    if (oCnt == 1 && hCnt == 1 && cCnt == 1 && lCnt == 1) {
        if (opn[0] - cls[0] < 0) {
            tr = 1;
        } else if (opn[0] - cls[0] > 0) {
            tr = -1;
        }
    }
    return tr;
}

//+------------------------------------------------------------------+
//| copyPositionStatus                                               |
//+------------------------------------------------------------------+
void copyPositionStatus(PositionStatus &to, PositionStatus &from)
{
    to.time          = from.time;
    to.timeMsc       = from.timeMsc;
    to.timeUpdate    = from.timeUpdate;
    to.timeUpdateMsc = from.timeUpdateMsc;
    to.type          = from.type;
    to.magic         = from.magic;
    to.identifier    = from.identifier;
    to.volume        = from.volume;
    to.priceOpen     = from.priceOpen;
    to.sl            = from.sl;
    to.tp            = from.tp;
    to.priceCurrent  = from.priceCurrent;
    to.commision     = from.commision;
    to.swap          = from.swap;
    to.profit        = from.profit;
    to.symbol        = from.symbol;
    to.comment       = from.comment;
    to.sign          = from.sign;
    to.pips          = from.pips;
    to.maxPips       = from.maxPips;
    to.minPips       = from.minPips;
    to.closedAt      = from.closedAt;
    return;
}

//+------------------------------------------------------------------+
//| updatePositionStatus                                             |
//+------------------------------------------------------------------+
void updatePositionStatus()
{
    copyPositionStatus(lSt, pSt);
    if (PositionSelect(_Symbol)) {    
        pSt.time          = (datetime)PositionGetInteger(POSITION_TIME);
        pSt.timeMsc       = PositionGetInteger(POSITION_TIME_MSC);
        pSt.timeUpdate    = PositionGetInteger(POSITION_TIME_UPDATE);
        pSt.timeUpdateMsc = PositionGetInteger(POSITION_TIME_UPDATE_MSC);
        pSt.type          = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        pSt.magic         = PositionGetInteger(POSITION_MAGIC);
        pSt.identifier    = PositionGetInteger(POSITION_IDENTIFIER);
        pSt.volume        = PositionGetDouble(POSITION_VOLUME);
        pSt.priceOpen     = lSt.volume == 0.0 ? PositionGetDouble(POSITION_PRICE_OPEN) : lSt.priceOpen;
        pSt.sl            = PositionGetDouble(POSITION_SL);
        pSt.tp            = PositionGetDouble(POSITION_TP);
        pSt.priceCurrent  = PositionGetDouble(POSITION_PRICE_CURRENT);
        pSt.commision     = PositionGetDouble(POSITION_COMMISSION);
        pSt.swap          = PositionGetDouble(POSITION_SWAP);
        pSt.profit        = PositionGetDouble(POSITION_PROFIT);
        pSt.symbol        = PositionGetString(POSITION_SYMBOL);
        pSt.comment       = PositionGetString(POSITION_COMMENT);
        pSt.sign          = pSt.type == POSITION_TYPE_BUY ? 1 : -1;
        pSt.pips          = (long)(pSt.sign * (pSt.priceCurrent - pSt.priceOpen) / _Point);
        if (pSt.maxPips < pSt.pips) {
            pSt.maxPips = pSt.pips;
        }
        if (pSt.minPips > pSt.pips) {
            pSt.minPips = pSt.pips;
        }
        pSt.closedAt      = 0;
    } else if (lSt.volume > 0.0) {
        copyPositionStatus(lSt, pSt);
        lSt.closedAt = TimeCurrent();
        pSt.time          = 0;
        pSt.timeMsc       = 0;
        pSt.timeUpdate    = 0;
        pSt.timeUpdateMsc = 0;
        pSt.type          = 0;
        pSt.magic         = 0;
        pSt.identifier    = 0;
        pSt.volume        = 0.0;
        pSt.priceOpen     = 0.0;
        pSt.sl            = 0.0;
        pSt.tp            = 0.0;
        pSt.priceCurrent  = 0.0;
        pSt.commision     = 0.0;
        pSt.swap          = 0.0;
        pSt.profit        = 0.0;
        pSt.symbol        = "";
        pSt.comment       = "";
        pSt.pips          = 0;
        pSt.maxPips       = 0;
        pSt.minPips       = 0;
        pSt.closedAt      = 0;
    }
    return;
}

//+------------------------------------------------------------------+
//| order                                                            |
//+------------------------------------------------------------------+
void order(MqlTradeRequest &req)
{
    MqlTradeCheckResult chk;
    MqlTradeResult res;
    
    if (OrderCheck(req, chk)) {
        if (OrderSend(req, res) && req.action == TRADE_ACTION_DEAL) {
            ;
        }
        Print(res.comment);
    } else {
        MqlTick tick = {0};
        SymbolInfoTick(_Symbol, tick);
    }
    return;
}

//+------------------------------------------------------------------+
//| createLots                                                       |
//+------------------------------------------------------------------+
double createLots()
{
    const int CURRS_PER_LOT = 100000;
    double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
    double profit      = AccountInfoDouble(ACCOUNT_PROFIT);
    string currA       = AccountInfoString(ACCOUNT_CURRENCY);
    string currB       = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
    string currC       = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
    double ret = 0.0;
    if (currA != "JPY") {
        double aaa_in_jpy = SymbolInfoDouble(currA + "JPY", SYMBOL_BID);
        balance *= aaa_in_jpy;
        profit  *= aaa_in_jpy;
    }
    double bbb_in_jpy = SymbolInfoDouble(currB + "JPY", SYMBOL_BID);
    double lots = NormalizeDouble((balance + profit) * leverage / (CURRS_PER_LOT * bbb_in_jpy), 2);
    ret = MathMin(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
    return ret;
}
