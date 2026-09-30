# How the AI signals work

## Data used by the models
Hourly Binance candles for BTC, ETH, BNB, SOL, XRP and ADA. Features: returns over 1, 4 and 24 hours, RSI, MACD, Bollinger Bands, ATR volatility, distance from 20 and 50 hour averages, volume ratio, taker buy ratio (share of aggressive buying), futures funding rate, the Fear and Greed Index and its 7-day change, and Bitcoin's own trend.

## What the models predict
The models label the next 24 hours as bullish (price expected to rise more than 1.5%), bearish (fall more than 1.5%) or neutral. They do not predict an exact price.

## The three models
XGBoost and LightGBM are gradient-boosted decision trees that are very strong on tabular indicator data. The GRU (Gated Recurrent Unit) is a deep-learning recurrent neural network that reads the last 48 hours as a sequence, so it can learn how a pattern developed. The final signal is a weighted ensemble: each model's probabilities are averaged, weighted by its validation score.

## How accurate it is
Models are tested on the most recent data they never saw during training (a time-based split with a gap so nothing leaks). Crypto is noisy: published studies usually report around 50 to 56 percent accuracy for direction prediction, and claims above 80 percent usually come from data leakage. Confidence is the model's probability, not a guarantee. Signals are a second opinion; always check the chart and set a stop-loss.                      