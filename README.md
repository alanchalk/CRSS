# CRSS 2024 occupant injury case-study data

This repository builds a person-level dataset from the US National Highway
Traffic Safety Administration's 2024 Crash Report Sampling System (CRSS).
The intended case study predicts whether a particular driver or passenger is
injured, conditional on that person being involved in a police-reported crash.
It is an injury-severity or claims-triage problem, not an insurance frequency
or pricing model: CRSS contains crashes, not insured exposure or claim costs.

Three possible Chapter 2 analyses are compared in
[`CASE_STUDY_OPTIONS.md`](CASE_STUDY_OPTIONS.md): occupant injury, injured
pedestrian involvement, and serious/fatal injury using journey-start
information.

## Source

The official 2024 download is declared explicitly in
`data-raw/00_download_crss_2024.R`:

- directory: <https://www.nhtsa.gov/file-downloads?p=nhtsa/downloads/CRSS/2024/>
- CSV archive: <https://static.nhtsa.gov/nhtsa/downloads/CRSS/2024/CRSS2024CSV.zip>

The download script validates the archive, extracts all 28 CSV files and
deletes the ZIP after successful extraction. Original downloads are ignored by
Git because they are reproducible and large.

## Observational unit and hierarchy

The final table has one row per occupant of a motor vehicle in transport:

```text
Crash: CASENUM
└── Vehicle: CASENUM + VEH_NO
    └── Occupant: CASENUM + VEH_NO + PER_NO
```

Drivers and passengers are included. Pedestrians, cyclists, people on personal
conveyances, and occupants of vehicles not in transport are outside this case
study because their injury mechanisms and available protection variables are
materially different.

The principal target, `injured`, is derived from NHTSA's imputed person injury
severity (`INJSEV_IMNAME`):

- `0`: No Apparent Injury (O)
- `1`: Possible, minor, serious, fatal, or severity-unknown injury

The original English injury-severity categories remain in
`injury_severity_observed` and `injury_severity_imputed`. A second target,
`serious_or_fatal_injury`, identifies suspected serious and fatal injuries.

## Build

```bash
Rscript data-raw/00_download_crss_2024.R
Rscript data-raw/01_build_inj_occupant.R
Rscript data-raw/02_build_sev_crash.R
```

The build uses `data.table`, validates source schemas and keys, aggregates
multi-response files before joining, and refuses to save a result with duplicate
person keys. It creates:

Exported analytical tables follow the target-before-grain convention documented
in [`NAMING.md`](NAMING.md).

- `data/dt_crss_inj_occupant.rda`: the package dataset;
- `inst/extdata/dt_crss_inj_occupant_schema.csv`: variable source, timing, and
  modelling role;
- `inst/extdata/dt_crss_inj_occupant_build.json`: row/column counts and build
  checks;
- `data/dt_crss_sev_crash.rda`: the physically restricted Option 3
  dataset, excluding collision consequences while retaining clearly labelled
  retrospective descriptions of pre-impact conditions and conduct;
- `inst/extdata/dt_crss_sev_crash_schema.csv`: provenance, modelling
  role, and information timing for every Option 3 column.

The 2024 build contains **120,475 occupants, 90,456 vehicles, 51,627 crashes,
and 485 columns**. It includes 90,440 drivers and 30,035 passengers. The binary
target has 87,065 no-apparent-injury records, 33,407 injured records, and three
records with no crash-caused outcome because the person died before the crash.

The journey-start build contains all **51,658 sampled crashes** and the single
serious/fatal-injury target. The repository does not publish a general crash
table containing alternative outcomes and mixed-timing fields. Its design is
documented in [`CASE_STUDY_OPTIONS.md`](CASE_STUDY_OPTIONS.md).

## Source-file decisions

All 28 files are retained in the raw download. The analytical build uses the
three core files plus relevant crash-, vehicle-, driver-, person-, event-, and
VIN-derived files. Multi-response files are widened to Boolean indicators.

Files describing parked/working vehicles or non-motorists are not joined to the
occupant table. `cevent.csv` and `vsoe.csv` are retained but not joined because
the richer vehicle-specific `vevent.csv` represents the same event sequence at
the grain needed for this case study. Trailer VIN data is retained but not used.
The full file-by-file decision and rationale are in
[`data-raw/FILE_INVENTORY.md`](data-raw/FILE_INVENTORY.md). Detailed modelling,
timing, leakage and survey-design decisions are in
[`data-raw/CASE_STUDY_DESIGN.md`](data-raw/CASE_STUDY_DESIGN.md).
For a prose description of every source file, its row grain, and example
variables, see [`data-raw/SOURCE_FILE_GUIDE.md`](data-raw/SOURCE_FILE_GUIDE.md).

## Modelling cautions

CRSS is a complex probability sample of police-reported crashes. `weight`,
`psu_var`, and `psu_stratum` are retained for design-aware summaries. Random
training/test splitting must be performed by `case_number`, not by person, so
occupants from one crash cannot appear in both sets. The supplied `fold` follows
that rule.

Features are labelled `context`, `crash_mechanism`, or `post_crash` in the
schema. A model presented as pre-impact injury risk must not use post-crash
features. A model presented as insurer triage after first notice of loss may use
them if they are known at the stated decision time.
