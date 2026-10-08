# CRSS 2024 source-file inventory

Counts refer to the downloaded 2024 CSV files. Column counts include identifiers,
survey fields, coded values, and English-name versions. “Multi-response” means
that NHTSA stores one row for every selected response; those files must be
aggregated before joining to an occupant table.

| File | Rows | Columns | Grain | Contents | Case-study decision and reason |
|---|---:|---:|---|---|---|
| `accident.csv` | 51,658 | 80 | One row per crash | Crash circumstances, road, environment, time, collision and crash outcomes | **Core.** Supplies crash context. Injury totals and maximum severity are excluded as target leakage. |
| `vehicle.csv` | 90,641 | 167 | One row per in-transport vehicle | Vehicle, driver, pre-crash movement, impact and vehicle outcomes | **Core.** Supplies the occupant's vehicle and driver context. Vehicle injury summaries are excluded. |
| `person.csv` | 126,159 | 112 | One row per person | Demographics, person type, seat, restraint, airbag, ejection, alcohol and injury severity | **Core.** Defines the population, person predictors and target. |
| `parkwork.csv` | 2,554 | 105 | One row per parked/working vehicle | Parked vehicles and road maintenance, construction or utility vehicles | **Outside population.** The principal population is occupants of vehicles in transport. |
| `pbtype.csv` | 5,211 | 54 | One row per pedestrian/cyclist/personal-conveyance user | PBCAT pedestrian and bicycle crash classifications and pre-crash actions | **Outside population.** Applies to non-motorists. |
| `cevent.csv` | 84,081 | 22 | One row per crash event | Crash-wide chronological sequence of harmful and non-harmful events | **Retained, not joined.** `vevent` gives the vehicle-specific sequence required for an occupant. |
| `vevent.csv` | 125,797 | 24 | One row per event per vehicle | Vehicle-specific chronological event sequence and impact areas | **Aggregated and included.** Produces event count, first/last event, first impact area and event indicators. |
| `vsoe.csv` | 125,797 | 18 | One row per event per vehicle | Simplified subset of `vevent` | **Retained, not joined.** Redundant with the richer `vevent`. |
| `crashrf.csv` | 51,817 | 14 | Multi-response per crash | Unusual crash conditions and special circumstances | **Aggregated and included** as crash-level indicators. |
| `weather.csv` | 52,032 | 14 | Multi-response per crash | Atmospheric conditions | **Aggregated and included.** Preserves multiple simultaneous conditions beyond the primary accident field. |
| `vehiclesf.csv` | 90,641 | 15 | Multi-response per vehicle | Special circumstances associated with in-transport vehicles | **Aggregated and included** as vehicle-level indicators. |
| `pvehiclesf.csv` | 2,554 | 15 | Multi-response per parked/working vehicle | Special circumstances associated with parked/working vehicles | **Outside population.** Companion to `parkwork`. |
| `driverrf.csv` | 92,041 | 15 | Multi-response per vehicle/driver | Driver conditions, unusual situations and special circumstances | **Aggregated and included** as driver-level indicators. |
| `damage.csv` | 191,085 | 15 | One row per damaged vehicle area | Every reported damaged area | **Aggregated and retained as post-crash features.** Appropriate to triage, not a pre-impact model. |
| `distract.csv` | 90,696 | 15 | Multi-response per vehicle/driver | Driver distractions | **Aggregated and included** as driver-level indicators. |
| `drimpair.csv` | 90,761 | 15 | Multi-response per vehicle/driver | Driver physical impairment, fatigue, illness and related conditions | **Aggregated and included** as driver-level indicators. |
| `factor.csv` | 90,708 | 15 | Multi-response per vehicle | Vehicle circumstances that may have contributed to the crash | **Aggregated and included** as vehicle-level indicators. |
| `maneuver.csv` | 90,643 | 15 | Multi-response per vehicle | Driver avoidance manoeuvres | **Aggregated and included** as vehicle-level indicators. |
| `violatn.csv` | 97,551 | 15 | Multi-response per vehicle/driver | Violations charged to the driver | **Aggregated and included** as driver-level indicators. |
| `vision.csv` | 90,668 | 15 | Multi-response per vehicle/driver | Circumstances obscuring the driver's vision | **Aggregated and included** as driver-level indicators. |
| `personrf.csv` | 126,167 | 16 | Multi-response per person | Unusual person circumstances and special factors | **Aggregated and included** as person-level indicators. |
| `nmcrash.csv` | 7,469 | 16 | Multi-response per non-motorist | Contributing circumstances or improper non-motorist actions | **Outside population.** Applies to non-motorists. |
| `nmdistract.csv` | 5,250 | 16 | Multi-response per non-motorist | Non-motorist distractions | **Outside population.** Applies to non-motorists. |
| `nmimpair.csv` | 5,256 | 16 | Multi-response per non-motorist | Non-motorist physical impairments | **Outside population.** Applies to non-motorists. |
| `nmprior.csv` | 5,355 | 16 | Multi-response per non-motorist | Non-motorist actions immediately before the crash | **Outside population.** Applies to non-motorists. |
| `safetyeq.csv` | 5,249 | 26 | One row per non-motorist | Helmet, protective pads, reflective clothing, lights and other equipment | **Outside population.** Applies to non-motorists. |
| `vpicdecode.csv` | 77,959 | 202 | One row per vehicle with decoded VIN | VIN-derived construction, engine, restraint and safety-system specifications | **Selected fields included.** Interpretable vehicle construction and safety fields are retained; IDs, free text and sparse technical detail are omitted. |
| `vpictrailerdecode.csv` | 628 | 40 | One row per trailer | VIN-derived trailer characteristics | **Retained, not joined.** Applies only to a small trailer subset and not directly to occupant protection. |

The inventory is based on the NHTSA *CRSS Analytical User's Manual,
2016–2024* and is checked against the actual headers by the build script.
