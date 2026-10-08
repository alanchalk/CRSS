#' CRSS 2024 crash-level targets and predictors
#'
#' A crash-level analytical dataset derived from the United States National
#' Highway Traffic Safety Administration's 2024 Crash Report Sampling System.
#' Each row represents one sampled police-reported crash.
#'
#' The table contains alternative injury, vulnerable-road-user, crash-mechanism,
#' and claim-complexity targets. It also contains crash context and aggregated
#' vehicle and driver information. Towing and maximum vehicle-damage targets are
#' deliberately omitted.
#'
#' Because several alternative outcomes coexist in this table, predictor
#' eligibility depends on the selected target. Target-specific exclusions are
#' recorded in `inst/extdata/crss_crash_target_exclusions.csv`, and column
#' provenance is recorded in `inst/extdata/crss_crash_targets_schema.csv`.
#'
#' @import data.table
#' @format A `data.table` with one row per crash. Build-time dimensions and
#'   validation results are stored in
#'   `inst/extdata/crss_crash_targets_build.json`.
#' @source \url{https://www.nhtsa.gov/file-downloads?p=nhtsa/downloads/CRSS/2024/}
"crss_crash_targets"
