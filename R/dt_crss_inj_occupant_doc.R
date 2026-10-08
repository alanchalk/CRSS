#' CRSS 2024 motor vehicle occupant injury data
#'
#' A person-level analytical dataset derived from the United States National
#' Highway Traffic Safety Administration's 2024 Crash Report Sampling System.
#' Each row is a driver or passenger of a motor vehicle in transport involved
#' in a sampled police-reported crash.
#'
#' The key is `case_number`, `vehicle_number`, and `person_number`. People are
#' nested within vehicles and vehicles within crashes. `injured` is a binary
#' target derived from NHTSA's imputed injury severity; `serious_or_fatal_injury`
#' is an alternative severe-outcome target. Source categorical codes are not
#' carried alongside labels: categorical variables use English values, while
#' true measurements, counts, identifiers, and survey-design fields remain
#' numeric where appropriate.
#'
#' Multi-response CRSS files are represented as Boolean indicator columns.
#' Column provenance, timing, and modelling roles are recorded in
#' `inst/extdata/dt_crss_inj_occupant_schema.csv`. In particular, columns
#' labelled `post_crash` should not be used in a model presented as pre-impact
#' injury risk.
#'
#' CRSS is a complex probability sample of crashes. `weight`, `psu_var`, and
#' `psu_stratum` are retained for design-aware analysis. The `fold` variable is
#' assigned at crash level so all people and vehicles from one crash remain in
#' the same fold.
#'
#' @import data.table
#' @format A `data.table` with one row per in-scope occupant. Build-time row and
#'   column counts are stored in
#'   `inst/extdata/dt_crss_inj_occupant_build.json`.
#' @source \url{https://www.nhtsa.gov/file-downloads?p=nhtsa/downloads/CRSS/2024/}
"dt_crss_inj_occupant"
