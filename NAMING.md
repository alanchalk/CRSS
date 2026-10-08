# Dataset naming

This repository follows the conventions used by the other packages in the
`datasetcreation` collection.

## R package data objects

For reusable source tables, use lower-case snake case with the components:

```text
dt_<source>_<observation-grain>
```

The CRSS objects are therefore:

- `dt_crss_person`: one row per in-scope person;
- `dt_crss_accident`: one row per sampled accident.

`dt_` identifies an R `data.table`, `crss` identifies the source, and the final
token states the row grain. The names deliberately do not encode a target:
both tables can support several supervised targets or unsupervised analysis.
For a genuinely target-specific derivative, the collection's longer pattern
remains `dt_<source>_<target-type>_<grain-or-qualifier>`.

## GLMStudio catalogue IDs

Use lower-case snake case with the components:

```text
<country>_<line>_<source>_<optional-target-or-qualifier>_<version>
```

The corresponding CRSS catalogue IDs are:

- `us_auto_crss_person_v1`;
- `us_auto_crss_accident_v1`.

Some manifests use a `ds_` prefix for the complete dataset identifier.

Country codes include `us` for the United States, `en` for England, and `zz`
for synthetic datasets. The line code is `auto` for motor insurance and `acft`
for aircraft.

The principal distinction between the CRSS IDs is observation grain—`person`
versus `accident`. Target definitions belong in catalogue metadata rather than
in the IDs of these reusable tables.
