require(RSelenium)

scrape_player_stats <- function(driver = RSelenium::rsDriver(browser = "firefox")) {
  assert_regex_matches <- function(player_position_match_groups, expected_match_group_count) {
    if (length(player_position_match_groups) == expected_match_group_count) {
      return()
    }

    invalid_matches <- paste0(player_position_match_groups, collapse = ",")

    stop(
      paste0(
        "Expected regex to match with one capturing group, but got the following ",
        "match groups instead:\n",
        invalid_matches
      )
    )
  }

  # RSelenium silently fails when you tell it to navigate to a junk URL,
  # staying on the same page and resulting in a difficult-to-understand error
  # getting raised later
  assert_browser_at_navigated_url <- function(browser, url) {
    current_url <- browser$getCurrentUrl()

    if (current_url == url) {
      return()
    }

    # Sometimes the source of the bug is passing a vector or list as the URL,
    # which we want to collapse for a readable error message; otherwise,
    # paste0 iterates over it
    invalid_url <- paste0(url, collapse = ", ")

    stop(
      paste0(
        "Expected current URL to be ", invalid_url, ",\n",
        "but instead the browser is at ", current_url
      )
    )
  }

  get_href <- function(link_element) {
    link_element$getElementAttribute("href")
  }

  clean_csv_strings <- function(player_info, csv_string) {
    N_HEADER_ROWS = 2

    csv_rows <- csv_string %>%
      stringr::str_split(., "\n") %>%
      unlist

    csv_header_row <- csv_rows[1:N_HEADER_ROWS] %>%
      purrr::map(~ stringr::str_split(., ",")) %>%
      purrr::pmap(paste0) %>%
      unlist %>%
      c(player_info[["player_cols"]], .) %>%
      paste0(., collapse = ",") %>%
      # I don't really like how spaces look in col labels, and most of the labels
      # are in pascal case anyway
      stringr::str_replace_all(., " ", "")

    non_table_values <- c(player_info[["player_values"]])
    player_values <- paste0(non_table_values, collapse = ",")

    csv_body_rows <-  csv_rows[(N_HEADER_ROWS + 1):length(csv_rows)] %>%
      purrr::map(~ paste0(player_values, ",", .)) %>%
      unlist

    paste0(c(csv_header_row, csv_body_rows), collapse = "\n")
  }

  # Not all players have a full name field in their info section, which shifts
  # all later fields up the page by one (i.e. down by one in terms of index number)
  n_indices_to_shift_by <- function(player_info_elements) {
    DEFAULT_PLAYER_INFO_ELEMENT_COUNT <- 6
    NO_SHIFT <- 0
    SHIFT_UP_BY_ONE <- -1

    if (length(player_info_elements) == DEFAULT_PLAYER_INFO_ELEMENT_COUNT) {
      return(NO_SHIFT)
    }

    SHIFT_UP_BY_ONE
  }

  scrape_player_national_team <- function(player_info_elements, match_group_index) {
    DEFAULT_NATIONAL_TEAM_INDEX <- 5
    NATIONAL_TEAM_REGEX <- "National Team: (.+) [:alpha:]{2}"

    national_team_index <- DEFAULT_NATIONAL_TEAM_INDEX + n_indices_to_shift_by(player_info_elements)
    national_team_element <- player_info_elements[[national_team_index]]

    national_team_match_groups <- national_team_element$getElementText() %>%
      stringr::str_match(NATIONAL_TEAM_REGEX)

    assert_regex_matches(national_team_match_groups, match_group_index)

    national_team_match_groups[[match_group_index]]
  }

  scrape_player_birthdate <- function(player_info_elements, match_group_index) {
    DEFAULT_BIRTHDATE_INDEX <- 4
    BIRTHDATE_REGEX <- "Born: ([:alpha:]+ [:digit:]{1,2}, [:digit:]{4})"

    birthdate_index <- DEFAULT_BIRTHDATE_INDEX + n_indices_to_shift_by(player_info_elements)
    birthdate_element <- player_info_elements[[birthdate_index]]

    birthdate_match_groups <- birthdate_element$getElementText() %>%
      stringr::str_match(BIRTHDATE_REGEX)

    assert_regex_matches(birthdate_match_groups, match_group_index)

    birthdate_match_groups[[match_group_index]]
  }

  scrape_player_height_weight <- function(player_info_elements, match_group_index) {
    DEFAULT_HEIGHT_WEIGHT_INDEX <- 3
    HEIGHT_WEIGHT_REGEX <- "([:digit:]+cm, [:digit:]+kg)"

    height_weight_index <- DEFAULT_HEIGHT_WEIGHT_INDEX + n_indices_to_shift_by(player_info_elements)
    height_weight_element <- player_info_elements[[height_weight_index]]

    height_weight_match_groups <- height_weight_element$getElementText() %>%
      stringr::str_match(HEIGHT_WEIGHT_REGEX)

    assert_regex_matches(height_weight_match_groups, match_group_index)

    height_weight_match_groups[[match_group_index]] %>%
      stringr::str_replace_all(., "[:alpha:]", "") %>%
      stringr::str_split(., ", ") %>%
      unlist
  }

  scrape_player_position <- function(player_info_elements, match_group_index) {
    DEFAULT_PLAYER_POSITION_INDEX <- 2

    FIRST_POSITION_REGEX <- "[:alpha:]+"
    SECOND_POSITION_REGEX <- "(?:-[:alpha:]+)?"
    GENERAL_POSITION_REGEX <- paste0(FIRST_POSITION_REGEX, SECOND_POSITION_REGEX)
    EXTRA_POSITION_INFO <- "(?:, [:alpha:])?"
    SPECIFIC_POSITION_REGEX <- paste0("(?: \\(", GENERAL_POSITION_REGEX, EXTRA_POSITION_INFO, "\\))?")
    PLAYER_POSITION_REGEX <- paste0(
      "Position: (", GENERAL_POSITION_REGEX, SPECIFIC_POSITION_REGEX, ")"
    )

    player_position_index <- DEFAULT_PLAYER_POSITION_INDEX + n_indices_to_shift_by(player_info_elements)
    player_position_element <- player_info_elements[[player_position_index]]

    player_position_match_groups <- player_position_element$getElementText() %>% stringr::str_match(PLAYER_POSITION_REGEX)

    assert_regex_matches(player_position_match_groups, match_group_index)

    player_position_match_groups[[match_group_index]] %>%
      stringr::str_replace_all(., ", ", "-")
  }

  scrape_player_info <- function(browser, competition_name) {
    PLAYER_NAME_SELECTOR <- "h1[itemprop='name']"
    PLAYER_INFO_SELECTOR <- "[itemtype='https://schema.org/Person'] p"
    MATCH_GROUP_INDEX <- 2
    PLAYER_INFO_COLS <- c(
      "Player",
      "Position",
      "HeightCm",
      "WeightKg",
      "Birthdate",
      "NationalTeam",
      "Competition"
    )

    player_name <- browser$findElement(using = "css", PLAYER_NAME_SELECTOR)$getElementText()

    player_info_elements <- browser$findElements(using = "css", PLAYER_INFO_SELECTOR)

    player_position <- scrape_player_position(player_info_elements, MATCH_GROUP_INDEX)
    height_weight <- scrape_player_height_weight(player_info_elements, MATCH_GROUP_INDEX)
    birthdate <- scrape_player_birthdate(player_info_elements, MATCH_GROUP_INDEX)
    national_team <- scrape_player_national_team(player_info_elements, MATCH_GROUP_INDEX)

    player_info_values <- c(
      player_name,
      player_position,
      height_weight,
      birthdate,
      national_team,
      competition_name
    )

    clean_player_values <- player_info_values %>%
      # Birthdate value has a ',' between day & year, but might as well replace
      # any potential commas to avoid CSV parsing errors
      purrr::map(~ stringr::str_replace_all(., ",", "")) %>%
      unlist

    list(player_values = clean_player_values, player_cols = PLAYER_INFO_COLS)
  }

  scrape_individual_match_stats <- function(browser, url_comp) {
    # FBRef will display up to 3 data tables, separated by competiton:
    # 1. #ks_matchlogs_all = All competitions
    # 2. #ks_matchlogs_<4-digit number> = Domestic league competition
    # 3. #ks_matchologs_<4-digit number> = International competition (if available)
    DATA_DIV_SELECTOR = "div[id^=all_ks_matchlogs_]"
    DATA_TABLE_SELECTOR = "table[id^=ks_matchlogs_]"
    BASE_TO_CSV_BUTTON_SELECTOR <- paste0(
      ".section_heading_text .hasmore li:nth-child(4) button"
    )
    CSV_ELEMENT_SELECTOR <- "pre[id^=csv_ks_matchlogs_]"

    url <- url_comp[["url"]]
    browser$navigate(url)
    assert_browser_at_navigated_url(browser, url)

    comp_data_tables <- browser$findElements(using = "css", DATA_TABLE_SELECTOR)
    domestic_comp_data_only <- length(comp_data_tables) == 1

    if (domestic_comp_data_only) {
      # Position of domestic competition data table depends on whether data
      # from other competitions exist.
      domestic_comp_index <- 1
    } else {
      domestic_comp_index <- 2

      # Need to click the domestic competition button to show the table,
      # because the to-csv button only converts the table that's currently visible
      domestic_comp_button_selector <- paste0(
        "#all_ks_matchlogs_all [data-show^='#all_ks_matchlogs_']:nth-child(",
        domestic_comp_index,
        ")"
      )

      browser$findElement(using = "css", domestic_comp_button_selector)$clickElement()
    }

    domestic_comp_table_selector <- paste0(
      ":nth-child(", domestic_comp_index ,") "
    )


    # We're using the domestic competition match data only, because it's more
    # consistent (i.e. some players participate in international comps some
    # years). Adding international competition data might be useful
    # (i.e. good players might suffer fatigue from the extra matches),
    # but, for now, it's not worth the extra effort cleaning the data.
    to_csv_button_selector <- paste0(
      DATA_DIV_SELECTOR,
      domestic_comp_table_selector,
      BASE_TO_CSV_BUTTON_SELECTOR
    )

    # Need to execute JS to click the button because calling $clickElement()
    # on the webElement object doesn't do anything. The selector is probably
    # more specific than it needs to be, but there are lots of tables
    # on these pages with similar markup, so there's a high risk
    # of accidentally querying for more than one intends.
    browser$executeScript(
      paste0(
        "document.querySelector('", to_csv_button_selector, "').click()"
      )
    )

    csv_element <- browser$findElement(using = "css", CSV_ELEMENT_SELECTOR)
    player_info <- scrape_player_info(browser, url_comp[["comp"]])

    clean_csv_strings(player_info, csv_element$getElementText())
  }

  scrape_individual_player_stats <- function(browser, url) {
    # Selecting domestic league matches only, because players don't always have
    # matches in international competitions (e.g. Champions League),
    # and I want to keep it relatively simple & consistent for now.
    # Might include international matches sometime later.
    DOMESTIC_COMPS_MATCH_LINK_SELECTOR <- "#all_stats_player [data-stat='matches'] a"
    DOMESTIC_COMPS_COMP_LINK_SELECTOR <- "#all_stats_player [data-stat='comp_level'] a"

    browser$navigate(url)
    assert_browser_at_navigated_url(browser, url)

    match_urls <- browser$findElements(
      using = "css", DOMESTIC_COMPS_MATCH_LINK_SELECTOR
    ) %>%
      purrr::map(get_href) %>%
      unlist

    comp_elements <- browser$findElements(
      using = "css", DOMESTIC_COMPS_COMP_LINK_SELECTOR
    )

    comp_names <- comp_elements[(length(comp_elements) - length(match_urls) + 1):length(comp_elements)] %>%
      purrr::map(~ .$getElementText()) %>%
      unlist

    purrr::map2(match_urls, comp_names, ~ list(url = .x, comp = .y))
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
    .[1:5] %>%
    purrr::map(~ scrape_individual_player_stats(browser, .)) %>%
    unlist(., recursive = FALSE) %>%
    purrr::map(~ scrape_individual_match_stats(browser, .)) %>%
    purrr::map(readr::read_csv) %>%
    purrr::map(
      ~ dplyr::mutate(
        .,
        HeightCm = as.numeric(HeightCm),
        WeightKg = as.numeric(WeightKg),
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

  # driver$server$stop()

  stats
}
