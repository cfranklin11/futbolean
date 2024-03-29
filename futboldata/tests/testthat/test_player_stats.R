describe("scrape_player_stats()", {
  player_urls <- c(
    "https://fbref.com/en/players/6b47c5db/Wilfred-Ndidi",
    "https://fbref.com/en/players/52465662/Rio-Ferdinand"
  )

  player_stats <- scrape_player_stats(player_urls)

  it("returns a list of data and skipped URLs", {
    expect_true("list" %in% class(player_stats))
    expect_true("data.frame" %in% class(player_stats$data))

    expect_true(
      "character" %in% class(player_stats$skipped_player_urls) ||
      "NULL" %in% class(player_stats$skipped_player_urls)
    )
    expect_true(
      "character" %in% class(player_stats$skipped_match_urls) ||
      "NULL" %in% class(player_stats$skipped_match_urls)
    )
  })

  it("returns player stats", {
    player_data <- player_stats$data

    expect_gt(nrow(player_data), length(player_urls))

    expect_type(player_data$Date, "double")
    expect_type(player_data$Day, "character")
    expect_type(player_data$Comp, "character")
    expect_type(player_data$Round, "character")
    expect_type(player_data$Venue, "character")
    expect_type(player_data$Result, "character")
    expect_type(player_data$Squad, "character")
    expect_type(player_data$Opponent, "character")
    expect_type(player_data$Start, "character")
    expect_type(player_data$Min, "double")
    expect_type(player_data$OffenseGls, "double")
    expect_type(player_data$OffenseAst, "double")
    expect_type(player_data$OffenseSh, "double")
    expect_type(player_data$OffenseSoT, "double")
    expect_type(player_data$OffenseCrs, "double")
    expect_type(player_data$OffenseFld, "double")
    expect_type(player_data$OffensePK, "double")
    expect_type(player_data$OffensePKatt, "double")
    expect_type(player_data$DefenseTkl, "double")
    expect_type(player_data$DefenseInt, "double")
    expect_type(player_data$DefenseFls, "double")
    expect_type(player_data$DefenseCrdY, "double")
    expect_type(player_data$DefenseCrdR, "double")
    expect_type(player_data$Player, "character")
    expect_type(player_data$Position, "character")
    expect_type(player_data$HeightCm, "double")
    expect_type(player_data$WeightKg, "double")
    expect_type(player_data$Birthdate, "character")
    expect_type(player_data$NationalTeam, "character")
    expect_type(player_data$GoalkeepingCS, "double")
    expect_type(player_data$GoalkeepingGA, "double")
    expect_type(player_data$GoalkeepingSaves, "double")
    expect_type(player_data$GoalkeepingSoTA, "double")
    expect_type(player_data$GoalkeepingSavePercentage, "double")
  })

  describe("if there are skipped URLs", {
    it("returns vectors of URLs", {
      skipped_player_urls <- player_stats$skipped_player_urls
      skipped_match_urls <- player_stats$skipped_match_urls

      all_are_player_urls <- skipped_player_urls %>%
        purrr::map(~ grepl("https://fbref.com/en/players/[[:alnum:]]+/", .)) %>%
        unlist %>%
        all

      expect_true(all_are_player_urls)

      match_url_regex <- paste0(
        "https://fbref.com/en/players/",
        "[[:alnum:]]+/matchlogs/[[:digit:]]{4}-[[:digit:]]{4}/"
      )

      any_are_match_urls <- skipped_player_urls %>%
        purrr::map(~ grepl(match_url_regex, .)) %>%
        unlist %>%
        any

      expect_false(any_are_match_urls)

      all_are_match_urls <- skipped_match_urls %>%
        purrr::map(~ grepl(match_url_regex, .)) %>%
        unlist %>%
        all

      expect_true(all_are_match_urls)
    })
  })
})
