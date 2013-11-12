# Install the quantmod package to get quote data
#install.packages("quantmod")
# Install RPostgreSQL to interact with PostgreSQL database
#install.packages("RPostgreSQL")

library("quantmod")
library("RPostgreSQL")

# Contants
MAX_STOCKS = 25
MAX_PRICE = 0.05
FREQ = 60
TICKER_LIST_LOC = "http://www.otcmarkets.com/reports/symbol_info.csv"

# Not sure how to access the local csv file, there must be a better way than this...
#setwd("R:\\Documents\\GitHub\\penny-algo-R")
#setwd("C:\\Users\\Luke\\Documents\\GitHub\\penny-algo-R")

# Read the universe of penny stocks
# Need to figure out how/where to just grab this from the www
download.file(TICKER_LIST_LOC, "PennyList.csv", "internal")
universe = read.csv("PennyList.csv",header=T)
universe = universe[universe$OTC.Tier == "OTC Pink Current",]
universe = universe[universe$Security.Type == "Common Stock",]

# Connect to DB
drv=dbDriver("PostgreSQL")
con=dbConnect(drv, dbname="PennyAlgo", user="postgres", password="pianobookkittenmonster")

# Insert universe into Security table
for (i in universe$Symbol) {
  rs=dbGetQuery(con,paste("SELECT Ticker FROM Security WHERE Ticker = '",i,"'",sep=""))
  if (length(rs)==0) {
    dbSendQuery(con,paste("INSERT INTO Security (Ticker, Active) VALUES ('",i,"',TRUE)",sep=""))
  }
}

# Mark as inactive if not in file
rs = dbGetQuery(con, "SELECT Ticker FROM Security");

inactive = rs$ticker[!(rs$ticker %in% universe$Symbol)]

for (i in inactive) {
  dbSendQuery(con,paste("UPDATE Security SET Active = FALSE WHERE Ticker = '",i,"'",sep=""))
}

# Get current prices
universe = dbGetQuery(con,"SELECT Ticker FROM Security WHERE Active = TRUE")
universe$price <- array(NA,length(universe$Symbol))
for (i in universe$Symbol) {
  tmp <- getQuote(i)
  universe$price[universe$Symbol==i] <- tmp$Last
}

universe = subset(universe, price < MAX_PRICE)

# We will rebalance the whole portfolio (sell all stocks and enter new ones) every FREQ days
# On other days, we will just exit positions that have made 50% since entering

# Which stocks should we invest in (if this is a rebalance day)
selection <- sample(1:nrow(universe),min(nrow(universe),MAX_STOCKS))

universeSelection <- universe[selection,]

print(universeSelection)