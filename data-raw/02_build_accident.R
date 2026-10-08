#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(data.table))
source(file.path("data-raw", "_metadata.R"))

raw_dir <- file.path("data-raw", "CRSS2024CSV")
data_dir <- "data"
metadata_dir <- file.path("inst", "extdata")

if (!dir.exists(raw_dir)) {
  stop("Raw CRSS directory not found. Run data-raw/00_download_crss_2024.R first.")
}
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(metadata_dir, recursive = TRUE, showWarnings = FALSE)

snake_name <- function(x) {
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("(^_+|_+$)", "", x)
  gsub("_+", "_", x)
}

safe_level_name <- function(x) {
  x[is.na(x) | !nzchar(trimws(x))] <- "missing"
  snake_name(x)
}

assert_unique_key <- function(x, key, label) {
  if (anyNA(x[, ..key])) stop(label, " has missing key values")
  if (x[, anyDuplicated(.SD), .SDcols = key] > 0L) {
    stop(label, " does not have a unique key: ", paste(key, collapse = " + "))
  }
  invisible(TRUE)
}

rename_columns <- function(x, mapping) {
  missing <- setdiff(names(mapping), names(x))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "))
  setnames(x, names(mapping), unname(mapping))
  x
}

left_join_checked <- function(x, y, by, label) {
  assert_unique_key(y, by, label)
  before <- nrow(x)
  out <- merge(x, y, by = by, all.x = TRUE, sort = FALSE)
  if (nrow(out) != before) stop(label, " changed the crash row count")
  out
}

make_crash_flags <- function(file, label_col, prefix) {
  x <- fread(
    file.path(raw_dir, paste0(file, ".csv")),
    select = c("CASENUM", label_col),
    na.strings = c("", "NA")
  )
  x <- unique(x[!is.na(get(label_col)), .(CASENUM, level = get(label_col))])
  x[, feature := paste0(prefix, "__", safe_level_name(level))]
  x[, value := TRUE]
  out <- dcast(
    x, CASENUM ~ feature, value.var = "value", fun.aggregate = any, fill = FALSE
  )
  assert_unique_key(out, "CASENUM", paste0(file, " crash indicators"))
  setnames(out, "CASENUM", "case_number")
  out
}

# Accident supplies the complete set of sampled crashes and the survey design.
accident_source <- fread(file.path(raw_dir, "accident.csv"),
                         na.strings = c("", "NA"))
assert_unique_key(accident_source, "CASENUM", "accident.csv")

dt_crss_crash_working <- accident_source[, .(
  CASENUM,
  PSU,
  PSU_VAR,
  PSUSTRAT,
  WEIGHT,
  REGIONNAME,
  URBANICITYNAME,
  MONTHNAME,
  WKDY_IMNAME,
  HOUR_IM,
  MINUTE_IM,
  RELJCT1_IMNAME,
  RELJCT2_IMNAME,
  TYP_INTNAME,
  REL_ROADNAME,
  WRK_ZONENAME,
  LGTCON_IMNAME,
  WEATHR_IMNAME,
  INT_HWYNAME,
  ALCHL_IMNAME,
  MAXSEV_IMNAME
)]

dt_crss_crash_working <- rename_columns(dt_crss_crash_working, c(
  CASENUM = "case_number",
  PSU = "psu",
  PSU_VAR = "psu_var",
  PSUSTRAT = "psu_stratum",
  WEIGHT = "weight",
  REGIONNAME = "region",
  URBANICITYNAME = "urbanicity",
  MONTHNAME = "crash_month",
  WKDY_IMNAME = "day_of_week",
  HOUR_IM = "crash_hour",
  MINUTE_IM = "crash_minute",
  RELJCT1_IMNAME = "within_interchange_area",
  RELJCT2_IMNAME = "junction_location",
  TYP_INTNAME = "intersection_type",
  REL_ROADNAME = "relation_to_road",
  WRK_ZONENAME = "work_zone",
  LGTCON_IMNAME = "light_condition",
  WEATHR_IMNAME = "primary_weather",
  INT_HWYNAME = "interstate_highway",
  ALCHL_IMNAME = "crash_alcohol_involvement",
  MAXSEV_IMNAME = "maximum_injury_severity"
))

dt_crss_crash_working[, serious_or_fatal_injury := as.integer(
  maximum_injury_severity %chin% c(
    "Suspected Serious Injury (A)", "Fatal Injury (K)"
  )
)]

# Person records provide pre-collision occupant composition.
person <- fread(
  file.path(raw_dir, "person.csv"),
  select = c(
    "CASENUM", "PER_TYPNAME", "INJSEV_IMNAME", "AGE_IM", "SEX_IMNAME",
    "SEAT_IMNAME", "REST_USENAME"
  ),
  na.strings = c("", "NA")
)
person[, occupant := PER_TYPNAME %chin% person_types_in_scope]
person[, passenger :=
         PER_TYPNAME == "Passenger of a Motor Vehicle In-Transport"]
person[, pedestrian := PER_TYPNAME == "Pedestrian"]
person[, injured_person :=
         INJSEV_IMNAME != "No Apparent Injury (O)" &
         INJSEV_IMNAME != "Died Prior to Crash*"]
pedestrian_target <- person[, .(
  injured_pedestrian = as.integer(any(pedestrian & injured_person))
), by = CASENUM]
setnames(pedestrian_target, "CASENUM", "case_number")
dt_crss_crash_working <- left_join_checked(
  dt_crss_crash_working, pedestrian_target, "case_number",
  "pedestrian target join"
)
set(dt_crss_crash_working,
    which(is.na(dt_crss_crash_working$injured_pedestrian)),
    "injured_pedestrian", 0L)

# Driver/passenger characteristics existed before impact and support the
# journey-start severity case study. Non-motorists are deliberately excluded
# from these summaries so they do not reveal pedestrian or cyclist involvement.
occupants <- person[occupant == TRUE]
occupants[, valid_age := fifelse(AGE_IM >= 0L & AGE_IM <= 120L,
                                 AGE_IM, NA_integer_)]
occupant_summary <- occupants[, .(
  occupant_count = .N,
  passenger_count = sum(passenger),
  child_occupant_count = sum(valid_age < 16L, na.rm = TRUE),
  older_occupant_count = sum(valid_age >= 65L, na.rm = TRUE),
  youngest_occupant_age = suppressWarnings(min(as.numeric(valid_age),
                                                na.rm = TRUE)),
  oldest_occupant_age = suppressWarnings(max(as.numeric(valid_age),
                                              na.rm = TRUE)),
  mean_occupant_age = mean(as.numeric(valid_age), na.rm = TRUE),
  male_occupant_count = sum(SEX_IMNAME == "Male", na.rm = TRUE),
  female_occupant_count = sum(SEX_IMNAME == "Female", na.rm = TRUE),
  unrestrained_occupant_count = sum(
    REST_USENAME == "None Used/Not Applicable", na.rm = TRUE
  ),
  any_unrestrained_occupant = any(
    REST_USENAME == "None Used/Not Applicable", na.rm = TRUE
  ),
  any_front_seat_passenger = any(
    passenger & grepl("^Front Seat", SEAT_IMNAME), na.rm = TRUE
  ),
  any_rear_seat_occupant = any(
    grepl("^(Second|Third|Fourth) Seat", SEAT_IMNAME), na.rm = TRUE
  )
), by = CASENUM]
for (j in c("youngest_occupant_age", "oldest_occupant_age",
            "mean_occupant_age")) {
  set(occupant_summary, which(!is.finite(occupant_summary[[j]])), j, NA_real_)
}
setnames(occupant_summary, "CASENUM", "case_number")
dt_crss_crash_working <- left_join_checked(
  dt_crss_crash_working, occupant_summary, "case_number", "occupant summary join"
)
occupant_count_columns <- c(
  "occupant_count", "passenger_count", "child_occupant_count",
  "older_occupant_count", "male_occupant_count", "female_occupant_count",
  "unrestrained_occupant_count"
)
occupant_flag_columns <- c(
  "any_unrestrained_occupant", "any_front_seat_passenger",
  "any_rear_seat_occupant"
)
for (j in occupant_count_columns) {
  set(dt_crss_crash_working, which(is.na(dt_crss_crash_working[[j]])), j, 0L)
}
for (j in occupant_flag_columns) {
  set(dt_crss_crash_working, which(is.na(dt_crss_crash_working[[j]])), j, FALSE)
}

# Vehicle-level targets and numerical summaries are aggregated before joining.
vehicle <- fread(file.path(raw_dir, "vehicle.csv"),
                 na.strings = c("", "NA"))
assert_unique_key(vehicle, c("CASENUM", "VEH_NO"), "vehicle.csv")
vehicle[, valid_model_year := fifelse(MDLYR_IM >= 1900L & MDLYR_IM <= 2025L,
                                      MDLYR_IM, NA_integer_)]
vehicle[, valid_speed_limit := fifelse(VSPD_LIM >= 0L & VSPD_LIM <= 85L,
                                       VSPD_LIM, NA_integer_)]
vehicle[, valid_travel_speed := fifelse(TRAV_SP >= 0L & TRAV_SP <= 200L,
                                        TRAV_SP, NA_integer_)]
vehicle[, commercial_configuration := !V_CONFIGNAME %chin% c(
  "Not Applicable", "Unknown", "Qualifying Vehicle, Unknown Configuration"
)]
vehicle_summary <- vehicle[, .(
  commercial_vehicle_involved = as.integer(any(commercial_configuration)),
  hazardous_material_involved = as.integer(any(HAZ_INVNAME == "Yes")),
  oldest_vehicle_model_year = suppressWarnings(min(as.numeric(valid_model_year),
                                                    na.rm = TRUE)),
  newest_vehicle_model_year = suppressWarnings(max(as.numeric(valid_model_year),
                                                    na.rm = TRUE)),
  mean_vehicle_model_year = mean(as.numeric(valid_model_year), na.rm = TRUE),
  maximum_speed_limit = suppressWarnings(max(as.numeric(valid_speed_limit),
                                              na.rm = TRUE)),
  maximum_reported_travel_speed = suppressWarnings(max(
    as.numeric(valid_travel_speed), na.rm = TRUE
  ))
), by = CASENUM]

numeric_summary <- c(
  "oldest_vehicle_model_year", "newest_vehicle_model_year",
  "mean_vehicle_model_year", "maximum_speed_limit",
  "maximum_reported_travel_speed"
)
for (j in numeric_summary) {
  set(vehicle_summary, which(!is.finite(vehicle_summary[[j]])), j, NA_real_)
}
setnames(vehicle_summary, "CASENUM", "case_number")
dt_crss_crash_working <- left_join_checked(
  dt_crss_crash_working, vehicle_summary, "case_number", "vehicle summary join"
)

# Crash-level and vehicle/driver multi-response fields become "any in crash"
# indicators. Sentinel levels such as None Noted and Not Reported are retained.
flag_specs <- list(
  list("crashrf", "CRASHRFNAME", "crash_factor"),
  list("weather", "WEATHERNAME", "weather"),
  list("vehiclesf", "VEHICLESFNAME", "vehicle_special_factor"),
  list("driverrf", "DRIVERRFNAME", "driver_factor"),
  list("distract", "DRDISTRACTNAME", "driver_distraction"),
  list("drimpair", "DRIMPAIRNAME", "driver_impairment"),
  list("factor", "VEHICLECCNAME", "vehicle_contributing_factor"),
  list("maneuver", "MANEUVERNAME", "avoidance_manoeuvre"),
  list("violatn", "VIOLATIONNAME", "driver_violation"),
  list("vision", "VISIONNAME", "vision_obstruction")
)

for (spec in flag_specs) {
  flags <- make_crash_flags(spec[[1L]], spec[[2L]], spec[[3L]])
  dt_crss_crash_working <- left_join_checked(
    dt_crss_crash_working, flags, "case_number", paste0(spec[[1L]], " join")
  )
}

# Selected vehicle categorical fields are represented as any-vehicle indicators.
vehicle_flag_specs <- list(
  list("BODY_TYPNAME", "vehicle_body_type"),
  list("V_CONFIGNAME", "vehicle_configuration"),
  list("SPEEDRELNAME", "any_vehicle_speed_relation"),
  list("V_ALCH_IMNAME", "any_driver_alcohol"),
  list("VTRAFWAYNAME", "any_vehicle_trafficway"),
  list("VALIGNNAME", "any_vehicle_road_alignment"),
  list("VPROFILENAME", "any_vehicle_road_grade"),
  list("VSURCONDNAME", "any_vehicle_surface_condition")
)
for (spec in vehicle_flag_specs) {
  x <- unique(vehicle[!is.na(get(spec[[1L]])), .(
    CASENUM, level = get(spec[[1L]])
  )])
  x[, feature := paste0(spec[[2L]], "__", safe_level_name(level))]
  x[, value := TRUE]
  flags <- dcast(x, CASENUM ~ feature, value.var = "value",
                 fun.aggregate = any, fill = FALSE)
  setnames(flags, "CASENUM", "case_number")
  dt_crss_crash_working <- left_join_checked(
    dt_crss_crash_working, flags, "case_number", paste0(spec[[1L]], " join")
  )
}

indicator_columns <- names(dt_crss_crash_working)[
  vapply(dt_crss_crash_working, is.logical, logical(1L))
]
for (j in indicator_columns) {
  set(dt_crss_crash_working, which(is.na(dt_crss_crash_working[[j]])), j, FALSE)
}

# Match the occupant dataset's reproducible crash-level fold allocation.
set.seed(2024)
crashes <- sort(unique(dt_crss_crash_working$case_number))
fold_map <- data.table(
  case_number = crashes,
  fold = sample(rep(1:10, length.out = length(crashes)))
)
dt_crss_crash_working <- left_join_checked(
  dt_crss_crash_working, fold_map, "case_number", "fold join"
)

target_columns <- c("serious_or_fatal_injury", "injured_pedestrian")

setcolorder(dt_crss_crash_working, c(
  "case_number", "fold", target_columns,
  "weight", "psu", "psu_var", "psu_stratum",
  setdiff(names(dt_crss_crash_working), c(
    "case_number", "fold", target_columns,
    "weight", "psu", "psu_var", "psu_stratum"
  ))
))
setkey(dt_crss_crash_working, case_number)
assert_unique_key(dt_crss_crash_working, "case_number", "final crash dataset")

if (nrow(dt_crss_crash_working) != nrow(accident_source)) {
  stop("Final crash dataset does not contain every accident.csv row")
}
if (any(c("any_vehicle_towed", "number_vehicles_towed",
          "maximum_vehicle_damage") %chin% names(dt_crss_crash_working))) {
  stop("A deliberately omitted towing/damage target is present")
}

schema <- data.table(variable = names(dt_crss_crash_working))
schema[, source := fcase(
  variable == "case_number", "accident.csv",
  variable == "fold", "derived",
  variable %chin% c(
    occupant_count_columns, occupant_flag_columns,
    "youngest_occupant_age", "oldest_occupant_age", "mean_occupant_age"
  ), "person.csv",
  variable == "serious_or_fatal_injury", "accident.csv",
  variable == "injured_pedestrian", "person.csv",
  variable %chin% c("commercial_vehicle_involved",
                    "hazardous_material_involved",
                    "oldest_vehicle_model_year", "newest_vehicle_model_year",
                    "mean_vehicle_model_year", "maximum_speed_limit",
                    "maximum_reported_travel_speed"), "vehicle.csv",
  startsWith(variable, "crash_factor__"), "crashrf.csv",
  startsWith(variable, "weather__"), "weather.csv",
  startsWith(variable, "vehicle_special_factor__"), "vehiclesf.csv",
  startsWith(variable, "driver_factor__"), "driverrf.csv",
  startsWith(variable, "driver_distraction__"), "distract.csv",
  startsWith(variable, "driver_impairment__"), "drimpair.csv",
  startsWith(variable, "vehicle_contributing_factor__"), "factor.csv",
  startsWith(variable, "avoidance_manoeuvre__"), "maneuver.csv",
  startsWith(variable, "driver_violation__"), "violatn.csv",
  startsWith(variable, "vision_obstruction__"), "vision.csv",
  startsWith(variable, "vehicle_body_type__") |
    startsWith(variable, "vehicle_configuration__") |
    startsWith(variable, "any_vehicle_"), "vehicle.csv",
  default = "accident.csv"
)]
schema[, model_role := fcase(
  variable == "case_number", "identifier",
  variable == "fold", "partition",
  variable %chin% c("weight", "psu", "psu_var", "psu_stratum"),
  "survey_design",
  variable %chin% target_columns, "target",
  default = "candidate_predictor"
)]

# A separate table enforces the information boundary for Option 3.  It is
# intentionally impossible to select collision mechanics or injury summaries
# from this object by accident. Retrospective descriptions of pre-impact
# conditions are retained but labelled separately in the schema.
journey_start_base <- c(
  "region", "urbanicity", "crash_month", "day_of_week", "crash_hour",
  "crash_minute", "within_interchange_area", "junction_location",
  "intersection_type", "relation_to_road", "work_zone", "light_condition",
  "primary_weather", "interstate_highway",
  occupant_count_columns, occupant_flag_columns,
  "youngest_occupant_age", "oldest_occupant_age", "mean_occupant_age",
  "commercial_vehicle_involved", "hazardous_material_involved",
  "oldest_vehicle_model_year", "newest_vehicle_model_year",
  "mean_vehicle_model_year", "maximum_speed_limit",
  "maximum_reported_travel_speed", "crash_alcohol_involvement"
)

# These crash-factor levels describe pre-existing road/location conditions.
# Other crashrf levels describe the collision or transient precipitating events
# and are deliberately not admitted.
journey_start_crash_context <- c(
  "crash_factor__obstructed_crosswalks",
  "crash_factor__other_maintenance_or_construction_created_condition",
  "crash_factor__regular_congestion",
  "crash_factor__related_to_a_bus_stop",
  "crash_factor__surface_under_water",
  "crash_factor__surface_washed_out_caved_in_road_slippage",
  "crash_factor__toll_booth_plaza_related",
  "crash_factor__within_designated_school_zone"
)

journey_start_prefixes <- c(
  "weather__", "vehicle_contributing_factor__", "vision_obstruction__",
  "driver_violation__", "vehicle_special_factor__",
  "driver_factor__", "driver_distraction__", "driver_impairment__",
  "avoidance_manoeuvre__", "any_vehicle_speed_relation__",
  "any_driver_alcohol__",
  "vehicle_body_type__", "vehicle_configuration__",
  "any_vehicle_trafficway__", "any_vehicle_road_alignment__",
  "any_vehicle_road_grade__", "any_vehicle_surface_condition__"
)
journey_start_prefixed <- names(dt_crss_crash_working)[vapply(
  names(dt_crss_crash_working),
  function(x) any(startsWith(x, journey_start_prefixes)),
  logical(1L)
)]
journey_start_predictors <- unique(c(
  journey_start_base, journey_start_crash_context, journey_start_prefixed
))
missing_journey_start <- setdiff(journey_start_predictors,
                                 names(dt_crss_crash_working))
if (length(missing_journey_start)) {
  stop("Missing journey-start fields: ",
       paste(missing_journey_start, collapse = ", "))
}

journey_start_admin <- c(
  "case_number", "fold", target_columns,
  "weight", "psu", "psu_var", "psu_stratum"
)
dt_crss_accident <- dt_crss_crash_working[, c(
  journey_start_admin, journey_start_predictors
), with = FALSE]
setkey(dt_crss_accident, case_number)
assert_unique_key(dt_crss_accident, "case_number",
                  "journey-start severity dataset")

post_crash_exact <- c(
  "first_harmful_event", "manner_of_collision", "school_bus_related",
  "vehicle_count", "maximum_injury_severity"
)
post_crash_prefixes <- c(
  "vehicle_event__"
)
forbidden_journey_start <- c(
  intersect(names(dt_crss_accident), post_crash_exact),
  names(dt_crss_accident)[vapply(
    names(dt_crss_accident),
    function(x) any(startsWith(x, post_crash_prefixes)),
    logical(1L)
  )]
)
if (length(forbidden_journey_start)) {
  stop("Post-crash or alternative-outcome fields entered journey-start data: ",
       paste(forbidden_journey_start, collapse = ", "))
}

journey_schema <- schema[match(names(dt_crss_accident), variable)]
journey_schema[, model_role := fcase(
  variable == "case_number", "identifier",
  variable == "fold", "partition",
  variable %chin% target_columns, "target",
  variable %chin% c("weight", "psu", "psu_var", "psu_stratum"),
  "survey_design",
  default = "predictor"
)]
journey_schema[, information_timing := fcase(
  model_role != "predictor", "not_a_predictor",
  startsWith(variable, "vehicle_contributing_factor__") |
    startsWith(variable, "vision_obstruction__") |
    startsWith(variable, "driver_violation__") |
    startsWith(variable, "vehicle_special_factor__") |
    startsWith(variable, "driver_factor__") |
    startsWith(variable, "driver_distraction__") |
    startsWith(variable, "driver_impairment__") |
    startsWith(variable, "avoidance_manoeuvre__") |
    startsWith(variable, "any_vehicle_speed_relation__") |
    startsWith(variable, "any_driver_alcohol__") |
    variable %chin% c("maximum_reported_travel_speed",
                      "crash_alcohol_involvement"),
  "existed_before_collision_but_police_reported",
  default = "available_before_collision"
)]
fwrite(journey_schema,
       file.path(metadata_dir, "dt_crss_accident_schema.csv"))

journey_report <- list(
  source_year = 2024L,
  built_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  rows = nrow(dt_crss_accident),
  columns = ncol(dt_crss_accident),
  predictors = length(journey_start_predictors),
  targets = target_columns,
  target_counts = list(
    serious_or_fatal_injury = sum(
      dt_crss_accident$serious_or_fatal_injury == 1L
    ),
    injured_pedestrian = sum(dt_crss_accident$injured_pedestrian == 1L)
  ),
  collision_consequence_features = 0L,
  retrospective_preimpact_predictors = sum(
    journey_schema$information_timing ==
      "existed_before_collision_but_police_reported"
  ),
  duplicate_crash_keys = dt_crss_accident[, anyDuplicated(case_number)]
)
jsonlite::write_json(
  journey_report,
  file.path(metadata_dir, "dt_crss_accident_build.json"),
  pretty = TRUE, auto_unbox = TRUE
)

save(dt_crss_accident,
     file = file.path(data_dir, "dt_crss_accident.rda"),
     compress = "xz")

message(
  "Built dt_crss_accident: ",
  format(nrow(dt_crss_accident), big.mark = ","), " rows x ",
  format(ncol(dt_crss_accident), big.mark = ","), " columns"
)
