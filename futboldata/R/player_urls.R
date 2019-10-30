#' @importFrom magrittr %>%

source(paste0(getwd(), "/R/utils.R"))

.scrape_links <- function(
  start_season,
  end_season,
  player_hrefs = NULL,
  path = "/en/comps/9/stats/Premier-League-Stats",
  should_scrape = FALSE
) {
  player_link_selector <- "#stats_player [data-stat='player'] a"
  prev_button_selector <- "a.button2.prev"
  page_headline_selector <- "h1[itemprop='name']"

  url <- paste0(fbref_hostname, path)
  page <- fetch_html(url)

  if (is.null(page)) {
    return(NULL)
  }

  page_headline <- page %>%
    rvest::html_node(., page_headline_selector) %>%
    rvest::html_text(.)

  # TODO: Checking start/end seasons as characters is error-prone,
  # probably better to convert them to integers, then compare to the season
  # numbers on the current page, but this is simpler and works well enough
  # for now
  if (is.na(page_headline)) {
    should_navigate_to_prev_season <- FALSE
    at_end_season <- FALSE
  } else {
    should_navigate_to_prev_season <- page_headline %>%
      stringr::str_match(., start_season) %>%
      is.na
    at_end_season <- page_headline %>%
        stringr::str_match(., end_season) %>%
        is.character
  }

  should_scrape_this_season <- ifelse(should_scrape, TRUE, at_end_season)

  if (should_scrape_this_season) {
    this_page_player_hrefs <- page %>%
      xml2::xml_find_all(., "//comment()") %>%
      .[[grep("data-stat=\"player\"", .)]] %>%
      rvest::html_text(.) %>%
      stringr::str_replace_all(., "^\n[:space:]+|\n$", "") %>%
      xml2::read_html(.) %>%
      rvest::html_nodes(., player_link_selector) %>%
      purrr::map(~ rvest::html_attr(., "href")) %>%
      unlist
  } else {
    this_page_player_hrefs <- NULL
  }

  all_player_hrefs <- c(player_hrefs, this_page_player_hrefs) %>% unique
  # We start at the current/most-recent season and work our way back
  prev_season_path <- page %>%
    rvest::html_node(., prev_button_selector) %>%
    rvest::html_attr(., "href")

  if (should_navigate_to_prev_season && is.character(prev_season_path)) {
    return(
      .scrape_links(
        start_season,
        end_season,
        player_hrefs = all_player_hrefs,
        path = prev_season_path,
        should_scrape = should_scrape_this_season
      )
    )
  }

  all_player_hrefs
}

scrape_player_links <- function(start_season, end_season) {
  player_urls <- .scrape_links(start_season, end_season) %>%
    purrr::discard(is.null) %>%
    purrr::map(~ paste0(fbref_hostname, .)) %>%
    unlist

  list(data = player_urls, skipped_urls = unique(skipped_urls))
}
