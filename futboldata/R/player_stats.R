require(RSelenium)

scrape_player_stats <- function(driver = RSelenium::rsDriver(browser = "firefox")) {
  clean_csv_strings <- function(player_name, csv_string) {
    N_HEADER_ROWS = 2

    csv_rows <- csv_string %>%
      stringr::str_split(., "\n") %>%
      unlist

    csv_header_row <- csv_rows[1:N_HEADER_ROWS] %>%
      purrr::map(~ stringr::str_split(., ",")) %>%
      purrr::pmap(paste0) %>%
      unlist %>%
      c("Player", .) %>%
      paste0(., collapse = ",")

    csv_body_rows <-  csv_rows[(N_HEADER_ROWS + 1):length(rows)] %>%
      purrr::map(~ paste0(player_name, ",", .)) %>%
      unlist

      paste0(c(csv_header_row, csv_body_rows), collapse = "\n")
  }

  get_href <- function(link_element) {
    link_element$getElementAttribute("href")
  }

  scrape_individual_match_stats <- function(browser, player_match_labels) {
    TO_CSV_BUTTON_SELECTOR <- paste0(
      "#all_kitchen_sink_matchlogs .section_heading_text .hasmore li:nth-child(4) button"
    )

    browser$navigate(player_match_labels[["url"]])

    # browser$findElement(using = "css", "#all_kitchen_sink_matchlogs .section_heading_text .hasmore li:nth-child(4) button")

    # Need to execute JS to click the button because calling $clickElement()
    # on the webElement object doesn't do anything. The selector is probably
    # more specific than it needs to be, but there are lots of tables
    # on these pages with similar markup, so there's a high risk
    # of accidentally querying for more than one intends.
    browser$executeScript(
      paste0(
        "document.querySelector('", TO_CSV_BUTTON_SELECTOR, "').click()"
      )
    )

    # FBRef are inconsistent in identifying the resulting csv elements,
    # using id="csv_ks_matchlogs_all" when there are matches
    # from international competitions present and
    # id="csv_ks_matchlogs_<some number>" when there are only matches
    # from domestic competitions. Since whether a player will have
    # international matches in a given season is variable, and we have no way
    # of knowing what the ID will be, we select for the <pre> element
    # and hope they don't start adding more than one to a page.
    csv_elements <- browser$findElements(using = "css", "pre")
    csv_element_count <- length(csv_elements)

    if (length(csv_elements) > 1) {
      stop(
        paste0(
          "Expected one <pre> element per page, but found ",
          csv_element_count,
          " on ",
          browser$getCurrentUrl()
        )
      )
    }

    clean_csv_strings(
      player_match_labels[["name"]],
      csv_elements[[1]]$getElementText()
    )
  }

  scrape_individual_player_stats <- function(browser, player_url) {
    PLAYER_NAME_SELECTOR <- "h1[itemprop='name']"
    # Selecting domestic leage matches only, because players don't always have
    # matches in international competitions (e.g. Champions League),
    # and I want to keep it relatively simple & consistent for now.
    # Might include international matches sometime later.
    DOMESTIC_COMPS_MATCH_LINK_SELECTOR <- "#all_stats_player [data-stat='matches'] a"

    browser$navigate(player_url)

    player_name <- browser$findElement(
      using = "css", PLAYER_NAME_SELECTOR
    )$getElementText()

    match_urls <- browser$findElements(
      using = "css", DOMESTIC_COMPS_MATCH_LINK_SELECTOR
    ) %>%
      purrr::map(get_href) %>%
      unlist %>%
      purrr::map(~ c(url = ., name = player_name))
  }

  PLAYER_STATS_URL = "https://fbref.com/en/comps/9/stats/Premier-League-Stats"
  PLAYER_LINK_SELECTOR = "#stats_player [data-stat='player'] a"
  STATS_COL_FILL = list(
    Min = 0,
    OffenseGls = 0,
    OffenseAst = 0,
    OffenseSh = 0,
    OffenseSoT = 0,
    OffenseCrs = 0,
    OffenseFld = 0,
    OffensePK = 0,
    OffensePKatt = 0,
    DefenseTkl = 0,
    DefenseInt = 0,
    DefenseFls = 0,
    DefenseCrdY = 0,
    DefenseCrdR = 0
  )

  browser <- driver$client

  browser$navigate(PLAYER_STATS_URL)

  stats <- browser$findElements(using = "css", PLAYER_LINK_SELECTOR) %>%
    purrr::map(get_href) %>%
    unlist %>%
    purrr::map(~ scrape_individual_player_stats(browser, .)) %>%
    unlist(., recursive = FALSE) %>%
    purrr::map(~ scrape_individual_match_stats(browser, .)) %>%
    purrr::map(readr::read_csv) %>%
    purrr::map(
      ~ dplyr::mutate(
        .,
        Min = as.numeric(Min),
        OffenseGls = as.numeric(OffenseGls),
        OffenseAst = as.numeric(OffenseAst),
        OffenseSh = as.numeric(OffenseSh),
        OffenseSoT = as.numeric(OffenseSoT),
        OffenseCrs = as.numeric(OffenseCrs),
        OffenseFld = as.numeric(OffenseFld),
        OffensePK = as.numeric(OffensePK),
        OffensePKatt = as.numeric(OffensePKatt),
        DefenseTkl = as.numeric(DefenseTkl),
        DefenseInt = as.numeric(DefenseInt),
        DefenseFls = as.numeric(DefenseFls),
        DefenseCrdY = as.numeric(DefenseCrdY),
        DefenseCrdR = as.numeric(DefenseCrdR)
      )
    ) %>%
    dplyr::bind_rows(.) %>%
    tidyr::drop_na(., Date) %>%
    tidyr::replace_na(., STATS_COL_FILL)

  driver$server$stop()

  stats
}