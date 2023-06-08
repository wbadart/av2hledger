#!/bin/bash
set -euo pipefail
API_BASE_URL="https://www.alphavantage.co/query?function=TIME_SERIES_DAILY_ADJUSTED&apikey=$ALPHAVANTAGE_API_KEY"

fetch_price() {
  curl -LsS "$API_BASE_URL&symbol=$1" \
    | jq --raw-output '.["Time Series (Daily)"] | to_entries | sort_by(.key) | last | (.value |= .["4. close"]) | .key, .value' 2>/dev/null
}

hledger commodities | grep -Pv "${LEDGER_STOCKS_EXCLUDE:-^$}" | while read -r SYMBOL; do
  fetch_price "$SYMBOL" | xargs --no-run-if-empty printf "P %s $SYMBOL USD %f\n" || echo "Failed to fetch price for symbol '$SYMBOL'." >&2
  sleep 13  # 5 requests per minute, plus a little buffer
done
