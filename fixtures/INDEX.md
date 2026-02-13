# Fixture Index

Complete inventory of fixture assets in this directory.

## events/v1/ -- Inbound fixture event prompts

| File | Event Type | Description |
|------|-----------|-------------|
| `S20260201-180000__email_received__R0001.md` | email_received | Route inbound vendor invoice email |
| `S20260201-180100__order_paid__R0002.md` | order_paid | Process payment confirmation event |
| `S20260201-180200__vendor_receipt__R0003.md` | vendor_receipt | Catalog vendor receipt for records |
| `S20260201-180300__file_uploaded__R0004.md` | file_uploaded | Classify and route uploaded file |
| `S20260201-180400__unknown_event__R0005.md` | unknown_event | Handle unrecognized event gracefully |
| `S20260201-180500__spine_verify__R0006.md` | spine_verify | Run spine health verification |
| `S20260201-180600__status_check__R0007.md` | status_check | Report unified ops status summary |
| `S20260201-180700__gap_filed__R0008.md` | gap_filed | Process new gap registration event |
| `SCHEMA.md` | -- | Header field schema definition |

## baseline/ -- SHA256 hashes of normalized expected outputs

| File | Paired Event |
|------|-------------|
| `S20260201-180000__email_received__R0001.hash` | R0001 |
| `S20260201-180100__order_paid__R0002.hash` | R0002 |
| `S20260201-180200__vendor_receipt__R0003.hash` | R0003 |
| `S20260201-180300__file_uploaded__R0004.hash` | R0004 |
| `S20260201-180400__unknown_event__R0005.hash` | R0005 |
| `README.md` | -- | Baseline structure documentation |

## n8n/ -- Workflow templates

| File | Description |
|------|-------------|
| `Spine_-_Mailroom_Enqueue.json` | n8n workflow template for enqueuing fixture events |
| `README.md` | Directory documentation |
