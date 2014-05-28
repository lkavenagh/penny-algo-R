dbCloseAll <- function() {
  cons = dbListConnections(PostgreSQL())
  for (con in cons) {
    if (length(dbListResults(con)) != 0) { dbClearResult(dbListResults(con)[[1]]) }
    dbDisconnect(con)
  }
}

downloadStockList = function(run_date, destDir) {
  run_date = format(as.Date(run_date), '%Y%m%d')
  q = paste0("http://bdn-ak.bloomberg.com/precanned/Equity_Common_Stock_", run_date, ".txt.zip")
  
  if (!file.exists(file.path(destDir, 'todaysStocks.zip'))) {
    download.file(q, file.path(destDir, 'todaysStocks.zip'), "internal")
  }
  
  if (length(list.files(destDir, "Equity_Common_Stock*")) == 0) {
    unzip(file.path(destDir, 'todaysStocks.zip'))
  }
  
  files = list.files(destDir, "Equity_Common_Stock*")
  symbols = ""
  for (i in 1:length(files)) {
    print(paste0("Reading file ", i, " of ", length(files)))
    tmp = read.csv(files[i], header = TRUE, sep="|", colClasses = 'character')
    symbols = c(symbols, tmp$ID_BB_SEC_NUM_DES)
  }
  
  symbols = unique(tail(symbols,-1))
  symbols = symbols[!is.na(symbols)]
  symbols = symbols[sapply(symbols, function(x)nchar(x))<=4]
  symbols = symbols[sapply(symbols, function(x)nchar(x))>=3]
  symbols = symbols[sapply(symbols, function(x)!grepl("[^a-zA-Z]", x))]
  
  file.remove(file.path(destDir, 'todaysStocks.zip'))
  file.remove(list.files(destDir, "Equity_Common_Stock*"))
  
  return(symbols)
}

updatePrices <- function(tickers, sd, ed) {
  library("quantmod")
  library("RPostgreSQL")
  
  sd = as.Date(sd)
  ed = as.Date(ed)
  stockData = new.env()
  
  # Connect to DB
  drv=dbDriver("PostgreSQL")
  con=dbConnect(drv, dbname="PennyAlgo", user="postgres", password="pianobookkittenmonster")
  
  for (i in 1:length(tickers)) {
    print(paste0("Getting history for ", tickers[i], ", ", length(tickers)-i+1, " to go."))
    tryCatch(getSymbols(tickers[i], env = stockData, src = "yahoo", from = sd, to = ed, warnings=FALSE),
             error = function(e) print(paste0(tickers[i], " not found.")))
  }
  
  if (is.null(stockData$.getSymbols)) {
    print("No data...")
    return
  }
  
  for (i in 1:length(stockData$.getSymbols)) {
    thisTicker = ls(stockData)[i]
    thisData = get(thisTicker, envir=stockData)
    print(paste0("Updating prices for ", thisTicker, ", ", length(stockData$.getSymbols)-i+1, " to go."))
    id = dbGetQuery(con, paste0("SELECT id FROM Security WHERE Ticker = '", thisTicker, "'"))
    if (length(id) > 0 & length(thisData) > 0) {
      dts = index(get(thisTicker, envir=stockData))
      op = thisData[,grep(".Open", colnames(thisData), ignore.case = TRUE)]
      cl = thisData[,grep(".Close", colnames(thisData), ignore.case = TRUE)]
      q = paste0("SELECT date FROM price WHERE securityId = ", id)
      tmp = dbGetQuery(con, q)
      idx = !(dts %in% tmp$date)
      dts = dts[idx]; op = op[idx]; cl = cl[idx]
      if (length(dts) == 0) {
        print("No updates necessary")
        next
      }
      for (j in 1:length(dts)) {
        tmp = dbGetQuery(con, paste0("SELECT * FROM price WHERE securityId = ", id, " AND date = '", dts[j], "'"))
        if (length(tmp) == 0) {
          q = paste0("INSERT INTO price (securityId, date, open_price, close_price) VALUES (", id, ",'", dts[j], "',", op[j], ",", cl[j], ")")
          dbSendQuery(con, q)
        }
      }
    } else {
      print("No data.")
    }
    
  }
}