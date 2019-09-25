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
#' @param start_season First season to scrape data for. Format: YYYY-YYYY.
#' @param end_season Last season to scrape data for. Format: YYYY-YYYY.
#' @get /player_stats
function(start_season, end_season) {
  scrape_player_stats(start_season, end_season) %>%
  jsonlite::toJSON(.)
}
