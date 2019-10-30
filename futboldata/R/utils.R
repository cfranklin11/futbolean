#' @importFrom magrittr %>%

fbref_hostname <- "https://fbref.com"
skipped_urls <- NULL

fetch_html <- function(url, n_attempts = 0) {
  # Using tryCatch without withCallingHandlers, because we're catching
  # random errors thrown by the server, not bugs in our code,
  # so there's no need to log them, but we still want to see
  # the warning messages without a stack trace.
  tryCatch({
      Sys.sleep(floor(runif(1, min = 0, max = 6)))
      n_attempts <- n_attempts + 1
      xml2::read_html(url)
    },
    error = function(e) {
      print(Sys.time())

      warning(
        paste0(
          "Raised the following after ", n_attempts, " ",
          ifelse(n_attempts == 1, "attempt", "attempts"), " on URL ", url,
          "\n", e
        )
      )

      if (n_attempts > 2) {
        warning(
          paste0(
            "Skipping URL ", url, " after ", n_attempts, " scraping attempts."
          )
        )

        # We don't save matchlog URLs, because it's easier to restart
        # from the associated player's URL
        if (!grepl("/matchlogs/", url)) {
          assign(
            "skipped_urls",
            c(skipped_urls, url),
            envir = .GlobalEnv
          )
        }

        return(NULL)
      }

      Sys.sleep(20 * n_attempts)
      closeAllConnections()
      gc()
      fetch_html(url, n_attempts = n_attempts)
    },
    include.full.call.stack = FALSE,
    include.compact.call.stack = FALSE
  )
}
