#' CRSS 2024 crash-level injury targets and pre-collision predictors
#'
#' A crash-level case-study dataset derived from the 2024 United States Crash
#' Report Sampling System. Each row is a sampled police-reported crash. The
#' Two binary targets are supplied: `serious_or_fatal_injury` records whether at
#' least one person sustained a suspected serious or fatal injury, and
#' `injured_pedestrian` records whether at least one pedestrian was injured.
#'
#' The table has an enforced boundary excluding collision consequences and
#' collision consequences and outcome information other than the two explicitly
#' identified targets.
#' Its predictors describe people and vehicles present, the route and road,
#' time, lighting, weather, vehicle construction and equipment, pre-existing
#' vehicle defects, vision obstructions, charged violations, vehicle special
#' factors, and retrospectively established pre-impact conduct. It omits first harmful event,
#' collision manner, event sequences, impact, damage, towing, rollover, airbag
#' deployment, ejection, and injury summaries.
#'
#' `case_number`, `fold`, and the survey-design columns are retained for data
#' management and validation and must not be used as predictors. Some included
#' conditions—including defects, vision obstructions, violations, and vehicle
#' special factors, reported speed, alcohol involvement, distraction,
#' impairment, and avoidance behaviour—describe pre-collision circumstances but
#' were recorded or determined during the subsequent police investigation.
#' Their inclusion in a model is therefore a deliberate modelling choice.
#'
#' @format A `data.table` with one row per crash. Exact column provenance,
#'   modelling role, and information timing are recorded in
#'   `inst/extdata/dt_crss_accident_schema.csv`.
#' @source \url{https://www.nhtsa.gov/file-downloads?p=nhtsa/downloads/CRSS/2024/}
"dt_crss_accident"
