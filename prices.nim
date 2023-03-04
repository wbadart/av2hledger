import std/httpclient
import std/json
import std/os
import std/osproc
import std/parseutils
import std/sequtils
import std/sets
import std/strformat
import std/strutils
import std/tables

const API_BASE_URL = "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY_ADJUSTED"

type APIError* = object of CatchableError


proc first_item[A, B](table: OrderedTable[A, B]): (A, B) =
  for key, value in table:
    return (key, value)


proc parse_float_expr(blob: string): float =
  discard parse_float(blob, result)


type PriceEntry = object
  date: string
  symbol: string
  price: float
func render(entry: PriceEntry): string =
  &"P {entry.date} {entry.symbol} USD {entry.price:.6f}"


proc fetch_price(client: HTTPClient, symbol, api_key: string): PriceEntry =
  let
    url = API_BASE_URL & &"&symbol={symbol}&apikey={api_key}"
    response =
      client
        .get_content(url)
        .parse_json()
  if response.contains("Error Message"):
    raise new_exception(APIError, &"API error for symbol '{symbol}'")

  let
    (latest_date, latest_data) =
      response{"Time Series (Daily)"}
        .get_fields()
        .first_item()
    latest_price = latest_data["4. close"].get_str().parse_float_expr()
  PriceEntry(date: latest_date, symbol: symbol, price: latest_price)


func parse_excludes(exclude_blob: JsonNode): HashSet[string] =
  exclude_blob
    .get_elems()
    .map(proc (x: JsonNode): string = x.get_str())
    .to_hash_set()


proc main(): void =
  let
    exclude = get_env("HLEDGER_STOCKS_EXCLUDE", "[]").parse_json().parse_excludes()
    (blob, _) = exec_cmd_ex("hledger commodities")
    commodities = blob.split('\n').to_hash_set() - exclude
    http = new_http_client()
    api_key = get_env("ALPHAVANTAGE_API_KEY")

  for commodity in commodities:
    try:
      echo http.fetch_price(commodity, api_key).render()
    except APIError as e:
      stderr.write_line(e.msg)
      stderr.flush_file()
    # limit 5 reqs/min, add .02 sec to account for slight timing differences w/ API server
    sleep(milsecs=12_020)


when isMainModule:
  main()
