source(paste0(getwd(), "/R/hello.R"))
source(paste0(getwd(), "/R/player_stats.R"))

#' Say hello to somebody
#' @param name Name of the recipient of the salutation
#' @get /hello
function(name = "") {
  hello(name) %>%
    jsonlite::toJSON(.)
}

#' Fetch the URLs to individual player pages on fbref.com. Player lists
#' are organized by season, but we deduplicate URLs for players
#' who have played multiple seasons.
#' @param start_season First season to scrape data for. Format: YYYY-YYYY.
#' @param end_season Last season to scrape data for. Format: YYYY-YYYY.
#' @get /player_urls
function(start_season, end_season) {
  tryCatchLog::tryCatchLog(
    {
      scrape_player_links(start_season, end_season) %>%
      list(data = ., error = NULL)
    },
    error = function(e) {
      list(
        data = list(data = NULL, skipped_player_urls = NULL, skipped_match_urls = NULL),
        error = as.character(e)
      )
    }
  )
}

#' Fetch EPL player stats from fbref.com
#' @param player_urls List of URLs to player pages.
#' @get /player_stats
function(player_urls) {
  tryCatchLog::tryCatchLog(
    {
      scrape_player_stats(player_urls) %>%
      list(data = ., error = NULL)
    },
    error = function(e) {
      list(
        data = list(data = NULL, skipped_player_urls = NULL, skipped_match_urls = NULL),
        error = as.character(e)
      )
    }
  )
}
