# Install the quantmod package to get quote data
install.packages("quantmod")
library("quantmod")

# Contants
MAX_STOCKS <- 25
MAX_PRICE <- 0.05
FREQ = 60

# Not sure how to access the local csv file, there must be a better way than this...
setwd("R:\\Documents\\GitHub\\penny-algo-R")

# Read the universe of penny stocks
# Need to figure out how/where to just grab this from the www
universe <- read.csv("PennyList.csv",nrows=100,header=F,col.names="ticker")

# Get current prices
universe["price"] <- array(NA,2)
for (i in 1:dim(universe)[1]) {
  tmp <- getQuote(toString(universe["ticker"][i,1]))[2]
  universe["price"][i,1] <- tmp
}
universe = universe[universe["price"] < MAX_PRICE,]

# We will rebalance the whole portfolio (sell all stocks and enter new ones) every FREQ days
# On other days, we will just exit positions that have made 50% since entering

# Which stocks should we invest in (if this is a rebalance day)
selection <- sample(1:dim(universe)[1],MAX_STOCKS)

universe <- universe[selection,]