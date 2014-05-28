# Install the quantmod package to get quote data
#install.packages("quantmod")
# Install RPostgreSQL to interact with PostgreSQL database
#install.packages("RPostgreSQL")

library("quantmod")
library("RPostgreSQL")

base_dir = "C:\\Users\\Luke\\Documents\\GitHub\\penny-algo-R"
setwd(base_dir)

source("utils.R")

# Contants
MAX_STOCKS <- 25
MAX_PRICE <- 3
MIN_PRICE <- 1
FREQ = 60

# Read the universe of penny stocks
universe = downloadStockList(Sys.Date()-1, base_dir)

# Connect to DB
drv=dbDriver("PostgreSQL")
con=dbConnect(drv, dbname="PennyAlgo", user="postgres", password="pianobookkittenmonster")

# Insert universe into Security table
ptm = proc.time()
for (i in 1:length(universe)) {
  if (i%%100 == 0) {
    print(paste0("Processed ", i ," of ", length(universe), " tickers in current universe"))
  }
  rs=dbGetQuery(con,paste0("SELECT Ticker FROM Security WHERE Ticker = '",universe[i],"'"))
  if (length(rs)==0) {
    dbSendQuery(con,paste0("INSERT INTO Security (Ticker, Active) VALUES ('", universe[i],"',TRUE)"))
  }
}
print(paste0(round((proc.time() - ptm)['elapsed']/60,1), " minutes."))

# Mark as inactive if not in file
rs = dbGetQuery(con, "SELECT Ticker FROM Security WHERE Active = TRUE");

inactive = rs$ticker[!(rs$ticker %in% universe)]

for (i in 1:length(inactive)) {
  if (i%%100 == 0) {
    print(paste0("Processed ", i ," of ", length(inactive), " tickers that are now inactive"))
  }
  dbSendQuery(con,paste0("UPDATE Security SET Active = FALSE WHERE Ticker = '", inactive[i],"'"))
}

ptm = proc.time()
universe = dbGetQuery(con,"SELECT Ticker FROM Security WHERE Active = TRUE")
updatePrices(c(universe$ticker), Sys.Date()-36, Sys.Date()-1)
print(paste0(round((proc.time() - ptm)['elapsed']/60,1), " minutes."))

universe = subset(universe, price < MAX_PRICE)

# We will rebalance the whole portfolio (sell all stocks and enter new ones) every FREQ days
# On other days, we will just exit positions that have made 50% since entering

# Which stocks should we invest in (if this is a rebalance day)
selection <- sample(1:nrow(universe),min(nrow(universe),MAX_STOCKS))

universeSelection <- universe[selection,]

print(universeSelection)