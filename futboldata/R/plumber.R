source(paste0(getwd(), "/R/player_stats.R"))
source(paste0(getwd(), "/R/player_urls.R"))

#' Fetch the URLs to individual player pages on fbref.com. Player lists
#' are organized by season, but we deduplicate URLs for players
#' who have played multiple seasons.
#' @param start_season First season to scrape data for. Format: YYYY-YYYY.
#' @param end_season Last season to scrape data for. Format: YYYY-YYYY.
#' @get /player_urls
function(start_season, end_season) {
  assign(
    "skipped_urls",
    NULL,
    envir = .GlobalEnv
  )

  withCallingHandlers({
      scrape_player_links(start_season, end_season) %>%
      list(data = ., error = NULL)
    },
    error = function(e) {
      print(sys.calls())

      list(
        data = list(data = NULL, skipped_urls = NULL),
        error = as.character(e)
      )
    }
  )
}

#' Fetch EPL player stats from fbref.com
#' @param player_urls List of URLs to player pages.
#' @get /player_stats
function(player_urls) {
  assign(
    "skipped_urls",
    NULL,
    envir = .GlobalEnv
  )

  withCallingHandlers({
      scrape_player_stats(player_urls) %>%
      list(data = ., error = NULL)
    },
    error = function(e) {
      print(sys.calls())

      list(
        data = list(data = NULL, skipped_urls = NULL),
        error = as.character(e)
      )
    }
  )
}
