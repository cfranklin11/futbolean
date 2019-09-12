source(paste0(getwd(), "/R/hello.R"))

#' Say hello to somebody
#' @param name Name of the recipient of the salutation
#' @get /hello
function(name = "") {
  hello(name) %>%
    jsonlite::toJSON(.)
}
