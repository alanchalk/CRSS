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

crss_crash_targets <- accident_source[, .(
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
  EVENT1_IMNAME,
  MANCOL_IMNAME,
  RELJCT1_IMNAME,
  RELJCT2_IMNAME,
  TYP_INTNAME,
  REL_ROADNAME,
  WRK_ZONENAME,
  LGTCON_IMNAME,
  WEATHR_IMNAME,
  SCH_BUSNAME,
  INT_HWYNAME,
  ALCHL_IMNAME,
  VE_FORMS,
  NO_INJ_IM,
  MAXSEV_IMNAME
)]

crss_crash_targets <- rename_columns(crss_crash_targets, c(
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
  EVENT1_IMNAME = "first_harmful_event",
  MANCOL_IMNAME = "manner_of_collision",
  RELJCT1_IMNAME = "within_interchange_area",
  RELJCT2_IMNAME = "junction_location",
  TYP_INTNAME = "intersection_type",
  REL_ROADNAME = "relation_to_road",
  WRK_ZONENAME = "work_zone",
  LGTCON_IMNAME = "light_condition",
  WEATHR_IMNAME = "primary_weather",
  SCH_BUSNAME = "school_bus_related",
  INT_HWYNAME = "interstate_highway",
  ALCHL_IMNAME = "crash_alcohol_involvement",
  VE_FORMS = "vehicle_count",
  NO_INJ_IM = "number_injured",
  MAXSEV_IMNAME = "maximum_injury_severity"
))

crss_crash_targets[, any_injury := as.integer(number_injured > 0L)]
crss_crash_targets[, multiple_people_injured := as.integer(number_injured >= 2L)]
crss_crash_targets[, serious_or_fatal_injury := as.integer(
  maximum_injury_severity %chin% c(
    "Suspected Serious Injury (A)", "Fatal Injury (K)"
  )
)]
crss_crash_targets[, fatal_crash := as.integer(
  maximum_injury_severity == "Fatal Injury (K)"
)]
crss_crash_targets[, multi_vehicle_crash := as.integer(vehicle_count >= 2L)]

# Person records create subgroup injury targets only; person attributes do not
# enter the crash-level predictor set.
person <- fread(
  file.path(raw_dir, "person.csv"),
  select = c(
    "CASENUM", "PER_TYPNAME", "INJSEV_IMNAME", "AGE_IM", "SEX_IMNAME",
    "SEAT_IMNAME", "REST_USENAME"
  ),
  na.strings = c("", "NA")
)
person[, injured_person :=
         INJSEV_IMNAME != "No Apparent Injury (O)" &
         INJSEV_IMNAME != "Died Prior to Crash*"]
person[, serious_or_fatal_person := INJSEV_IMNAME %chin% c(
  "Suspected Serious Injury (A)", "Fatal Injury (K)"
)]
person[, pedestrian := PER_TYPNAME == "Pedestrian"]
person[, cyclist := PER_TYPNAME %chin% c("Bicyclist", "Other Pedalcyclist")]
person[, occupant := PER_TYPNAME %chin% person_types_in_scope]
person[, passenger :=
         PER_TYPNAME == "Passenger of a Motor Vehicle In-Transport"]

person_targets <- person[, .(
  injured_pedestrian = as.integer(any(pedestrian & injured_person)),
  injured_cyclist = as.integer(any(cyclist & injured_person)),
  serious_vulnerable_road_user_injury = as.integer(any(
    (pedestrian | cyclist) & serious_or_fatal_person
  )),
  occupant_injury = as.integer(any(occupant & injured_person)),
  passenger_injury = as.integer(any(passenger & injured_person))
), by = CASENUM]
setnames(person_targets, "CASENUM", "case_number")
crss_crash_targets <- left_join_checked(
  crss_crash_targets, person_targets, "case_number", "person target join"
)
for (j in c("injured_pedestrian", "injured_cyclist",
            "serious_vulnerable_road_user_injury", "occupant_injury",
            "passenger_injury")) {
  set(crss_crash_targets, which(is.na(crss_crash_targets[[j]])), j, 0L)
}

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
crss_crash_targets <- left_join_checked(
  crss_crash_targets, occupant_summary, "case_number", "occupant summary join"
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
  set(crss_crash_targets, which(is.na(crss_crash_targets[[j]])), j, 0L)
}
for (j in occupant_flag_columns) {
  set(crss_crash_targets, which(is.na(crss_crash_targets[[j]])), j, FALSE)
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
  rollover_crash = as.integer(any(ROLLOVERNAME == "Rollover")),
  vehicle_fire = as.integer(any(FIRE_EXPNAME == "Yes")),
  hit_and_run = as.integer(any(HIT_RUNNAME == "Yes")),
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
crss_crash_targets <- left_join_checked(
  crss_crash_targets, vehicle_summary, "case_number", "vehicle summary join"
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
  crss_crash_targets <- left_join_checked(
    crss_crash_targets, flags, "case_number", paste0(spec[[1L]], " join")
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
  crss_crash_targets <- left_join_checked(
    crss_crash_targets, flags, "case_number", paste0(spec[[1L]], " join")
  )
}

indicator_columns <- names(crss_crash_targets)[
  vapply(crss_crash_targets, is.logical, logical(1L))
]
for (j in indicator_columns) {
  set(crss_crash_targets, which(is.na(crss_crash_targets[[j]])), j, FALSE)
}

# Match the occupant dataset's reproducible crash-level fold allocation.
set.seed(2024)
crashes <- sort(unique(crss_crash_targets$case_number))
fold_map <- data.table(
  case_number = crashes,
  fold = sample(rep(1:10, length.out = length(crashes)))
)
crss_crash_targets <- left_join_checked(
  crss_crash_targets, fold_map, "case_number", "fold join"
)

target_columns <- c(
  "any_injury", "serious_or_fatal_injury", "fatal_crash",
  "number_injured", "multiple_people_injured", "maximum_injury_severity",
  "injured_pedestrian", "injured_cyclist",
  "serious_vulnerable_road_user_injury", "occupant_injury",
  "passenger_injury", "rollover_crash", "vehicle_fire", "hit_and_run",
  "multi_vehicle_crash", "commercial_vehicle_involved",
  "hazardous_material_involved"
)

setcolorder(crss_crash_targets, c(
  "case_number", "fold", target_columns,
  "weight", "psu", "psu_var", "psu_stratum",
  setdiff(names(crss_crash_targets), c(
    "case_number", "fold", target_columns,
    "weight", "psu", "psu_var", "psu_stratum"
  ))
))
setkey(crss_crash_targets, case_number)
assert_unique_key(crss_crash_targets, "case_number", "final crash dataset")

if (nrow(crss_crash_targets) != nrow(accident_source)) {
  stop("Final crash dataset does not contain every accident.csv row")
}
if (any(c("any_vehicle_towed", "number_vehicles_towed",
          "maximum_vehicle_damage") %chin% names(crss_crash_targets))) {
  stop("A deliberately omitted towing/damage target is present")
}

# Target-specific leakage rules. Patterns ending in __ refer to whole indicator
# families; consumers should treat them as starts-with exclusions.
injury_family <- c(
  "any_injury", "serious_or_fatal_injury", "fatal_crash",
  "number_injured", "multiple_people_injured", "maximum_injury_severity",
  "injured_pedestrian", "injured_cyclist",
  "serious_vulnerable_road_user_injury", "occupant_injury",
  "passenger_injury"
)
exclusions <- rbindlist(list(
  CJ(target = injury_family, excluded_variable_or_prefix = injury_family)[
    target != excluded_variable_or_prefix
  ],
  data.table(target = injury_family,
             excluded_variable_or_prefix = injury_family),
  data.table(
    target = c("injured_pedestrian", "injured_cyclist",
               "serious_vulnerable_road_user_injury"),
    excluded_variable_or_prefix = "first_harmful_event"
  ),
  data.table(
    target = rep(c("injured_pedestrian", "injured_cyclist",
                   "serious_vulnerable_road_user_injury"), each = 1L),
    excluded_variable_or_prefix = "crash_factor__non_occupant_struck_vehicle"
  ),
  data.table(
    target = c("rollover_crash", "vehicle_fire", "hit_and_run",
               "multi_vehicle_crash", "commercial_vehicle_involved",
               "hazardous_material_involved"),
    excluded_variable_or_prefix = c(
      "rollover_crash", "vehicle_fire", "hit_and_run", "vehicle_count",
      "vehicle_configuration__", "hazardous_material_involved"
    )
  ),
  data.table(
    target = "commercial_vehicle_involved",
    excluded_variable_or_prefix = "vehicle_body_type__"
  )
), use.names = TRUE)
exclusions[, reason := fifelse(
  excluded_variable_or_prefix == target,
  "Selected target cannot also be a predictor",
  "Same outcome, direct component, or explicit description would leak the target"
)]
setorder(exclusions, target, excluded_variable_or_prefix)
fwrite(exclusions,
       file.path(metadata_dir, "crss_crash_target_exclusions.csv"))

schema <- data.table(variable = names(crss_crash_targets))
schema[, source := fcase(
  variable == "case_number", "accident.csv",
  variable == "fold", "derived",
  variable %chin% c(
    occupant_count_columns, occupant_flag_columns,
    "youngest_occupant_age", "oldest_occupant_age", "mean_occupant_age"
  ), "person.csv",
  variable %chin% injury_family, "person.csv/accident.csv",
  variable %chin% c("rollover_crash", "vehicle_fire", "hit_and_run",
                    "commercial_vehicle_involved",
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
  variable %chin% target_columns, "alternative_target",
  default = "candidate_predictor"
)]
fwrite(schema, file.path(metadata_dir, "crss_crash_targets_schema.csv"))

build_report <- list(
  source_year = 2024L,
  built_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  rows = nrow(crss_crash_targets),
  columns = ncol(crss_crash_targets),
  duplicate_crash_keys = crss_crash_targets[, anyDuplicated(case_number)],
  targets = target_columns,
  target_counts = as.list(crss_crash_targets[, lapply(.SD, function(x) {
    if (is.numeric(x) || is.logical(x)) sum(x == 1L, na.rm = TRUE) else NA_integer_
  }), .SDcols = setdiff(target_columns,
                        c("number_injured", "maximum_injury_severity"))]),
  towing_and_damage_targets_included = FALSE
)
jsonlite::write_json(
  build_report,
  file.path(metadata_dir, "crss_crash_targets_build.json"),
  pretty = TRUE, auto_unbox = TRUE
)

save(crss_crash_targets,
     file = file.path(data_dir, "crss_crash_targets.rda"), compress = "xz")

message(
  "Built crss_crash_targets: ",
  format(nrow(crss_crash_targets), big.mark = ","), " rows x ",
  format(ncol(crss_crash_targets), big.mark = ","), " columns"
)
