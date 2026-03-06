# Receipt — CP-20260302-033506 bridge-calendar packet retirement

- Added canonical manifest for malformed bridge-calendar packet.
- Marked packet as `superseded` with terminal disposition.
- Packet was not carried forward because:
  - referenced loop scope was never normalized into the canonical loop ledger
  - referenced gap linkage drifted
  - no active gap or pending loop remains for this work
