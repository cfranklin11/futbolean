# FBRef doesn't seem to have per-match player data before the 2014-2015 season.
# We may want data aggregated by season, which goes back a bit futher,
# eventually, but not for now
EARLIEST_SEASON_WITH_PLAYER_MATCH_DATA <- "2014-2015"
FBREF_HOSTNAME = "https://fbref.com"

fetch_html <- function(url, n_attempts = 0) {
  tryCatch(
    {
      n_attempts <- n_attempts + 1
      xml2::read_html(url)
    },
    error = function(e) {
      warning(
        paste0(
          "Raised \n", e, "\nafter ", n_attempts, " ",
          ifelse(n_attempts == 1, "attempt", "attempts"), " on URL ", url
        )
      )

      if (n_attempts > 3) {
        print(Sys.time())

        stop(
          paste0(
            "Stopped trying to scrape URL ", url,
            " after ", n_attempts, " attempts."
          )
        )
      }

      Sys.sleep(10 * n_attempts)
      fetch_html(url, n_attempts = n_attempts)
    }
  )
}

scrape_player_links <- function(start_season, end_season) {
  scrape_links <- function(
    player_hrefs = NULL,
    path = "/en/comps/9/stats/Premier-League-Stats",
    should_scrape = FALSE
  ) {
    PLAYER_LINK_SELECTOR <- "#stats_player [data-stat='player'] a"
    PREV_BUTTON_SELECTOR <- "a.button2.prev"
    PAGE_HEADLINE_SELECTOR <- "h1[itemprop='name']"

    url <- paste0(FBREF_HOSTNAME, path)
    page <- fetch_html(url)

    page_headline <- page %>%
      rvest::html_node(., PAGE_HEADLINE_SELECTOR) %>%
      rvest::html_text(.)

    # TODO: Checking start/end seasons as characters is error-prone,
    # probably better to convert them to integers, then compare to the season
    # numbers on the current page, but this is simpler and works well enough
    # for now
    if (is.na(page_headline)) {
      should_navigate_to_previous_season <- FALSE
      at_end_season <- FALSE
    } else {
      should_navigate_to_previous_season <- page_headline %>%
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
        rvest::html_nodes(., PLAYER_LINK_SELECTOR) %>%
        purrr::map(~ rvest::html_attr(., "href")) %>%
        unlist
    } else {
      this_page_player_hrefs <- NULL
    }

    all_player_hrefs <- c(player_hrefs, this_page_player_hrefs) %>% unique
    # We start at the current/most-recent season and work our way back
    prev_season_path <- page %>%
      rvest::html_node(., PREV_BUTTON_SELECTOR) %>%
      rvest::html_attr(., "href")

    if (should_navigate_to_previous_season && is.character(prev_season_path)) {
      return(
        scrape_links(
          player_hrefs = all_player_hrefs,
          path = prev_season_path,
          should_scrape = should_scrape_this_season
        )
      )
    }

    all_player_hrefs
  }

  scrape_links() %>%
    purrr::map(~ paste0(FBREF_HOSTNAME, .)) %>%
    unlist
}

scrape_player_stats <- function(player_urls) {
  print(Sys.time())

  coerce_optional_col_to_numeric <- function(data_frame, col_name) {
    if (is.null(data_frame[[col_name]])) {
      return(numeric(nrow(data_frame)))
    }

    as.numeric(data_frame[[col_name]])
  }

  scrape_player_national_team <- function(player_info_fields, match_group_index) {
    NATIONAL_TEAM_LABEL <- "National Team:"
    NATIONAL_TEAM_REGEX <- paste0(NATIONAL_TEAM_LABEL, " (.+) [:alpha:]{2}")

    national_team_text <- player_info_fields %>%
      purrr::detect(~ grepl(NATIONAL_TEAM_LABEL, .)) %>%
      unlist

    if (is.null(national_team_text)) {
      return("")
    }

    national_team_match_groups <- stringr::str_match(
      national_team_text, NATIONAL_TEAM_REGEX
    )

    if (any(is.na(national_team_match_groups))) {
      return("")
    }

    national_team_match_groups[[match_group_index]]
  }

  scrape_player_birthdate <- function(player_info_fields, match_group_index) {
    BIRTHDATE_LABEL <- "Born:"
    BIRTHDATE_REGEX <- paste0(
      BIRTHDATE_LABEL, " ([:alpha:]+ [:digit:]{1,2}, [:digit:]{4})"
    )

    birthdate_text <- player_info_fields %>%
      purrr::detect(~ grepl(BIRTHDATE_LABEL, .))

    if (is.null(birthdate_text)) {
      return("")
    }

    birthdate_match_groups <- stringr::str_match(birthdate_text, BIRTHDATE_REGEX)

    if (any(is.na(birthdate_match_groups))) {
      return("")
    }

    birthdate_match_groups[[match_group_index]]
  }

  scrape_player_height_weight <- function(player_info_fields, match_group_index) {
    HEIGHT_WEIGHT_LABELS <- "cm|kg"
    HEIGHT_WEIGHT_REGEX <- "((?:[:digit:]+cm)?(?:, )?(?:[:digit:]+kg)?)"

    height_weight_text <- player_info_fields %>%
      purrr::detect(~ grepl(HEIGHT_WEIGHT_LABELS, .))

    if (is.null(height_weight_text)) {
      return(c("", ""))
    }

    height_weight_match_groups <- stringr::str_match(
      height_weight_text, HEIGHT_WEIGHT_REGEX
    )

    if (any(is.na(height_weight_match_groups))) {
      return(c("", ""))
    }

    height_weight <- height_weight_match_groups[[match_group_index]] %>%
      stringr::str_split(., ", ") %>%
      unlist

    height <- height_weight %>%
      purrr::detect(~ grepl("cm", .), .default = "") %>%
      stringr::str_replace_all(., "[:alpha:]", "") %>%
      unlist

    weight <- height_weight %>%
      purrr::detect(~ grepl("kg", .), .default = "") %>%
      stringr::str_replace_all(., "[:alpha:]", "") %>%
      unlist

    return(c(height, weight))
  }

  scrape_player_position <- function(player_info_fields, match_group_index) {
    POSITION_LABEL <- "Position:"
    FIRST_POSITION_REGEX <- "[:alpha:]+"
    SECOND_POSITION_REGEX <- "(?:-[:alpha:]+)?"
    GENERAL_POSITION_REGEX <- paste0(FIRST_POSITION_REGEX, SECOND_POSITION_REGEX)
    EXTRA_POSITION_INFO <- "(?:, [:alpha:])?"
    SPECIFIC_POSITION_REGEX <- paste0("(?: \\(", GENERAL_POSITION_REGEX, EXTRA_POSITION_INFO, "\\))?")
    PLAYER_POSITION_REGEX <- paste0(
      POSITION_LABEL, " (", GENERAL_POSITION_REGEX, SPECIFIC_POSITION_REGEX, ")"
    )

    player_position_text <- player_info_fields %>%
      purrr::detect(~ grepl(POSITION_LABEL, .))

    if (is.null(player_position_text)) {
      return("")
    }

    player_position_match_groups <- stringr::str_match(
      player_position_text, PLAYER_POSITION_REGEX
    )

    if (any(is.na(player_position_match_groups))) {
      return("")
    }

    player_position_match_groups[[match_group_index]] %>%
      stringr::str_replace_all(., ", ", "-")
  }

  scrape_player_info <- function(page, competition_name) {
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
      "SeasonCompetition"
    )

    player_name <- rvest::html_node(page, PLAYER_NAME_SELECTOR) %>% rvest::html_text(.)

    player_info_fields <- rvest::html_nodes(page, PLAYER_INFO_SELECTOR) %>%
      purrr::map(rvest::html_text) %>%
      unlist

    player_position <- scrape_player_position(player_info_fields, MATCH_GROUP_INDEX)
    height_weight <- scrape_player_height_weight(player_info_fields, MATCH_GROUP_INDEX)
    birthdate <- scrape_player_birthdate(player_info_fields, MATCH_GROUP_INDEX)
    national_team <- scrape_player_national_team(player_info_fields, MATCH_GROUP_INDEX)

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

    setNames(as.list(clean_player_values), PLAYER_INFO_COLS)
  }

  extract_header_cell_text <- function(header_cell) {
    cell_colspan <- rvest::html_attr(header_cell, "colspan")
    cell_text <- rvest::html_text(header_cell) %>%
      # I don't really like how spaces look in col labels, and most of the labels
      # are in pascal case anyway
      stringr::str_replace_all(., " ", "") %>%
      stringr::str_replace_all(., "%", "Percentage")

    if (is.na(cell_colspan)) {
      return(cell_text)
    }

    rep(cell_text, as.numeric(cell_colspan))
  }

  scrape_player_stats <- function(page, path) {
    N_HEADER_ROWS <- 2

    # FBRef will display up to 3 data tables, separated by competiton:
    # 1. #ks_matchlogs_all = All competitions
    # 2. #ks_matchlogs_<4-digit number> = Domestic league competition
    # 3. #ks_matchologs_<4-digit number> = International competition (if available)
    # None of these is guaranteed to appear, so the selector must be flexible.
    DATA_TABLE_SELECTOR <- "table[id^=ks_matchlogs_]"

    # We always want the first data table, because it is for "All competitions"
    # when available and the relevant domestic competition when not.
    html_table <- page %>% rvest::html_node(., DATA_TABLE_SELECTOR)

    # Some pages are missing match data tables
    if (is.na(html_table)) {
      print(paste0(path, " didn't have a match data table"))
      return(NULL)
    }

    table_header <- html_table %>%
      rvest::html_nodes(., "thead tr") %>%
        purrr::map(~ rvest::html_nodes(., "th")) %>%
        purrr::map_depth(., 2, extract_header_cell_text) %>%
        purrr::map(unlist) %>%
        purrr::pmap(paste0) %>%
        unlist

    table_body <- html_table %>%
      rvest::html_table(., fill = TRUE, header = FALSE) %>%
      dplyr::slice(., (N_HEADER_ROWS + 1):length(.))

    colnames(table_body) <- table_header

    table_body
  }

  scrape_individual_match_stats <- function(url_and_competition) {
    url <- url_and_competition[["url"]]
    competition_name <- url_and_competition[["competition"]]

    page <- fetch_html(url)

    player_data_table <- scrape_player_stats(page, url)
    player_info <- scrape_player_info(page, competition_name)

    if (is.null(player_data_table)) {
      return(NULL)
    }

    do.call(tibble::add_column, c(list(.data = player_data_table), player_info))
  }

  scrape_individual_player_stats <- function(url) {
    # Selecting domestic league matches only, because players don't always have
    # matches in international competitions (e.g. Champions League),
    # and I want to keep it relatively simple & consistent for now.
    # Might include international matches sometime later.
    DOMESTIC_COMPS_MATCH_LINK_SELECTOR <- "#all_stats_player [data-stat='matches'] a"
    DOMESTIC_COMPS_COMP_LINK_SELECTOR <- "#all_stats_player [data-stat='comp_level'] a"

    page <- fetch_html(url)

    match_urls <- page %>%
      rvest::html_nodes(., DOMESTIC_COMPS_MATCH_LINK_SELECTOR) %>%
      purrr::map(~ rvest::html_attr(., "href")) %>%
      unlist %>%
      # Match paths can be duplicated if a player played for two different teams
      # in one season
      unique %>%
      purrr::map(~ paste0(FBREF_HOSTNAME, .))

    # Some older player pages don't have links to per-match data pages, so we
    # just skip them. This seems to only happen with players whose final season
    # was 2014-2015 (the first season with per-match data), but not sure if it
    # applies to all players like this or just some.
    if (is.null(match_urls)) {
      print(paste0(url, "didn't have any links to match data pages."))
      return(NULL)
    }

    comp_names <- page %>%
      rvest::html_nodes(., DOMESTIC_COMPS_COMP_LINK_SELECTOR) %>%
      # There will often be more rows with competition values than rows with
      # links to per-match data pages, so we take the last n rows, where
      # n = number of rows with matches links
      .[(length(.) - length(match_urls) + 1):length(.)] %>%
      purrr::map(~ rvest::html_text(.)) %>%
      unlist

    purrr::map2(match_urls, comp_names, ~ list(url = .x, competition = .y))
  }

  STATS_COL_FILL = list(
    HeightCm = 0,
    WeightKg = 0,
    NationalTeam = "",
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
    DefenseCrdR = 0,
    GoalkeepingCS = 0,
    GoalkeepingGA = 0,
    GoalkeepingSaves = 0,
    GoalkeepingSoTA = 0,
    GoalkeepingSavePercentage = 0
  )

  stats <- player_urls %>%
    purrr::map(~ scrape_individual_player_stats(.)) %>%
    unlist(., recursive = FALSE) %>%
    purrr::discard(is.null) %>%
    purrr::map(~ scrape_individual_match_stats(.)) %>%
    purrr::discard(is.null) %>%
    purrr::map(
      .,
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
        DefenseCrdR = as.numeric(DefenseCrdR),
        GoalkeepingCS = coerce_optional_col_to_numeric(., "GoalkeepingCS"),
        GoalkeepingGA = coerce_optional_col_to_numeric(., "GoalkeepingGA"),
        GoalkeepingSaves = coerce_optional_col_to_numeric(., "GoalkeepingSaves"),
        GoalkeepingSoTA = coerce_optional_col_to_numeric(., "GoalkeepingSoTA"),
        GoalkeepingSavePercentage = coerce_optional_col_to_numeric(., "GoalkeepingSavePercentage")
      )
    ) %>%
    dplyr::bind_rows(.) %>%
    tidyr::drop_na(., Date) %>%
    tidyr::replace_na(., STATS_COL_FILL) %>%
    dplyr::mutate(., Comp = dplyr::coalesce(Comp, SeasonCompetition)) %>%
    dplyr::select(., -c("SeasonCompetition", "MatchReport"))

  print(Sys.time())

  stats
}
