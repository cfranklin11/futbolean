source(paste0(getwd(), "/R/hello.R"))
source(paste0(getwd(), "/R/player_stats.R"))

#' Say hello to somebody
#' @param name Name of the recipient of the salutation
#' @get /hello
function(name = "") {
  hello(name) %>%
    jsonlite::toJSON(.)
}

#' Fetch EPL player stats from fbref.com
#' @get /player_stats
function() {
  scrape_player_stats %>%
  jsonlite::toJSON(.)
}
