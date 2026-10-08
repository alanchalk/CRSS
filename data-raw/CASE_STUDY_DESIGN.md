# Occupant injury case-study design

## Question and estimand

The case study estimates the probability that a particular driver or passenger
is injured, conditional on involvement in a police-reported crash represented by
CRSS. It does not estimate claim frequency, population injury incidence, policy
risk, or ultimate claim cost.

The unit of observation is a person. The hierarchy is people nested within
vehicles nested within crashes. The unique person key is
`CASENUM + VEH_NO + PER_NO` in the source and
`case_number + vehicle_number + person_number` in the output.

## Population

Included person types are:

- Driver of a Motor Vehicle In-Transport
- Passenger of a Motor Vehicle In-Transport

Non-motorists and occupants of vehicles not in transport are excluded because
their exposure, available protective equipment and injury mechanisms differ.

## Outcomes

`injured` uses the imputed NHTSA injury severity:

- 0: No Apparent Injury (O)
- 1: Possible Injury (C), Suspected Minor Injury (B), Suspected Serious Injury
  (A), Fatal Injury (K), or Injured, Severity Unknown

`serious_or_fatal_injury` equals one for suspected serious or fatal injury.
Records coded “Died Prior to Crash” do not represent an injury caused by the
crash and receive a missing outcome.

The observed and imputed English severity categories are both retained for
audit and sensitivity analysis. Models must use an explicitly chosen target.

## Source integration

Core tables are joined at their natural keys:

- accident: `CASENUM`
- vehicle: `CASENUM + VEH_NO`
- person: `CASENUM + VEH_NO + PER_NO`

Multi-response tables are converted to Boolean indicators at the relevant grain
before joining. Missing indicators after the join mean the response was not
present and are set to zero only after confirming that the source table covers
the relevant key population.

`vevent` is summarized per vehicle with the number of events, first and last
event, first impact area, and indicators for all recorded event types. It is
used instead of also joining `cevent` and `vsoe`, avoiding duplicated versions
of the same event history.

## English values and numerical quantities

Categorical fields retain their English labels rather than carrying both NHTSA
codes and labels. True measurements and counts remain numeric, including age,
vehicle model year, occupants, number of vehicles, speed limit and VIN-derived
dimensions. Identifiers and CRSS survey variables also remain numeric or text as
appropriate.

## Timing and leakage

The schema assigns every output column a timing class:

- `identifier`: relational key;
- `survey_design`: CRSS weight, PSU and stratum;
- `person`: occupant information;
- `context`: information existing before or at crash initiation;
- `crash_mechanism`: impact and event information generated during the crash;
- `post_crash`: damage, towing, deformation and similar aftermath information;
- `outcome`: injury target or auditable outcome category;
- `partition`: crash-grouped analysis fold.

The following fields are deliberately absent because they summarize or reveal
the person-level outcome:

- crash maximum injury severity and number injured;
- vehicle maximum injury severity and number injured;
- person hospitalisation as a predictor;
- any fatality or injury total derived from people in the same crash.

Damage and other post-impact evidence are retained, clearly labelled, for a
possible insurer first-notice-of-loss triage analysis. They must not enter a
model described as pre-impact injury risk.

## Dependence and validation

Occupants in one vehicle share an impact, and vehicles in one crash share the
collision. Ordinary person-level random splitting would leak crash information.
The supplied ten-fold partition assigns entire crashes to a fold.

A later generalized linear mixed model can represent the hierarchy with crash
and nested-vehicle random intercepts, for example:

```r
injured ~ age_years + seat_position + restraint_use + person_type +
  vehicle_model_year + rollover + manner_of_collision +
  (1 | case_number) + (1 | case_number:vehicle_number)
```

## Survey design

CRSS is a complex probability sample. The output retains `weight`, `psu_var`
and `psu_stratum`. Descriptive population estimates should use the survey
weight and design variables. Predictive modelling should report whether weights
were used and should not describe unweighted sample percentages as national
crash percentages.

## Limitations

- CRSS contains police-reported crashes, not insurance claims.
- It does not include policy exposure, premiums, coverage, reserves or costs.
- Some fields are police-reported or imputed and may be measured with error.
- Restraint use, distraction, alcohol and similar factors are observational;
  model associations are not automatically causal effects.
- The useful information set depends on the decision time. Every analysis must
  state whether it is pre-impact explanation or post-crash triage.
