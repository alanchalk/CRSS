# Dataset naming

This repository follows the conventions used by the other packages in the
`datasetcreation` collection.

## R package data objects

Use lower-case snake case with the components:

```text
dt_<source>_<target-type>_<grain-or-qualifier>
```

The target type precedes the observation grain. The CRSS objects are therefore:

- `dt_crss_inj_occupant`: binary occupant-injury target, one row per occupant;
- `dt_crss_sev_crash`: serious/fatal-injury severity target, one row per crash.

This matches names such as `dt_stats19_freq_lsoa`, where `freq` is the target
type and `lsoa` is the grain. `dt_` identifies an R `data.table`; `crss`
identifies the source.

## GLMStudio catalogue IDs

Use lower-case snake case with the components:

```text
<country>_<line>_<source>_<target-type>_<optional-qualifier>_<version>
```

The corresponding CRSS catalogue IDs are:

- `us_auto_crss_inj_occupant_v1`;
- `us_auto_crss_sev_crash_v1`.

Some manifests use a `ds_` prefix for the complete dataset identifier.

Country codes include `us` for the United States, `en` for England, and `zz`
for synthetic datasets. The line code is `auto` for motor insurance and `acft`
for aircraft.

## Meaning of `sev`

Existing catalogue entries use `sev` for claim severity. For CRSS,
`dt_crss_sev_crash` is an injury-severity classification target rather than a
claim-amount target. Any GLMStudio integration must declare the response family
and task in its manifest instead of inferring regression behaviour from the
`sev` token alone.
