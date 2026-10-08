# Guide to the CRSS 2024 source files

This guide describes the 28 CSV files in the CRSS 2024 download in prose. Row
counts refer to the downloaded 2024 files. The “rows per” description is the
natural grain of the source file, before any aggregation or joining performed
for the occupant-injury dataset.

## `accident.csv`

This is the main crash-level file. It describes when and where the crash
happened, the road and environmental conditions, the manner of collision, the
first harmful event, and crash-level injury summaries. It contains **51,658
rows: exactly one row per sampled crash**.

Example variables include:

- `MANCOL_IMNAME`: imputed manner of collision, such as “Front-to-Rear” or “Angle”
- `LGTCON_IMNAME`: imputed light condition, such as “Daylight” or “Dark - Lighted”
- `RELJCT2_IMNAME`: imputed junction location, such as “Non-Junction” or “Intersection”

## `vehicle.csv`

This file describes every vehicle participating in road traffic, including
vehicles moving or temporarily stopped in the roadway, and its driver. Parked
and working vehicles are recorded separately in `parkwork.csv`. It covers
vehicle type and model year, pre-crash movement, speed and roadway conditions,
initial impact, rollover, damage, towing, driver alcohol, and vehicle-level
injury summaries. It contains **90,641 rows: one row per such vehicle**, so a
multi-vehicle crash contributes several rows.

Example variables include:

- `PCRASH1_IMNAME`: imputed critical pre-crash event, such as “Going Straight” or “Stopped in Roadway”
- `IMPACT1_IMNAME`: imputed initial impact point, such as “12 Clock Point” or “6 Clock Point”
- `SPEEDRELNAME`: whether speed was related, such as “No” or “Yes, Too Fast for Conditions”

## `person.csv`

This file describes every person involved in a sampled crash, including
drivers, passengers, pedestrians, cyclists, and other non-motorists. It contains
demographics, person type, seating position, restraint use, airbag deployment,
ejection, alcohol information, and injury severity. It contains **126,159 rows:
one row per person**. People in the same vehicle share `CASENUM` and `VEH_NO`
but have different `PER_NO` values.

Example variables include:

- `INJSEV_IMNAME`: imputed injury severity, such as “No Apparent Injury (O)” or “Possible Injury (C)”
- `SEAT_IMNAME`: imputed seating position, such as “Front Seat, Left Side” or “Front Seat, Right Side”
- `REST_USENAME`: restraint use, such as “Shoulder and Lap Belt Used” or “None Used/Not Applicable”

## `parkwork.csv`

This is the vehicle-level file for parked vehicles and vehicles performing road
maintenance, construction, or utility work. It parallels many fields in
`vehicle.csv`, but describes vehicles that are not ordinary in-transport units.
It contains **2,554 rows: one row per parked or working vehicle**.

Example variables include:

- `PTYPENAME`: vehicle status, such as “Motor Vehicle Not In-Transport Within the Trafficway” or “Motor Vehicle Not In-Transport Outside the Trafficway”
- `PIMPACT1NAME`: initial impact point, such as “6 Clock Point” or “7 Clock Point”
- `PVEH_SEVNAME`: vehicle damage severity, such as “Minor Damage” or “Functional Damage”

## `pbtype.csv`

This file contains output from the Pedestrian and Bicycle Crash Analysis Tool.
It describes crash configurations and pre-crash actions in collisions involving
pedestrians, cyclists, and people on personal conveyances. It contains **5,211
rows: one row per relevant non-motorist**.

Example variables include:

- `PBPTYPENAME`: road-user type, such as “Pedestrian” or “Bicyclist”
- `PEDPOSNAME`: pedestrian position, such as “Travel Lane” or “Not a Pedestrian”
- `BIKECGPNAME`: bicyclist crash group, such as “Crossing Paths - Other Circumstances” or “Not a Cyclist”

## `cevent.csv`

This file records the chronological sequence of qualifying harmful and
non-harmful events across the whole crash. A crash can involve several events,
vehicles, objects, and impact areas. It contains **84,081 rows: one row per
crash event**, so a crash normally contributes one or more rows.

Example variables include:

- `EVENTNUM`: event sequence number within the crash, such as `1` or `2`
- `SOENAME`: event or object contacted, such as “Motor Vehicle In-Transport” or “Ran Off Roadway - Right”
- `AOI1NAME`: area of impact, such as “12 Clock Point” or “Non-Harmful Event”

## `vevent.csv`

This file records the event sequence separately for each in-transport vehicle.
It is the most useful event file for attaching a collision history to an
occupant's vehicle. It contains **125,797 rows: one row per event per vehicle**;
each vehicle can therefore contribute several rows.

Example variables include:

- `VEVENTNUM`: sequence number within the vehicle's events, such as `1` or `2`
- `SOENAME`: event or object contacted, such as “Motor Vehicle In-Transport” or “Ran Off Roadway - Right”
- `AOI1NAME`: area of impact, such as “12 Clock Point” or “Non-Harmful Event”

## `vsoe.csv`

This is a simplified vehicle sequence-of-events file containing a subset of the
information in `vevent.csv`. It contains **125,797 rows: one row per event per
vehicle**, with the same number of event records as `vevent.csv` in 2024.

Example variables include:

- `VEVENTNUM`: vehicle event sequence number, such as `1` or `2`
- `SOENAME`: event description, such as “Motor Vehicle In-Transport” or “Ran Off Roadway - Right”
- `AOINAME`: area of impact, such as “12 Clock Point” or “Non-Harmful Event”

## `crashrf.csv`

This file records unusual crash-level conditions and special circumstances.
Because several conditions can be selected, a crash may have several rows; a
“None Noted” row records crashes without a listed factor. It contains **51,817
rows: one row per selected crash-related factor**.

Example variables include:

- `CRASHRFNAME`: crash-related factor, such as “Non-occupant struck vehicle” or “Emergency Vehicle Related”
- `CASENUM`: crash identifier, such as `202405684003` or `202405769745`
- `WEIGHT`: CRSS sampling weight, such as `130.5519` or `129.8638`

## `weather.csv`

This file allows more than one atmospheric condition to be recorded for a
crash, unlike a single primary-weather field. It contains **52,032 rows: one
row per reported weather condition per crash**, with at least one row for every
crash.

Example variables include:

- `WEATHERNAME`: weather condition, such as “Clear” or “Cloudy”
- `CASENUM`: crash identifier, such as `202405940278` or `202406428902`
- `URBANICITYNAME`: area classification, either “Urban Area” or “Rural Area”

## `vehiclesf.csv`

This file records special circumstances associated with an in-transport
vehicle. Several factors may apply, while “None Noted” represents no listed
special circumstance. It contains **90,641 rows: one row per selected vehicle
factor**, with at least one row for each in-transport vehicle.

Example variables include:

- `VEHICLESFNAME`: special factor, such as “Adaptive Equipment” or “Reconstructed/Altered Vehicle”
- `VEH_NO`: vehicle number within the crash, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405818059` or `202406487192`

## `pvehiclesf.csv`

This file provides the corresponding special-factor responses for parked and
working vehicles described by `parkwork.csv`. It contains **2,554 rows: one row
per selected factor for a parked or working vehicle**, with at least one row for
each such vehicle.

Example variables include:

- `PVEHICLESFNAME`: special factor, such as “Other Working Vehicle (Not Construction, Maintenance, Utility, Police, Fire, or EMS Vehicle)” or “Police, Fire, or EMS Vehicle Working at the Scene of an Emergency or Performing Other Traffic Control Activities”
- `VEH_NO`: parked/working vehicle number, such as `2` or `3`
- `CASENUM`: crash identifier, such as `202406415260` or `202406027927`

## `driverrf.csv`

This file records listed driver conditions, unusual situations, and special
circumstances. A driver can have several recorded factors. It contains **92,041
rows: one row per selected driver-related factor**, with at least one row for
each driver, including “None Noted” where applicable.

Example variables include:

- `DRIVERRFNAME`: driver-related factor, such as “Careless Driving, Inattentive Operation, Improper Driving, Driving Without Due Care” or “Operating the Vehicle in an Erratic, Reckless or Negligent Manner.”
- `VEH_NO`: vehicle operated by the driver, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405818059` or `202405980871`

## `damage.csv`

This file identifies all areas of a vehicle reported as damaged, generally by
clock position. A single vehicle can have damage in several areas. It contains
**191,085 rows: one row per damaged area per vehicle**.

Example variables include:

- `DAMAGENAME`: damaged area, such as “12 Clock Value” or “6 Clock Value”
- `VEH_NO`: vehicle number within the crash, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202406137353` or `202405657396`

## `distract.csv`

This file describes driver distraction or inattention. More than one
distraction can be recorded for a driver, and explicit “Not Distracted,”
unknown, and not-reported responses are retained. It contains **90,696 rows:
one row per reported distraction response per driver**.

Example variables include:

- `DRDISTRACTNAME`: distraction category, such as “Distraction/Inattention” or “Distracted by Outside Person, Object or Event”
- `VEH_NO`: vehicle operated by the driver, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405818059` or `202406487192`

## `drimpair.csv`

This file describes physical or mental conditions affecting the driver, such
as fatigue, illness, blackout, or impairment by alcohol, drugs, or medication.
It contains **90,761 rows: one row per reported impairment response per
driver**, allowing multiple responses.

Example variables include:

- `DRIMPAIRNAME`: impairment category, such as “Asleep or Fatigued” or “Under the Influence of Alcohol, Drugs or Medication”
- `VEH_NO`: vehicle operated by the driver, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405818059` or `202406487192`

## `factor.csv`

This file records vehicle circumstances that may have contributed to the
crash, such as tyre, brake, steering, power-train, or body problems. It contains
**90,708 rows: one row per selected contributing vehicle circumstance**, with
at least one response for each in-transport vehicle.

Example variables include:

- `VEHICLECCNAME`: contributing vehicle circumstance, such as “Tires” or “Brake System”
- `VEH_NO`: vehicle number within the crash, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405818059` or `202406487192`

## `maneuver.csv`

This file records what the driver attempted to avoid immediately before the
crash, such as another vehicle, a non-motorist, an animal, an object, or poor
road conditions. It contains **90,643 rows: one row per selected avoidance
manoeuvre response per vehicle**.

Example variables include:

- `MANEUVERNAME`: avoidance response, such as “Driver Did Not Maneuver to Avoid” or “Contact Motor Vehicle (In this crash)”
- `VEH_NO`: vehicle number within the crash, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405818059` or `202406487192`

## `violatn.csv`

This file lists citations issued to drivers in connection with the current
crash, including failure to yield, unsafe lane changes, speeding, licence
offences, and impaired driving. It does not contain the driver's earlier
violation history. A driver may receive several citations. It contains **97,551
rows: one row per citation response per driver**.

Example variables include:

- `VIOLATIONNAME`: citation issued for the current crash, such as “Fail to yield generally” or “Following too closely”
- `VEH_NO`: vehicle operated by the driver, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202406473825` or `202406514322`

## `vision.csv`

This file records circumstances that may have obscured the driver's view, such
as glare, weather, vegetation, vehicle geometry, or another vehicle. It contains
**90,668 rows: one row per reported vision obstruction per driver**, allowing
multiple responses.

Example variables include:

- `VISIONNAME`: vision obstruction, such as “Reflected Glare, Bright Sunlight, Headlights” or “Rain, Snow, Fog, Smoke, Sand, Dust”
- `VEH_NO`: vehicle operated by the driver, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405818059` or `202406487192`

## `personrf.csv`

This file records unusual situations and special circumstances associated with
individual people, including occupants and non-motorists. It contains **126,167
rows: one row per selected person-related factor**, with at least one response
for each person.

Example variables include:

- `PERSONRFNAME`: person-related factor, such as “Police or Law Enforcement Officer” or “Non-Operator Flees Scene”
- `PER_NO`: person number within the vehicle or crash, commonly `1` or `2`
- `VEH_NO`: associated vehicle number, commonly `1` or `2`

## `nmcrash.csv`

This file contains police-reported contributing circumstances or improper
actions by non-motorists, such as pedestrians and cyclists. It contains **7,469
rows: one row per selected contributing action per non-motorist**, allowing a
person to contribute several rows.

Example variables include:

- `NMCCNAME`: contributing circumstance, such as “Failure to Yield Right-Of-Way” or “Improper Crossing of Roadway or Intersection (Jaywalking)”
- `PER_NO`: non-motorist person number, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202406474784` or `202405830143`

## `nmdistract.csv`

This file records distractions affecting pedestrians, cyclists, and other
non-motorists. It contains **5,250 rows: one row per reported distraction per
non-motorist**, with at least one response for each applicable person.

Example variables include:

- `NMDISTRACTNAME`: distraction, such as “Distraction/Inattention” or “Distracted by Animal, Other Object, Event, or Activity”
- `PER_NO`: non-motorist person number, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405990316` or `202406066971`

## `nmimpair.csv`

This file records physical impairments affecting non-motorists, including
illness, fatigue, alcohol, drugs, or other impairments. It contains **5,256
rows: one row per reported impairment per non-motorist**, allowing multiple
responses.

Example variables include:

- `NMIMPAIRNAME`: impairment, such as “Under the Influence of Alcohol, Drugs or Medication” or “Paraplegic or in a Wheelchair”
- `PER_NO`: non-motorist person number, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202405990316` or `202406066971`

## `nmprior.csv`

This file describes what a non-motorist was doing immediately before becoming
involved in the crash. It contains **5,355 rows: one row per reported prior
action per non-motorist**, allowing multiple actions.

Example variables include:

- `NMACTIONNAME`: prior action, such as “Crossing Roadway” or “Movement Along Roadway with Traffic (In or Adjacent to Travel Lane)”
- `PER_NO`: non-motorist person number, commonly `1` or `2`
- `CASENUM`: crash identifier, such as `202406420789` or `202405811775`

## `safetyeq.csv`

This file describes safety equipment used by non-motorists, such as helmets,
protective pads, reflective clothing, and lights. Since 2017 the equipment
fields are stored together on a single record. The 2024 file contains **5,249
rows: one row per applicable non-motorist**.

Example variables include:

- `NMHELMETNAME`: helmet use, with levels such as “Yes” and “No”
- `NMREFCLONAME`: reflective clothing use, with levels such as “Yes” and “No”
- `NMLIGHTNAME`: lighting equipment use, with levels such as “Yes” and “No”

## `vpicdecode.csv`

This file contains vehicle characteristics decoded from the vehicle
identification number using NHTSA's Product Information Catalog and Vehicle
Listing system. It covers construction, dimensions, engine, restraint systems,
airbags, and active-safety equipment. It contains **77,959 rows: one row per
vehicle for which a vPIC decode record is supplied**. Not every vehicle in
`vehicle.csv` has a usable decoded VIN.

Example variables include:

- `BODYCLASS`: body class, such as “Sport Utility Vehicle (SUV)/Multi-Purpose Vehicle (MPV)” or “Sedan/Saloon”
- `CURBWEIGHTLB`: curb weight in pounds, with observed examples such as `3,485` or `3,455`
- `ELECTRONICSTABILITYCONTROL`: stability-control availability, for example “Standard” where decoded

## `vpictrailerdecode.csv`

This file contains characteristics decoded from trailer VINs, including body
type, connection type, weight rating, length, and axle configuration. It
contains **628 rows: one row per decoded trailer**, identified within its towing
vehicle by `TRAILER_NO`.

Example variables include:

- `TRAILERBODYTYPE`: body type, such as “Box or Van Enclosed Trailer” or “Flatbed or Platform Trailer”
- `TRAILERTYPECONNECTION`: connection type, such as “Straight Semi/Semi Trailer” or “Kingpin”
- `TRAILERLENGTHFT`: trailer length in feet, with observed examples such as `53` or `48`
