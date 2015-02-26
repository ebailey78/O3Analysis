library(data.table)

raw_data_file <- "C:/R/o3exceedData/ozone.txt"

y <- read.csv(raw_data_file, comment.char = "", stringsAsFactors = FALSE)
y <- y[seq(nrow(y)-1), ]
colnames(y)[1] <- "STATE.CODE"

y <- y[, c("STATE.CODE", "COUNTY.CODE", "SITE.ID", "POC", "COLLECTION.DATE", "NUM.DAILY.OBS", "MAX.VALUE")]

colnames(y) <- c("STATE_CODE", "COUNTY_CODE", "SITE_ID", "POC", "DATE", "COUNT", "VALUE")

y$STATE_CODE <- as.numeric(y$STATE_CODE)

y <- y[!is.na(y$VALUE), ]
y <- y[(y$VALUE >= 0.065 | y$COUNT >= 18), ]

y$DATE <- as.Date(as.character(y$DATE), format= "%Y%m%d")
y$YEAR <- as.numeric(format(y$DATE, "%Y"))
y$MONTH <- as.numeric(format(y$DATE, "%m"))
y$DAY <- as.numeric(format(y$DATE, "%m%d"))

readings <- as.data.table(y)
setkey(readings, STATE_CODE, DAY)

save(readings, file = "data/readings.rda")