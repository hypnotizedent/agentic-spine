# W72 Runtime Verify Stability Report

## Verify Stability Runs
| surface | run_key | result | notes |
|---|---|---|---|
| verify.pack.run workbench | `CAP-20260228-052351__verify.pack.run__Rjrus78938` | PASS | 27/27 pass |
| verify.pack.run media | `CAP-20260228-052446__verify.pack.run__R6cuz98724` | PASS | 17/17 pass |
| verify.pack.run communications | `CAP-20260228-052454__verify.pack.run__Rz6i71568` | PASS | 33/33 pass |
| verify.pack.run mint | `CAP-20260228-052514__verify.pack.run__Rk64w3604` | PASS | 40/40 pass |
| verify.run -- fast | `CAP-20260228-052534__verify.run__Rh2vf6805` | PASS | failure_class all zero |
| verify.run -- domain communications | `CAP-20260228-052536__verify.run__Rkz4k7299` | PASS | failure_class all zero |

## Transient Behavior
- Earlier mint pack transient fail observed in run `CAP-20260228-051147__verify.pack.run__Rktzz95416`.
- Immediate rerun `CAP-20260228-051230__verify.pack.run__Rwm4a5116` passed.
- Final stability block includes only passing runs listed above.
