describe("scrape_player_links()", {
  start_season <- "2016-2017"
  end_season <- "2017-2018"
  n_seasons <- 2

  # Fetching data takes awhile, so we do it once for all tests
  player_urls <- scrape_player_links(
    start_season = start_season,
    end_season = end_season
  )

  it("returns a vector of url characters", {
    expect_true("character" %in% class(player_urls$data))

    expect_gt(length(player_urls$data), n_seasons)

    all_are_player_urls <- player_urls$data %>%
      purrr::map(~ grepl("https://fbref.com/en/players/", .)) %>%
      unlist %>%
      all

    expect_true(all_are_player_urls)
  })
})
