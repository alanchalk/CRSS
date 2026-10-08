# Crash-level target dataset design

## Purpose and grain

`crss_crash_targets` provides one row for every sampled 2024 CRSS crash. Its
unique key is `case_number`, corresponding to source field `CASENUM`. The table
supports several alternative insurance-relevant classification and count
targets without rebuilding the source joins for each case study.

The dataset contains crash context and aggregated vehicle/driver information.
It does not contain one row per pedestrian or other person. Person records are
used only to construct crash-level injury targets.

## Injury targets

- `any_injury`: at least one person received a possible-or-worse injury.
- `serious_or_fatal_injury`: at least one person received a suspected serious
  or fatal injury.
- `fatal_crash`: at least one person received a fatal injury.
- `number_injured`: number of people receiving possible-or-worse injury.
- `multiple_people_injured`: at least two people were injured.
- `maximum_injury_severity`: NHTSA's imputed maximum severity for the crash.
- `injured_pedestrian`: at least one pedestrian was injured.
- `injured_cyclist`: at least one bicyclist or other pedalcyclist was injured.
- `serious_vulnerable_road_user_injury`: at least one pedestrian, bicyclist, or
  other pedalcyclist received a serious or fatal injury.
- `occupant_injury`: at least one driver or passenger of a vehicle in transport
  was injured.
- `passenger_injury`: at least one passenger of a vehicle in transport was
  injured.

“Died Prior to Crash” is not counted as an injury caused by the crash.

## Other potential targets

- `rollover_crash`: at least one in-transport vehicle rolled over.
- `vehicle_fire`: at least one in-transport vehicle had a fire or explosion.
- `hit_and_run`: at least one in-transport vehicle was coded hit-and-run.
- `multi_vehicle_crash`: at least two motor vehicles in transport were involved.
- `commercial_vehicle_involved`: at least one vehicle has a truck, bus, or
  other over-10,000-pound commercial configuration.
- `hazardous_material_involved`: at least one vehicle carried hazardous
  material as defined by CRSS.

Towing and maximum vehicle-damage targets are deliberately not included.

## Predictors

Crash context comes from `accident.csv`, excluding person counts and injury
summaries. Multiple weather conditions and crash-related factors are converted
to crash-level Boolean indicators. Vehicle and driver tables are aggregated to
the crash level using counts, numerical summaries, and “any vehicle/driver”
indicators.

No event-sequence, pedestrian-type, non-motorist-action, or person-level feature
is joined as a predictor. Those sources can directly reveal that a pedestrian or
cyclist was involved and would undermine the vulnerable-road-user targets.

## Target-specific leakage

There is no universal predictor list because the dataset contains several
alternative targets. For example, `rollover_crash` is a legitimate crash
mechanism predictor for an injury model but cannot predict itself. Similarly,
`first_harmful_event` may be used for a general injury model but directly reveals
some pedestrian collisions.

`inst/extdata/crss_crash_target_exclusions.csv` records the variables that must
be excluded for each target family. At minimum, models must exclude the chosen
target, all other targets derived from the same outcome, direct counts used to
construct the target, and post-event descriptions that explicitly name it.

The ten-fold partition is assigned by crash. Survey weight, PSU, and stratum are
retained for design-aware summaries.
