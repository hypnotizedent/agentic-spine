#!/usr/bin/env python3
"""Direct EML importer — reads .eml files and inserts into ArchivedEmails via psql."""
import email
import email.policy
import email.utils
import hashlib
import os
import sys
import glob
from datetime import datetime

EML_DIR = os.environ.get("EML_DIR", "/app/uploads/eml")
ACCOUNT_ID = int(os.environ.get("MAIL_ACCOUNT_ID", "3"))


def parse_eml(path):
    with open(path, "rb") as f:
        msg = email.message_from_binary_file(f, policy=email.policy.default)

    message_id = msg.get("Message-ID", "") or ""
    subject = msg.get("Subject", "") or ""
    from_addr = msg.get("From", "") or ""
    to_addr = msg.get("To", "") or ""
    cc_addr = msg.get("Cc", "") or ""
    bcc_addr = msg.get("Bcc", "") or ""

    date_str = msg.get("Date", "")
    sent_date = None
    if date_str:
        try:
            sent_date = email.utils.parsedate_to_datetime(date_str)
            sent_date = sent_date.strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            pass
    received_date = sent_date

    body_text = ""
    body_html = ""
    has_attachments = False

    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            cd = str(part.get("Content-Disposition", ""))
            if "attachment" in cd:
                has_attachments = True
                continue
            try:
                payload = part.get_content()
            except Exception:
                payload = ""
            if ct == "text/plain" and not body_text:
                body_text = str(payload) if payload else ""
            elif ct == "text/html" and not body_html:
                body_html = str(payload) if payload else ""
    else:
        ct = msg.get_content_type()
        try:
            payload = msg.get_content()
        except Exception:
            payload = ""
        if ct == "text/html":
            body_html = str(payload) if payload else ""
        else:
            body_text = str(payload) if payload else ""

    folder = msg.get("X-Folder", "") or msg.get("X-Gmail-Labels", "") or ""

    is_outgoing = False
    if from_addr and "ronny@mintprints.com" in from_addr.lower():
        is_outgoing = True

    content = "{}{}{}{}".format(message_id, subject, from_addr, sent_date or "")
    content_hash = hashlib.sha256(content.encode()).hexdigest()[:64]

    return {
        "message_id": message_id.strip("<>")[:500] if message_id else "",
        "subject": subject[:500] if subject else "",
        "body": body_text[:50000] if body_text else "",
        "html_body": body_html[:200000] if body_html else "",
        "from_addr": from_addr[:500] if from_addr else "",
        "to_addr": to_addr[:2000] if to_addr else "",
        "cc_addr": cc_addr[:2000] if cc_addr else "",
        "bcc_addr": bcc_addr[:2000] if bcc_addr else "",
        "sent_date": sent_date,
        "received_date": received_date,
        "is_outgoing": is_outgoing,
        "has_attachments": has_attachments,
        "folder": folder[:200] if folder else "",
        "content_hash": content_hash,
    }


def sql_escape(s):
    if s is None:
        return "NULL"
    return "'" + str(s).replace("'", "''") + "'"


def main():
    eml_files = sorted(glob.glob(os.path.join(EML_DIR, "*.eml")))
    if not eml_files:
        print("No .eml files in {}".format(EML_DIR), file=sys.stderr)
        return 1

    total = len(eml_files)
    print("Found {} .eml files, account_id={}".format(total, ACCOUNT_ID), file=sys.stderr)
    imported = 0
    failed = 0

    for i, path in enumerate(eml_files):
        try:
            rec = parse_eml(path)

            cols = '"MailAccountId","MessageId","Subject","Body","HtmlBody","From","To","Cc","Bcc","SentDate","ReceivedDate","IsOutgoing","HasAttachments","FolderName","ContentHash","HashCreatedAt","IsLocked"'
            vals = "{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},NOW(),false".format(
                ACCOUNT_ID,
                sql_escape(rec["message_id"]),
                sql_escape(rec["subject"]),
                sql_escape(rec["body"]),
                sql_escape(rec["html_body"]),
                sql_escape(rec["from_addr"]),
                sql_escape(rec["to_addr"]),
                sql_escape(rec["cc_addr"]),
                sql_escape(rec["bcc_addr"]),
                sql_escape(rec["sent_date"]),
                sql_escape(rec["received_date"]),
                str(rec["is_outgoing"]).lower(),
                str(rec["has_attachments"]).lower(),
                sql_escape(rec["folder"]),
                sql_escape(rec["content_hash"]),
            )

            sql = 'INSERT INTO mail_archiver."ArchivedEmails" ({}) VALUES ({}) ON CONFLICT DO NOTHING;'.format(cols, vals)
            print(sql)
            imported += 1

        except Exception as e:
            print("FAIL: {}: {}".format(os.path.basename(path), e), file=sys.stderr)
            failed += 1

        if (i + 1) % 100 == 0:
            print("  processed {}/{}".format(i + 1, total), file=sys.stderr)

    print("done: imported={} failed={} total={}".format(imported, failed, total), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
