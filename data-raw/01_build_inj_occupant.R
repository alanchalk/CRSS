#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
})

source(file.path("data-raw", "_metadata.R"))

raw_dir <- file.path("data-raw", "CRSS2024CSV")
data_dir <- "data"
metadata_dir <- file.path("inst", "extdata")

if (!dir.exists(raw_dir)) {
  stop("Raw CRSS directory not found. Run data-raw/00_download_crss_2024.R first.")
}

dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(metadata_dir, recursive = TRUE, showWarnings = FALSE)

source_files <- sort(list.files(raw_dir, pattern = "[.]csv$"))
expected_files <- sort(paste0(names(expected_source_columns), ".csv"))
if (!identical(source_files, expected_files)) {
  stop(
    "The raw directory does not contain exactly the expected 28 CSV files.\n",
    "Missing: ", paste(setdiff(expected_files, source_files), collapse = ", "), "\n",
    "Unexpected: ", paste(setdiff(source_files, expected_files), collapse = ", ")
  )
}

actual_columns <- vapply(names(expected_source_columns), function(stem) {
  ncol(fread(file.path(raw_dir, paste0(stem, ".csv")), nrows = 0L))
}, integer(1L))

if (!identical(unname(actual_columns), unname(expected_source_columns))) {
  bad <- names(actual_columns)[actual_columns != expected_source_columns]
  stop(
    "Unexpected source column count: ",
    paste0(
      bad, " (expected ", expected_source_columns[bad],
      ", found ", actual_columns[bad], ")",
      collapse = "; "
    )
  )
}

snake_name <- function(x) {
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("(^_+|_+$)", "", x)
  x <- gsub("_+", "_", x)
  x
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
  setnames(x, old = names(mapping), new = unname(mapping))
  x
}

make_flags <- function(file, key, label_col, prefix) {
  x <- fread(
    file.path(raw_dir, paste0(file, ".csv")),
    select = c(key, label_col),
    na.strings = c("", "NA")
  )
  x <- unique(x[!is.na(get(label_col)), c(key, label_col), with = FALSE])
  x[, feature := paste0(prefix, "__", safe_level_name(get(label_col)))]
  x[, value := TRUE]
  x[, (label_col) := NULL]
  out <- dcast(x, formula = as.formula(paste(paste(key, collapse = " + "), "~ feature")),
               value.var = "value", fun.aggregate = any, fill = FALSE)
  assert_unique_key(out, key, paste0(file, " indicators"))
  out
}

left_join_checked <- function(x, y, by, label) {
  assert_unique_key(y, by, label)
  before <- nrow(x)
  out <- merge(x, y, by = by, all.x = TRUE, sort = FALSE)
  if (nrow(out) != before) stop(label, " changed the occupant row count")
  out
}

# Person is the base because it defines the unit, population and outcome.
person_source <- fread(file.path(raw_dir, "person.csv"), na.strings = c("", "NA"))
assert_unique_key(person_source, c("CASENUM", "VEH_NO", "PER_NO"), "person.csv")

person <- person_source[PER_TYPNAME %chin% person_types_in_scope, .(
  CASENUM,
  VEH_NO,
  PER_NO,
  PSU,
  PSU_VAR,
  PSUSTRAT,
  WEIGHT,
  AGE_IM,
  SEX_IMNAME,
  PER_TYPNAME,
  INJ_SEVNAME,
  INJSEV_IMNAME,
  SEAT_IMNAME,
  REST_USENAME,
  REST_MISNAME,
  HELM_USENAME,
  HELM_MISNAME,
  AIR_BAGNAME,
  EJECT_IMNAME,
  PERALCH_IMNAME,
  ALC_STATUSNAME,
  ATST_TYPNAME,
  ALC_RES,
  DRUGSNAME,
  LOCATIONNAME
)]

person <- rename_columns(person, c(
  CASENUM = "case_number",
  VEH_NO = "vehicle_number",
  PER_NO = "person_number",
  PSU = "psu",
  PSU_VAR = "psu_var",
  PSUSTRAT = "psu_stratum",
  WEIGHT = "weight",
  AGE_IM = "age_years",
  SEX_IMNAME = "sex",
  PER_TYPNAME = "person_type",
  INJ_SEVNAME = "injury_severity_observed",
  INJSEV_IMNAME = "injury_severity_imputed",
  SEAT_IMNAME = "seat_position",
  REST_USENAME = "restraint_use",
  REST_MISNAME = "restraint_misuse",
  HELM_USENAME = "helmet_use",
  HELM_MISNAME = "helmet_misuse",
  AIR_BAGNAME = "air_bag",
  EJECT_IMNAME = "ejection",
  PERALCH_IMNAME = "person_alcohol_involvement",
  ALC_STATUSNAME = "alcohol_test_status",
  ATST_TYPNAME = "alcohol_test_type",
  ALC_RES = "alcohol_test_result",
  DRUGSNAME = "police_reported_drug_involvement",
  LOCATIONNAME = "nonmotorist_location"
))

person[, injured := fifelse(
  injury_severity_imputed == "No Apparent Injury (O)", 0L,
  fifelse(injury_severity_imputed == "Died Prior to Crash*", NA_integer_, 1L)
)]
person[, serious_or_fatal_injury := fifelse(
  injury_severity_imputed %chin% c(
    "Suspected Serious Injury (A)", "Fatal Injury (K)"
  ),
  1L,
  fifelse(injury_severity_imputed == "Died Prior to Crash*", NA_integer_, 0L)
)]

accident_source <- fread(file.path(raw_dir, "accident.csv"), na.strings = c("", "NA"))
assert_unique_key(accident_source, "CASENUM", "accident.csv")
accident <- accident_source[, .(
  CASENUM,
  REGIONNAME,
  URBANICITYNAME,
  PEDS,
  PERNOTMVIT,
  VE_TOTAL,
  VE_FORMS,
  PVH_INVL,
  PERMVIT,
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
  ALCHL_IMNAME
)]
accident <- rename_columns(accident, c(
  CASENUM = "case_number",
  REGIONNAME = "region",
  URBANICITYNAME = "urbanicity",
  PEDS = "pedestrians_in_crash",
  PERNOTMVIT = "people_not_in_motor_vehicle_in_transport",
  VE_TOTAL = "vehicles_total",
  VE_FORMS = "vehicles_in_transport",
  PVH_INVL = "parked_working_vehicles",
  PERMVIT = "people_in_motor_vehicles_in_transport",
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
  ALCHL_IMNAME = "crash_alcohol_involvement"
))

vehicle_source <- fread(file.path(raw_dir, "vehicle.csv"), na.strings = c("", "NA"))
assert_unique_key(vehicle_source, c("CASENUM", "VEH_NO"), "vehicle.csv")
vehicle <- vehicle_source[, .(
  CASENUM,
  VEH_NO,
  NUMOCCS,
  UNITTYPENAME,
  HIT_RUNNAME,
  MDLYR_IM,
  VPICMAKENAME,
  VPICMODELNAME,
  VPICBODYCLASSNAME,
  BODY_TYPNAME,
  ICFINALBODYNAME,
  GVWR_FROMNAME,
  GVWR_TONAME,
  TOW_VEHNAME,
  J_KNIFENAME,
  V_CONFIGNAME,
  CARGO_BTNAME,
  HAZ_INVNAME,
  BUS_USENAME,
  SPEC_USENAME,
  EMER_USENAME,
  TRAV_SP,
  UNDEROVERRIDENAME,
  ROLLOVERNAME,
  ROLINLOCNAME,
  IMPACT1_IMNAME,
  DEFORMEDNAME,
  TOWEDNAME,
  VEVENT_IMNAME,
  FIRE_EXPNAME,
  DR_PRESNAME,
  V_ALCH_IMNAME,
  SPEEDRELNAME,
  VTRAFWAYNAME,
  VNUM_LAN,
  VSPD_LIM,
  VALIGNNAME,
  VPROFILENAME,
  VSURCONDNAME,
  VTRAFCONNAME,
  VTCONT_FNAME,
  PCRASH1_IMNAME,
  P_CRASH2NAME,
  P_CRASH3NAME,
  PCRASH4NAME,
  PCRASH5NAME,
  ACC_TYPENAME
)]
vehicle <- rename_columns(vehicle, c(
  CASENUM = "case_number",
  VEH_NO = "vehicle_number",
  NUMOCCS = "vehicle_occupants",
  UNITTYPENAME = "unit_type",
  HIT_RUNNAME = "hit_and_run",
  MDLYR_IM = "vehicle_model_year",
  VPICMAKENAME = "vehicle_make",
  VPICMODELNAME = "vehicle_model",
  VPICBODYCLASSNAME = "vehicle_body_class",
  BODY_TYPNAME = "vehicle_body_type",
  ICFINALBODYNAME = "final_body_type",
  GVWR_FROMNAME = "gross_vehicle_weight_rating_from",
  GVWR_TONAME = "gross_vehicle_weight_rating_to",
  TOW_VEHNAME = "trailing_units",
  J_KNIFENAME = "jackknife",
  V_CONFIGNAME = "vehicle_configuration",
  CARGO_BTNAME = "cargo_body_type",
  HAZ_INVNAME = "hazardous_material_involvement",
  BUS_USENAME = "bus_use",
  SPEC_USENAME = "special_use",
  EMER_USENAME = "emergency_use",
  TRAV_SP = "travel_speed",
  UNDEROVERRIDENAME = "underride_override",
  ROLLOVERNAME = "rollover",
  ROLINLOCNAME = "rollover_location",
  IMPACT1_IMNAME = "initial_impact_point",
  DEFORMEDNAME = "damage_extent",
  TOWEDNAME = "vehicle_towed",
  VEVENT_IMNAME = "most_harmful_event",
  FIRE_EXPNAME = "fire_or_explosion",
  DR_PRESNAME = "driver_presence",
  V_ALCH_IMNAME = "driver_alcohol_involvement",
  SPEEDRELNAME = "speed_related",
  VTRAFWAYNAME = "trafficway_description",
  VNUM_LAN = "number_of_lanes",
  VSPD_LIM = "speed_limit",
  VALIGNNAME = "road_alignment",
  VPROFILENAME = "road_grade",
  VSURCONDNAME = "road_surface_condition",
  VTRAFCONNAME = "traffic_control_device",
  VTCONT_FNAME = "traffic_control_functioning",
  PCRASH1_IMNAME = "critical_precrash_event",
  P_CRASH2NAME = "critical_event_detail",
  P_CRASH3NAME = "attempted_avoidance_manoeuvre",
  PCRASH4NAME = "preimpact_stability",
  PCRASH5NAME = "preimpact_location",
  ACC_TYPENAME = "crash_type"
))

dt_crss_inj_occupant <- left_join_checked(
  person, vehicle,
  by = c("case_number", "vehicle_number"),
  label = "vehicle join"
)
dt_crss_inj_occupant <- left_join_checked(
  dt_crss_inj_occupant, accident,
  by = "case_number",
  label = "accident join"
)

# Multi-response source tables. Sentinel categories such as "None Noted" and
# "Not Reported" are retained rather than silently converted to absence.
flag_specs <- list(
  list("crashrf", "CASENUM", "CRASHRFNAME", "crash_factor", "crash"),
  list("weather", "CASENUM", "WEATHERNAME", "weather", "crash"),
  list("vehiclesf", c("CASENUM", "VEH_NO"), "VEHICLESFNAME", "vehicle_special_factor", "vehicle"),
  list("driverrf", c("CASENUM", "VEH_NO"), "DRIVERRFNAME", "driver_factor", "vehicle"),
  list("distract", c("CASENUM", "VEH_NO"), "DRDISTRACTNAME", "driver_distraction", "vehicle"),
  list("drimpair", c("CASENUM", "VEH_NO"), "DRIMPAIRNAME", "driver_impairment", "vehicle"),
  list("factor", c("CASENUM", "VEH_NO"), "VEHICLECCNAME", "vehicle_contributing_factor", "vehicle"),
  list("maneuver", c("CASENUM", "VEH_NO"), "MANEUVERNAME", "avoidance_manoeuvre", "vehicle"),
  list("violatn", c("CASENUM", "VEH_NO"), "VIOLATIONNAME", "driver_violation", "vehicle"),
  list("vision", c("CASENUM", "VEH_NO"), "VISIONNAME", "vision_obstruction", "vehicle"),
  list("personrf", c("CASENUM", "VEH_NO", "PER_NO"), "PERSONRFNAME", "person_factor", "person"),
  list("damage", c("CASENUM", "VEH_NO"), "DAMAGENAME", "postcrash_damaged_area", "vehicle")
)

for (spec in flag_specs) {
  flags <- make_flags(spec[[1L]], spec[[2L]], spec[[3L]], spec[[4L]])
  setnames(
    flags,
    old = spec[[2L]],
    new = c("case_number", "vehicle_number", "person_number")[seq_along(spec[[2L]])]
  )
  join_key <- switch(
    spec[[5L]],
    crash = "case_number",
    vehicle = c("case_number", "vehicle_number"),
    person = c("case_number", "vehicle_number", "person_number")
  )
  dt_crss_inj_occupant <- left_join_checked(
    dt_crss_inj_occupant, flags, join_key,
    paste0(spec[[1L]], " join")
  )
}

# Vehicle event histories are summarized before the person-level join.
vevent <- fread(
  file.path(raw_dir, "vevent.csv"),
  select = c("CASENUM", "VEH_NO", "VEVENTNUM", "SOENAME", "AOI1NAME"),
  na.strings = c("", "NA")
)
setorder(vevent, CASENUM, VEH_NO, VEVENTNUM)
vevent_summary <- vevent[, .(
  vehicle_event_count = .N,
  first_vehicle_event = first(SOENAME),
  last_vehicle_event = last(SOENAME),
  first_vehicle_impact_area = first(AOI1NAME)
), by = .(CASENUM, VEH_NO)]
vevent_flags <- copy(vevent[!is.na(SOENAME), .(CASENUM, VEH_NO, SOENAME)])
vevent_flags[, feature := paste0("vehicle_event__", safe_level_name(SOENAME))]
vevent_flags[, value := TRUE]
vevent_flags <- dcast(
  unique(vevent_flags[, .(CASENUM, VEH_NO, feature, value)]),
  CASENUM + VEH_NO ~ feature,
  value.var = "value",
  fun.aggregate = any,
  fill = FALSE
)
vevent_summary <- merge(
  vevent_summary, vevent_flags,
  by = c("CASENUM", "VEH_NO"), all.x = TRUE, sort = FALSE
)
setnames(vevent_summary, c("CASENUM", "VEH_NO"), c("case_number", "vehicle_number"))
dt_crss_inj_occupant <- left_join_checked(
  dt_crss_inj_occupant, vevent_summary,
  c("case_number", "vehicle_number"), "vevent join"
)

# vPIC contains 202 columns. Keep interpretable measurements and English
# specifications; omit paired internal IDs, free-text notes and sparse detail.
vpic_keep <- c(
  "CASENUM", "VEH_NO", "VINDECODEERROR", "VEHICLETYPE", "BODYCLASS",
  "DOORSCOUNT", "WHEELBASETYPE", "CURBWEIGHTLB", "WHEELBASEIN_FROM",
  "WHEELBASEIN_TO", "WHEELSCOUNT", "SEATSCOUNT", "SEATROWSCOUNT",
  "TRANSMISSIONSPEEDS", "TRANSMISSIONSTYLE", "DRIVETYPE",
  "BRAKESYSTEMTYPE", "ENGINECONFIGURATION", "ENGINECYLINDERSCOUNT",
  "ENGINEBRAKEHP_FROM", "ENGINEBRAKEHP_TO", "DISPLACEMENTL",
  "FUELTYPEPRIMARY", "ENGINEELECTRIFICATIONLEVEL", "SEATBELTTYPE",
  "PRETENSIONER", "AIRBAGLOCFRONT", "AIRBAGLOCKNEE", "AIRBAGLOCSIDE",
  "AIRBAGLOCCURTAIN", "FORWARDCOLLISIONWARNING", "DYNAMICBRAKESUPPORT",
  "CRASHIMMINENTBRAKING", "PEDESTRIANAUTOEMERGENCYBRAKING",
  "BLINDSPOTWARNING", "LANEDEPARTUREWARNING", "LANEKEEPINGASSISTANCE",
  "BACKUPCAMERA", "REARCROSSTRAFFICALERT", "PARKASSIST",
  "DAYTIMERUNNINGLIGHT", "HEADLAMPLIGHTSOURCE", "ADAPTIVECRUISECONTROL",
  "ANTILOCKBRAKESYSTEM", "ELECTRONICSTABILITYCONTROL", "TPMS",
  "AUTOMATICCRASHNOTIFICATION", "EVENTDATARECORDER", "TRACTIONCONTROL"
)
vpic <- fread(file.path(raw_dir, "vpicdecode.csv"), select = vpic_keep,
              na.strings = c("", "NA"))
assert_unique_key(vpic, c("CASENUM", "VEH_NO"), "vpicdecode.csv")
setnames(vpic, c("CASENUM", "VEH_NO"), c("case_number", "vehicle_number"))
setnames(
  vpic,
  old = setdiff(names(vpic), c("case_number", "vehicle_number")),
  new = paste0("vpic_", snake_name(setdiff(names(vpic), c("case_number", "vehicle_number"))))
)
dt_crss_inj_occupant <- left_join_checked(
  dt_crss_inj_occupant, vpic,
  c("case_number", "vehicle_number"), "vpic join"
)

# Missing indicator values arise when an otherwise valid key has no matching
# selected response. Preserve missingness for vPIC and scalar fields.
indicator_columns <- grep(
  "^(crash_factor|weather|vehicle_special_factor|driver_factor|driver_distraction|driver_impairment|vehicle_contributing_factor|avoidance_manoeuvre|driver_violation|vision_obstruction|person_factor|postcrash_damaged_area|vehicle_event)__",
  names(dt_crss_inj_occupant), value = TRUE
)
for (j in indicator_columns) {
  set(dt_crss_inj_occupant, which(is.na(dt_crss_inj_occupant[[j]])), j, FALSE)
}

# Ten reproducible folds assigned at crash level, never at person level.
set.seed(2024)
crashes <- sort(unique(dt_crss_inj_occupant$case_number))
fold_map <- data.table(
  case_number = crashes,
  fold = sample(rep(1:10, length.out = length(crashes)))
)
dt_crss_inj_occupant <- left_join_checked(
  dt_crss_inj_occupant, fold_map, "case_number", "fold join"
)

setcolorder(
  dt_crss_inj_occupant,
  c(
    "case_number", "vehicle_number", "person_number", "fold",
    "injured", "serious_or_fatal_injury",
    "injury_severity_observed", "injury_severity_imputed",
    "weight", "psu", "psu_var", "psu_stratum",
    setdiff(
      names(dt_crss_inj_occupant),
      c(
        "case_number", "vehicle_number", "person_number", "fold",
        "injured", "serious_or_fatal_injury",
        "injury_severity_observed", "injury_severity_imputed",
        "weight", "psu", "psu_var", "psu_stratum"
      )
    )
  )
)
setkey(dt_crss_inj_occupant, case_number, vehicle_number, person_number)

assert_unique_key(
  dt_crss_inj_occupant,
  c("case_number", "vehicle_number", "person_number"),
  "final dataset"
)
if (any(outcome_leakage_source_fields %chin% names(dt_crss_inj_occupant))) {
  stop("A source outcome-leakage field survived under its original name")
}
if (dt_crss_inj_occupant[, uniqueN(fold), by = case_number][, max(V1)] != 1L) {
  stop("A crash was assigned to more than one fold")
}

# Machine-readable provenance and modelling roles.
schema <- data.table(variable = names(dt_crss_inj_occupant))
schema[, source := fcase(
  variable %chin% c("case_number", "fold"), "derived",
  variable %chin% c("vehicle_number", "person_number", "age_years", "sex",
                    "person_type", "injury_severity_observed",
                    "injury_severity_imputed", "injured",
                    "serious_or_fatal_injury", "seat_position", "restraint_use",
                    "restraint_misuse", "helmet_use", "helmet_misuse",
                    "air_bag", "ejection", "person_alcohol_involvement",
                    "alcohol_test_status", "alcohol_test_type",
                    "alcohol_test_result", "police_reported_drug_involvement",
                    "nonmotorist_location", "weight", "psu", "psu_var",
                    "psu_stratum"), "person.csv",
  startsWith(variable, "person_factor__"), "personrf.csv",
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
  startsWith(variable, "postcrash_damaged_area__"), "damage.csv",
  startsWith(variable, "vehicle_event") |
    variable %chin% c("first_vehicle_event", "last_vehicle_event",
                      "first_vehicle_impact_area"), "vevent.csv",
  startsWith(variable, "vpic_"), "vpicdecode.csv",
  variable %chin% names(accident), "accident.csv",
  default = "vehicle.csv"
)]
schema[, timing := fcase(
  variable %chin% c("case_number", "vehicle_number", "person_number"), "identifier",
  variable %chin% c("weight", "psu", "psu_var", "psu_stratum"), "survey_design",
  variable == "fold", "partition",
  variable %chin% c("injured", "serious_or_fatal_injury",
                    "injury_severity_observed", "injury_severity_imputed"), "outcome",
  startsWith(variable, "postcrash_") |
    variable %chin% c("damage_extent", "vehicle_towed"), "post_crash",
  variable %chin% c("initial_impact_point", "underride_override", "rollover",
                    "rollover_location", "most_harmful_event", "fire_or_explosion",
                    "vehicle_event_count", "first_vehicle_event",
                    "last_vehicle_event", "first_vehicle_impact_area") |
    startsWith(variable, "vehicle_event__"), "crash_mechanism",
  source %chin% c("person.csv", "personrf.csv"), "person",
  default = "context"
)]
schema[, model_role := fcase(
  timing == "identifier", "identifier",
  timing == "survey_design", "survey_design",
  timing == "partition", "partition",
  timing == "outcome", "outcome",
  timing == "post_crash", "secondary_triage_predictor",
  default = "primary_predictor"
)]

fwrite(schema, file.path(metadata_dir, "dt_crss_inj_occupant_schema.csv"))

build_report <- list(
  source_year = 2024L,
  built_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  source_files = length(source_files),
  rows = nrow(dt_crss_inj_occupant),
  columns = ncol(dt_crss_inj_occupant),
  crashes = uniqueN(dt_crss_inj_occupant$case_number),
  vehicles = uniqueN(dt_crss_inj_occupant[, .(case_number, vehicle_number)]),
  drivers = dt_crss_inj_occupant[person_type == person_types_in_scope[1L], .N],
  passengers = dt_crss_inj_occupant[person_type == person_types_in_scope[2L], .N],
  injured_nonmissing = dt_crss_inj_occupant[!is.na(injured), .N],
  injured_count = dt_crss_inj_occupant[injured == 1L, .N],
  duplicate_person_keys = dt_crss_inj_occupant[
    , sum(duplicated(.SD)),
    .SDcols = c("case_number", "vehicle_number", "person_number")
  ],
  fold_is_crash_grouped = TRUE,
  source_column_counts_validated = TRUE,
  excluded_outcome_leakage_fields = outcome_leakage_source_fields
)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required to write build metadata")
}
jsonlite::write_json(
  build_report,
  file.path(metadata_dir, "dt_crss_inj_occupant_build.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)

save(
  dt_crss_inj_occupant,
  file = file.path(data_dir, "dt_crss_inj_occupant.rda"),
  compress = "xz"
)

message(
  "Built dt_crss_inj_occupant: ",
  format(nrow(dt_crss_inj_occupant), big.mark = ","), " rows x ",
  format(ncol(dt_crss_inj_occupant), big.mark = ","), " columns"
)
