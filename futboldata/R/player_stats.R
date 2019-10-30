#' @importFrom magrittr %>%

source(paste0(getwd(), "/R/utils.R"))

.coerce_col_to_numeric <- function(data_frame, col_name) {
  if (is.null(data_frame[[col_name]])) {
    return(numeric(nrow(data_frame)))
  }

  as.numeric(data_frame[[col_name]])
}

.coerce_column_data_types <- function(data_frame) {
  coerce_invalid_date_warning <- "failed to parse"
  coerce_invalid_number_warning <- "NAs introduced by coercion"

  # Coercing columns results in major warning spam, and since the whole point
  # of this is to generate NAs for invalid rows, we don't need to hear
  # about it hundreds of times
  withCallingHandlers(
    dplyr::mutate(
      data_frame,
      Date = lubridate::as_date(Date),
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
      GoalkeepingCS = .coerce_col_to_numeric(
        data_frame, "GoalkeepingCS"
      ),
      GoalkeepingGA = .coerce_col_to_numeric(
        data_frame, "GoalkeepingGA"
      ),
      GoalkeepingSaves = .coerce_col_to_numeric(
        data_frame, "GoalkeepingSaves"
      ),
      GoalkeepingSoTA = .coerce_col_to_numeric(
        data_frame, "GoalkeepingSoTA"
      ),
      GoalkeepingSavePercentage = .coerce_col_to_numeric(
        data_frame, "GoalkeepingSavePercentage"
      )
    ),
    warning = function(w) {
      if (
        grepl(coerce_invalid_date_warning, w$message) ||
        grepl(coerce_invalid_number_warning, w$message)
      ) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

.nullify_partial_player_data <- function(player_data) {
  data_frames <- player_data %>% purrr::map(~ .x[["data"]])
  first_missing_data_index <- data_frames %>% purrr::detect_index(is.null)
  no_missing_data <- first_missing_data_index == 0

  if (no_missing_data) {
    return(data_frames)
  }

  player_url <- player_data[[first_missing_data_index]][["player_url"]]
  assign("skipped_urls", c(skipped_urls, player_url), envir = .GlobalEnv)

  list()
}

.scrape_player_national_team <- function(
  player_info_fields, match_group_index
) {
  national_team_label <- "National Team:"
  national_team_regex <- paste0(national_team_label, " (.+) [:alpha:]{2}")

  national_team_text <- player_info_fields %>%
    purrr::detect(~ grepl(national_team_label, .)) %>%
    unlist

  if (is.null(national_team_text)) {
    return("")
  }

  national_team_match_groups <- stringr::str_match(
    national_team_text, national_team_regex
  )

  if (any(is.na(national_team_match_groups))) {
    return("")
  }

  national_team_match_groups[[match_group_index]]
}

.scrape_player_birthdate <- function(player_info_fields, match_group_index) {
  birthdate_label <- "Born:"
  birthdate_regex <- paste0(
    birthdate_label, " ([:alpha:]+ [:digit:]{1,2}, [:digit:]{4})"
  )

  birthdate_text <- player_info_fields %>%
    purrr::detect(~ grepl(birthdate_label, .))

  if (is.null(birthdate_text)) {
    return("")
  }

  birthdate_match_groups <- stringr::str_match(
    birthdate_text, birthdate_regex
  )

  if (any(is.na(birthdate_match_groups))) {
    return("")
  }

  birthdate_match_groups[[match_group_index]]
}

.scrape_player_height_weight <- function(
  player_info_fields, match_group_index
) {
  height_weight_labels <- "cm|kg"
  height_weight_regex <- "((?:[:digit:]+cm)?(?:, )?(?:[:digit:]+kg)?)"

  height_weight_text <- player_info_fields %>%
    purrr::detect(~ grepl(height_weight_labels, .))

  if (is.null(height_weight_text)) {
    return(c("", ""))
  }

  height_weight_match_groups <- stringr::str_match(
    height_weight_text, height_weight_regex
  )

  if (any(is.na(height_weight_match_groups))) {
    return(c("", ""))
  }

  height_weight <- height_weight_match_groups[[match_group_index]] %>%
    stringr::str_split(", ") %>%
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

.scrape_player_position <- function(player_info_fields, match_group_index) {
  postigion_label <- "Position:"
  first_position_regex <- "[:alpha:]+"
  second_position_regex <- "(?:-[:alpha:]+)?"
  general_position_regex <- paste0(
    first_position_regex, second_position_regex
  )
  extra_position_info <- "(?:, [:alpha:])?"
  specific_position_regex <- paste0(
    "(?: \\(", general_position_regex, extra_position_info, "\\))?"
  )
  player_position_regex <- paste0(
    postigion_label,
    " (", general_position_regex, specific_position_regex, ")"
  )

  player_position_text <- player_info_fields %>%
    purrr::detect(~ grepl(postigion_label, .))

  if (is.null(player_position_text)) {
    return("")
  }

  player_position_match_groups <- stringr::str_match(
    player_position_text, player_position_regex
  )

  if (any(is.na(player_position_match_groups))) {
    return("")
  }

  player_position_match_groups[[match_group_index]] %>%
    stringr::str_replace_all(., ", ", "-")
}

.scrape_player_info <- function(page, competition_name) {
  player_name_selector <- "h1[itemprop='name']"
  player_info_selector <- "[itemtype='https://schema.org/Person'] p"
  match_group_index <- 2
  player_info_cols <- c(
    "Player",
    "Position",
    "HeightCm",
    "WeightKg",
    "Birthdate",
    "NationalTeam",
    "SeasonCompetition"
  )

  player_name <- rvest::html_node(page, player_name_selector) %>%
    rvest::html_text(.)

  player_info_fields <- rvest::html_nodes(page, player_info_selector) %>%
    purrr::map(rvest::html_text) %>%
    unlist

  player_position <- .scrape_player_position(
    player_info_fields, match_group_index
  )
  height_weight <- .scrape_player_height_weight(
    player_info_fields, match_group_index
  )
  birthdate <- .scrape_player_birthdate(
    player_info_fields, match_group_index
  )
  national_team <- .scrape_player_national_team(
    player_info_fields, match_group_index
  )

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

  setNames(as.list(clean_player_values), player_info_cols)
}

.extract_header_cell_text <- function(header_cell) {
  cell_colspan <- rvest::html_attr(header_cell, "colspan")
  cell_text <- rvest::html_text(header_cell) %>%
    # I don't really like how spaces look in col labels,
    # and most of the labels are in pascal case anyway
    stringr::str_replace_all(., " ", "") %>%
    stringr::str_replace_all(., "%", "Percentage")

  if (is.na(cell_colspan)) {
    return(cell_text)
  }

  rep(cell_text, as.numeric(cell_colspan))
}

.scrape_player_stats_table <- function(page, path) {
  n_header_rows <- 2

  # nolint start lintr keeps thinking this is commented code
  # FBRef will display up to 3 data tables, separated by competiton:
  # 1. #ks_matchlogs_all is for All competitions
  # 2. #ks_matchlogs_<4-digit number> is for Domestic league competition
  # 3. #ks_matchologs_<4-digit number> is for International competition
  #   (if available)
  # None of these is guaranteed to appear, so the selector must be flexible.
  # nolint end
  data_table_selector <- "table[id^=ks_matchlogs_]"

  # We always want the first data table, because it is for "All competitions"
  # when available and the relevant domestic competition when not.
  html_table <- page %>% rvest::html_node(., data_table_selector)

  # Some pages are missing match data tables
  if (is.na(html_table)) {
    print(paste0(path, " didn't have a match data table"))
    return(NULL)
  }

  table_header <- html_table %>%
    rvest::html_nodes(., "thead tr") %>%
      purrr::map(~ rvest::html_nodes(., "th")) %>%
      purrr::map_depth(., 2, .extract_header_cell_text) %>%
      purrr::map(unlist) %>%
      purrr::pmap(paste0) %>%
      unlist

  table_body <- html_table %>%
    rvest::html_table(., fill = TRUE, header = FALSE) %>%
    dplyr::slice(., (n_header_rows + 1):length(.))

  colnames(table_body) <- table_header

  table_body
}

.scrape_match_stats_page <- function(
  player_url,
  match_url,
  competition_name
) {
  page <- fetch_html(match_url)

  if (is.null(page)) {
    return(list(player_url = player_url, data = NULL))
  }

  player_data_table <- .scrape_player_stats_table(page, match_url)
  player_info <- .scrape_player_info(page, competition_name)

  if (is.null(player_data_table)) {
    return(NULL)
  }

  data_frame <- do.call(
    tibble::add_column, c(list(.data = player_data_table), player_info)
  )

  list(player_url = player_url, data = data_frame)
}

.scrape_player_stats_page <- function(url) {
  # Selecting domestic league matches only, because players don't always have
  # matches in international competitions (e.g. Champions League),
  # and I want to keep it relatively simple & consistent for now.
  # Might include international matches sometime later.
  domestic_match_link_selector <- "#all_stats_player [data-stat='matches'] a"
  domestic_comp_link_selector <- (
    "#all_stats_player [data-stat='comp_level'] a"
  )

  page <- fetch_html(url)

  if (is.null(page)) {
    return(NULL)
  }

  match_urls <- page %>%
    rvest::html_nodes(., domestic_match_link_selector) %>%
    purrr::map(~ rvest::html_attr(., "href")) %>%
    # Match paths can be duplicated if a player played for two different teams
    # in one season
    unique %>%
    purrr::map(~ paste0(fbref_hostname, .)) %>%
    unlist

  # Some older player pages don't have links to per-match data pages, so we
  # just skip them. This seems to only happen with players whose final season
  # was 2014-2015 (the first season with per-match data), but not sure if it
  # applies to all players like this or just some.
  if (is.null(match_urls) || length(match_urls) == 0) {
    print(paste0(url, "didn't have any links to match data pages."))
    return(NULL)
  }

  comp_names <- page %>%
    rvest::html_nodes(., domestic_comp_link_selector) %>%
    # There will often be more rows with competition values than rows with
    # links to per-match data pages, so we take the last n rows, where
    # n = number of rows with matches links
    .[(length(.) - length(match_urls) + 1):length(.)] %>%
    purrr::map(~ rvest::html_text(.)) %>%
    unlist

  purrr::map2(
    match_urls,
    comp_names,
    ~ list(player_url = url, match_url = .x, competition = .y)
  )
}

scrape_player_stats <- function(player_urls) {
  print(paste0("Starting: ", Sys.time()))

  stats_col_fill <- list(
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
    purrr::map(.scrape_player_stats_page) %>%
    purrr::discard(is.null) %>%
    purrr::map_depth(., 2, ~ do.call(.scrape_match_stats_page, .)) %>%
    purrr::discard(is.null) %>%
    purrr::map(.nullify_partial_player_data) %>%
    unlist(., recursive = FALSE) %>%
    purrr::discard(is.null) %>%
    purrr::map(.coerce_column_data_types) %>%
    dplyr::bind_rows(.) %>%
    tidyr::drop_na(., Date) %>%
    tidyr::replace_na(., stats_col_fill) %>%
    dplyr::mutate(., Comp = dplyr::coalesce(Comp, SeasonCompetition)) %>%
    dplyr::select(., -c("SeasonCompetition", "MatchReport"))

  print(paste0("Finished: ", Sys.time()))

  list(
    data = stats,
    skipped_urls = unique(skipped_urls)
  )
}
