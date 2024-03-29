library("magrittr")

options(keep.source = TRUE)
# I don't find the full call stack very useful. The compact one tells me where
# the bug is in my code, which is what really matters
options(include.full.call.stack = FALSE)

port <- as.numeric(Sys.getenv("PORT", unset = "8080"))
pr <- plumber::plumb("R/plumber.R")
pr$run(host = "0.0.0.0", port = port)
