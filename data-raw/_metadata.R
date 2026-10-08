expected_source_columns <- c(
  accident = 80L, cevent = 22L, crashrf = 14L, damage = 15L,
  distract = 15L, drimpair = 15L, driverrf = 15L, factor = 15L,
  maneuver = 15L, nmcrash = 16L, nmdistract = 16L, nmimpair = 16L,
  nmprior = 16L, parkwork = 105L, pbtype = 54L, person = 112L,
  personrf = 16L, pvehiclesf = 15L, safetyeq = 26L, vehicle = 167L,
  vehiclesf = 15L, vevent = 24L, violatn = 15L, vision = 15L,
  vpicdecode = 202L, vpictrailerdecode = 40L, vsoe = 18L,
  weather = 14L
)

file_decisions <- data.table::data.table(
  file = names(expected_source_columns),
  decision = c(
    "core", "retained_redundant", "aggregate_include", "aggregate_post_crash",
    "aggregate_include", "aggregate_include", "aggregate_include",
    "aggregate_include", "aggregate_include", "outside_population",
    "outside_population", "outside_population", "outside_population",
    "outside_population", "outside_population", "core",
    "aggregate_include", "outside_population", "outside_population", "core",
    "aggregate_include", "aggregate_include", "aggregate_include",
    "aggregate_include", "selected_include", "retained_not_used",
    "retained_redundant", "aggregate_include"
  )
)

stopifnot(
  length(expected_source_columns) == 28L,
  nrow(file_decisions) == 28L,
  !anyDuplicated(file_decisions$file)
)

outcome_leakage_source_fields <- c(
  "MAX_SEV", "MAX_SEVNAME", "MAXSEV_IM", "MAXSEV_IMNAME",
  "NUM_INJ", "NUM_INJNAME", "NO_INJ_IM", "NO_INJ_IMNAME",
  "MAX_VSEV", "MAX_VSEVNAME", "MXVSEV_IM", "MXVSEV_IMNAME",
  "NUM_INJV", "NUM_INJVNAME", "NUMINJ_IM", "NUMINJ_IMNAME",
  "HOSPITAL", "HOSPITALNAME"
)

person_types_in_scope <- c(
  "Driver of a Motor Vehicle In-Transport",
  "Passenger of a Motor Vehicle In-Transport"
)
