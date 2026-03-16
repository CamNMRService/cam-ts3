#!/usr/bin/env python3
"""
NMR Zip File Processor

Continuously scans a mounted remote directory for new zip files,
extracts them, parses metadata from 'orig' files within numbered
subdirectories, renames and re-zips the content, then emails the
result to the user identified by CRSID.

Errors are emailed to nmr@ch.cam.ac.uk.
Local zips older than one month are automatically cleaned up.
"""

import os
import sys
import time
import json
import shutil
import zipfile
import smtplib
import logging
import signal
import traceback
import fcntl
from pathlib import Path
from datetime import datetime, timedelta
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email import encoders
from logging.handlers import RotatingFileHandler

# ================================================================
# CONFIGURATION — Edit these to match your environment
# ================================================================
REMOTE_DIR          = "/data/recent-nmr/glenlivet2"          # Mounted remote dir to watch
LOCAL_OUTPUT_DIR    = "/home/djh35/zip_email_processing"           # Local working directory
LOCAL_ZIP_DIR       = "/home/djh35/zip_email_processing/zipped"    # Renamed zips stored here
PROCESSED_DB_FILE   = "/home/djh35/zip_email_processing/.processed_files.json"
#LOG_FILE            = "/var/log/nmr_processor/nmr_processor.log"
LOG_FILE            = "/home/djh35/zip_email_processing/log/nmr_processor.log"
#LOCK_FILE           = "/var/run/nmr_processor.lock"
LOCK_FILE           = "/home/djh35/zip_email_processing/lock/nmr_processor.lock"

SCAN_INTERVAL_SECS  = 60
FILE_SETTLE_SECS    = 5
CLEANUP_AGE_DAYS    = 30

SMTP_SERVER         = "localhost"
SMTP_PORT           = 25
SMTP_USE_TLS        = False
SMTP_USERNAME       = None
SMTP_PASSWORD       = None
EMAIL_FROM          = "nmr@ch.cam.ac.uk"
ERROR_EMAIL_TO      = "nmr@ch.cam.ac.uk"
RECIPIENT_DOMAIN    = "@cam.ac.uk"

MAX_ATTACHMENT_MB   = 25
# ================================================================


# --------------- Global state ---------------
shutdown_requested = False
lock_fd = None


# --------------- Signal handling ---------------
def handle_signal(signum, frame):
    global shutdown_requested
    shutdown_requested = True


signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT,  handle_signal)


# --------------- Logging setup ---------------
def setup_logging():
    """Configure rotating file + console logging."""
    log_dir = os.path.dirname(LOG_FILE)
    os.makedirs(log_dir, exist_ok=True)

    logger = logging.getLogger("nmr_processor")
    logger.setLevel(logging.DEBUG)

    # Rotating file handler: 10 MB x 5 backups
    fh = RotatingFileHandler(LOG_FILE, maxBytes=10 * 1024 * 1024, backupCount=5)
    fh.setLevel(logging.DEBUG)

    # Console handler
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)

    fmt = logging.Formatter(
        "%(asctime)s  %(levelname)-8s  %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    fh.setFormatter(fmt)
    ch.setFormatter(fmt)

    logger.addHandler(fh)
    logger.addHandler(ch)
    return logger


logger = setup_logging()


# --------------- Lock file (prevent duplicate instances) --------
def acquire_lock():
    """Acquire an exclusive lock file; exit if another instance runs."""
    global lock_fd
    lock_dir = os.path.dirname(LOCK_FILE)
    try:
        os.makedirs(lock_dir, exist_ok=True)
    except PermissionError:
        logger.error("Cannot create lock directory %s — permission denied", lock_dir)
        sys.exit(1)

    try:
        lock_fd = open(LOCK_FILE, "w")
    except PermissionError:
        logger.error(
            "Cannot create lock file %s — permission denied. "
            "Try changing LOCK_FILE to a writable path.", LOCK_FILE
        )
        sys.exit(1)

    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_fd.write(str(os.getpid()))
        lock_fd.flush()
    except IOError:
        logger.error("Another instance is already running. Exiting.")
        sys.exit(1)


def release_lock():
    global lock_fd
    if lock_fd:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            lock_fd.close()
            os.remove(LOCK_FILE)
        except Exception:
            pass


# --------------- Processed-files database ----------------------
def load_processed_db() -> dict:
    """
    Load the database tracking processed files.
    Returns dict: { "filename.zip": { "timestamp": ..., "status": ... }, ... }
    """
    if os.path.isfile(PROCESSED_DB_FILE):
        try:
            with open(PROCESSED_DB_FILE, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as exc:
            logger.warning("Could not load processed DB (%s); starting fresh", exc)
    return {}


def save_processed_db(db: dict):
    os.makedirs(os.path.dirname(PROCESSED_DB_FILE), exist_ok=True)
    tmp = PROCESSED_DB_FILE + ".tmp"
    try:
        with open(tmp, "w") as f:
            json.dump(db, f, indent=2)
        os.replace(tmp, PROCESSED_DB_FILE)          # atomic on same FS
    except IOError as exc:
        logger.error("Could not save processed DB: %s", exc)


# --------------- Email helpers ---------------------------------
def send_email(to_addr, subject, body, attachment_path=None):
    """Send a plain-text email with an optional zip attachment."""
    msg = MIMEMultipart()
    msg["From"]    = EMAIL_FROM
    msg["To"]      = to_addr
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain"))

    if attachment_path and os.path.isfile(attachment_path):
        with open(attachment_path, "rb") as af:
            part = MIMEBase("application", "zip")
            part.set_payload(af.read())
        encoders.encode_base64(part)
        part.add_header(
            "Content-Disposition",
            f'attachment; filename="{os.path.basename(attachment_path)}"',
        )
        msg.attach(part)

    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=30) as srv:
            if SMTP_USE_TLS:
                srv.starttls()
            if SMTP_USERNAME and SMTP_PASSWORD:
                srv.login(SMTP_USERNAME, SMTP_PASSWORD)
            srv.sendmail(EMAIL_FROM, [to_addr], msg.as_string())
        logger.info("Email sent to %s — %s", to_addr, subject)
        return True
    except Exception as exc:
        logger.error("Failed to send email to %s: %s", to_addr, exc)
        return False


def send_error_notification(short_subject, detail):
    """Email an error report to the admin address."""
    body = (
        f"The NMR zip processor encountered an error.\n\n"
        f"Summary : {short_subject}\n"
        f"Time    : {datetime.now().isoformat()}\n"
        f"Host    : {os.uname().nodename}\n\n"
        f"Details:\n{detail}\n"
    )
    send_email(ERROR_EMAIL_TO, f"[NMR Processor] {short_subject}", body)


# --------------- Filename sanitisation -------------------------
def sanitize(name: str) -> str:
    """Keep only alphanumerics, hyphens, underscores, and dots."""
    return "".join(c if (c.isalnum() or c in "_-.") else "_" for c in name)


# --------------- Orig file parser ------------------------------
def parse_orig_file(path: str):
    """
    Parse an 'orig' metadata file.

    Expected format (3 non-blank lines, fields separated by whitespace):
        Group <value>
        CRSID <value>
        SampleName <value>

    Returns (group, crsid, samplename) on success, or None on failure.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            lines = [ln.strip() for ln in fh if ln.strip()]
    except Exception as exc:
        logger.warning("Cannot read %s: %s", path, exc)
        return None

    if len(lines) < 3:
        logger.warning("orig file %s has only %d non-blank line(s) (need 3)", path, len(lines))
        return None

    parsed = {}
    for line in lines[:3]:
        tokens = line.split(None, 1)
        if len(tokens) != 2:
            logger.warning("Unparseable line in %s: '%s'", path, line)
            return None
        parsed[tokens[0].strip().lower()] = tokens[1].strip()

    group      = parsed.get("group")
    crsid      = parsed.get("crsid")
    samplename = parsed.get("samplename")

    if not (group and crsid and samplename):
        logger.warning(
            "Missing field(s) in %s — group=%s, crsid=%s, samplename=%s",
            path, group, crsid, samplename,
        )
        return None

    logger.debug("Parsed %s -> group=%s  crsid=%s  samplename=%s", path, group, crsid, samplename)
    return group, crsid, samplename


# --------------- Zip helpers -----------------------------------
def safe_extract_zip(zip_path, dest_dir):
    """Extract a zip with path-traversal protection. Returns True on success."""
    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            real_dest = os.path.realpath(dest_dir)
            for member in zf.namelist():
                target = os.path.realpath(os.path.join(dest_dir, member))
                if not target.startswith(real_dest + os.sep) and target != real_dest:
                    raise zipfile.BadZipFile(f"Path traversal detected: {member}")
            zf.extractall(dest_dir)
        return True
    except zipfile.BadZipFile as exc:
        logger.error("Bad/corrupt zip %s: %s", zip_path, exc)
    except Exception as exc:
        logger.error("Extraction failed for %s: %s", zip_path, exc)
    return False


def create_zip_from_dir(source_dir, output_path, archive_top_name=None):
    """
    Recursively zip the *contents* of source_dir.
    The top-level folder inside the archive will be archive_top_name
    (defaults to the basename of source_dir).
    """
    try:
        top = archive_top_name or os.path.basename(source_dir)
        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for root, _dirs, files in os.walk(source_dir):
                for fname in files:
                    full = os.path.join(root, fname)
                    arcname = os.path.join(
                        top, os.path.relpath(full, source_dir)
                    )
                    zf.write(full, arcname)
        return True
    except Exception as exc:
        logger.error("Could not create zip %s: %s", output_path, exc)
        return False


# --------------- Core: find metadata in numbered subdirs -------
def find_metadata_in_extract(extract_root):
    """
    Walk the extraction tree looking for numbered subdirectories
    containing an 'orig' file.  Returns (group, crsid, samplename)
    from the first subdirectory whose orig parses successfully,
    or None if all fail.

    Handles the case where the zip wraps everything in a single
    top-level directory.
    """
    def _scan_dir(base):
        entries = []
        try:
            for name in os.listdir(base):
                full = os.path.join(base, name)
                if os.path.isdir(full):
                    try:
                        sort_key = int(name)
                    except ValueError:
                        sort_key = float("inf")
                    entries.append((sort_key, name, full))
        except OSError as exc:
            logger.warning("Cannot list %s: %s", base, exc)
            return None
        entries.sort()

        for _, dname, dpath in entries:
            orig = os.path.join(dpath, "orig")
            if os.path.isfile(orig):
                result = parse_orig_file(orig)
                if result:
                    return result
                logger.info("orig in %s/%s failed to parse; trying next subdir", base, dname)
        return None

    # First try scanning extract_root directly
    result = _scan_dir(extract_root)
    if result:
        return result

    # If the zip created a single wrapper directory, try one level deeper
    children = [
        os.path.join(extract_root, d)
        for d in os.listdir(extract_root)
        if os.path.isdir(os.path.join(extract_root, d))
    ]
    for child in children:
        result = _scan_dir(child)
        if result:
            return result

    logger.warning("No valid orig file found anywhere under %s", extract_root)
    return None


# --------------- Process a single zip --------------------------
def process_zip_file(zip_path, db):
    """
    Full pipeline for one zip:
      1. Copy locally & extract
      2. Parse metadata from 'orig'
      3. Re-zip with new top-level folder name
      4. Email to crsid@cam.ac.uk
    Returns True on success.
    """
    originalzipname       = os.path.basename(zip_path)
    originalzipname_noext = os.path.splitext(originalzipname)[0]

    tmp_area    = os.path.join(LOCAL_OUTPUT_DIR, "_tmp")
    local_copy  = os.path.join(tmp_area, originalzipname)
    extract_dir = os.path.join(tmp_area, f"extract_{originalzipname_noext}")

    try:
        # ---- Prepare temp area ----
        os.makedirs(tmp_area, exist_ok=True)
        for p in (local_copy, extract_dir):
            if os.path.isdir(p):
                shutil.rmtree(p)
            elif os.path.isfile(p):
                os.remove(p)
        os.makedirs(extract_dir)

        # ---- Copy from remote (handles slow / flaky mounts) ----
        logger.info("Copying %s to local temp area", originalzipname)
        shutil.copy2(zip_path, local_copy)

        # ---- Extract ----
        logger.info("Extracting %s", originalzipname)
        if not safe_extract_zip(local_copy, extract_dir):
            send_error_notification(
                f"Extraction failed: {originalzipname}",
                f"Could not extract {originalzipname}. The file may be corrupt.",
            )
            return False

        # ---- Parse metadata ----
        metadata = find_metadata_in_extract(extract_dir)
        if metadata is None:
            send_error_notification(
                f"No valid metadata: {originalzipname}",
                f"No parseable 'orig' file was found in any numbered "
                f"subdirectory of {originalzipname}.",
            )
            return False

        group, crsid, samplename = metadata
        logger.info(
            "Metadata for %s -> group=%s  crsid=%s  samplename=%s",
            originalzipname, group, crsid, samplename,
        )

        # ---- Build new name ----
        new_name = (
            f"{sanitize(group)}_{sanitize(crsid)}_"
            f"{sanitize(samplename)}_{sanitize(originalzipname_noext)}"
        )

        # ---- Find the real content root ----
        # If the zip had a single wrapper directory, skip past it
        contents = os.listdir(extract_dir)
        if len(contents) == 1 and os.path.isdir(os.path.join(extract_dir, contents[0])):
            content_root = os.path.join(extract_dir, contents[0])
            logger.info("Detected wrapper directory '%s' — skipping it", contents[0])
        else:
            content_root = extract_dir

        # ---- Re-zip with new top-level folder name ----
        os.makedirs(LOCAL_ZIP_DIR, exist_ok=True)
        output_zip = os.path.join(LOCAL_ZIP_DIR, f"{new_name}.zip")
        if not create_zip_from_dir(content_root, output_zip, archive_top_name=new_name):
            send_error_notification(
                f"Zip creation failed: {originalzipname}",
                f"Failed to create {output_zip}.",
            )
            return False

        zip_size_mb = os.path.getsize(output_zip) / (1024 * 1024)
        logger.info("Created %s (%.1f MB)", output_zip, zip_size_mb)

        # ---- Size warning ----
        if zip_size_mb > MAX_ATTACHMENT_MB:
            logger.warning("Zip is %.1f MB — may exceed mail-server limits", zip_size_mb)
            send_error_notification(
                f"Large attachment ({zip_size_mb:.0f} MB): {originalzipname}",
                f"The output zip {new_name}.zip is {zip_size_mb:.1f} MB.\n"
                f"Recipient: {crsid}{RECIPIENT_DOMAIN}\n"
                f"Local copy: {output_zip}",
            )

        # ---- Email to user ----
        recipient = f"{sanitize(crsid)}{RECIPIENT_DOMAIN}"
        subject   = f"NMR Data: {samplename} ({group})"
        body = (
            f"Dear {crsid},\n\n"
            f"Please find your NMR data attached.\n\n"
            f"  Group       : {group}\n"
            f"  CRSID       : {crsid}\n"
            f"  Sample Name : {samplename}\n"
            f"  Original File: {originalzipname}\n\n"
            f"Regards,\n"
            f"NMR Facility Automated Zipfile to Email Processor\n"
        )

        if not send_email(recipient, subject, body, output_zip):
            send_error_notification(
                f"Email failed: {originalzipname}",
                f"Processed successfully but could not email "
                f"{new_name}.zip to {recipient}.\n"
                f"Local copy retained at {output_zip}.",
            )
            # Still count as 'processed' — admin notified, local copy exists
            return True

        logger.info("SUCCESS — %s -> %s.zip -> %s", originalzipname, new_name, recipient)
        return True

    except Exception as exc:
        logger.error("Unexpected error processing zip email %s: %s", originalzipname, exc)
        logger.debug(traceback.format_exc())
        send_error_notification(
            f"Unexpected error: {originalzipname}",
            traceback.format_exc(),
        )
        return False

    finally:
        # Clean up temp files (keep the output zip in LOCAL_ZIP_DIR)
        for path in (local_copy, extract_dir):
            if path and os.path.exists(path):
                try:
                    if os.path.isdir(path):
                        shutil.rmtree(path)
                    else:
                        os.remove(path)
                except Exception:
                    pass


# --------------- Cleanup old local zips ------------------------
def cleanup_old_zips():
    cutoff = datetime.now() - timedelta(days=CLEANUP_AGE_DAYS)
    try:
        for zp in Path(LOCAL_ZIP_DIR).glob("*.zip"):
            mtime = datetime.fromtimestamp(zp.stat().st_mtime)
            if mtime < cutoff:
                zp.unlink()
                logger.info("Deleted old zip: %s (modified %s)", zp.name, mtime.date())
    except Exception as exc:
        logger.error("Cleanup error: %s", exc)


# --------------- Remote-mount health check ---------------------
def remote_is_accessible():
    try:
        if not os.path.isdir(REMOTE_DIR):
            return False
        os.listdir(REMOTE_DIR)
        return True
    except OSError:
        return False


# --------------- File-stability check --------------------------
def file_is_stable(path):
    """Return True if the file size does not change over FILE_SETTLE_SECS."""
    try:
        s1 = os.path.getsize(path)
        time.sleep(FILE_SETTLE_SECS)
        s2 = os.path.getsize(path)
        return s1 == s2
    except OSError:
        return False


# ===============================================================
#  MAIN LOOP
# ===============================================================
def main():
    acquire_lock()

    logger.info("=" * 65)
    logger.info("NMR Zip File Email Processor — starting up")
    logger.info("  Remote dir  : %s", REMOTE_DIR)
    logger.info("  Output dir  : %s", LOCAL_OUTPUT_DIR)
    logger.info("  Zip store   : %s", LOCAL_ZIP_DIR)
    logger.info("  Scan every  : %d s", SCAN_INTERVAL_SECS)
    logger.info("  Cleanup age : %d days", CLEANUP_AGE_DAYS)
    logger.info("=" * 65)

    # Ensure directories
    for d in (LOCAL_OUTPUT_DIR, LOCAL_ZIP_DIR):
        os.makedirs(d, exist_ok=True)

    db = load_processed_db()
    logger.info("Loaded processed-file DB with %d entries", len(db))

    mount_alert_sent = False
    last_cleanup     = datetime.min

    try:
        while not shutdown_requested:

            # ---- Check mount ----
            if not remote_is_accessible():
                if not mount_alert_sent:
                    logger.error("Remote directory %s is NOT accessible", REMOTE_DIR)
                    send_error_notification(
                        "Remote directory unavailable",
                        f"{REMOTE_DIR} cannot be listed. "
                        f"Check the network mount.",
                    )
                    mount_alert_sent = True
                _interruptible_sleep(SCAN_INTERVAL_SECS)
                continue

            if mount_alert_sent:
                logger.info("Remote directory is accessible again")
                mount_alert_sent = False

            # ---- Discover new zips ----
            try:
                all_zips = sorted(
                    f for f in os.listdir(REMOTE_DIR)
                    if f.lower().endswith(".zip")
                    and os.path.isfile(os.path.join(REMOTE_DIR, f))
                )
            except OSError as exc:
                logger.error("Cannot list %s: %s", REMOTE_DIR, exc)
                _interruptible_sleep(SCAN_INTERVAL_SECS)
                continue

            new_zips = [z for z in all_zips if z not in db]

            if new_zips:
                logger.info("Found %d new zip(s): %s", len(new_zips),
                            ", ".join(new_zips[:10]))

            for zipname in new_zips:
                if shutdown_requested:
                    break

                full_path = os.path.join(REMOTE_DIR, zipname)

                # Wait for file to finish writing
                if not file_is_stable(full_path):
                    logger.info("Skipping %s (still being written)", zipname)
                    continue

                success = process_zip_file(full_path, db)

                db[zipname] = {
                    "processed_at": datetime.now().isoformat(),
                    "status": "ok" if success else "failed",
                }
                save_processed_db(db)

            # ---- Periodic cleanup ----
            if datetime.now() - last_cleanup > timedelta(hours=24):
                logger.info("Running old-zip cleanup (> %d days)", CLEANUP_AGE_DAYS)
                cleanup_old_zips()
                last_cleanup = datetime.now()

            _interruptible_sleep(SCAN_INTERVAL_SECS)

    except Exception as exc:
        logger.critical("Fatal error in main loop: %s", exc)
        logger.critical(traceback.format_exc())
        send_error_notification("Fatal error — zip emailerstopped", traceback.format_exc())
        raise
    finally:
        release_lock()
        logger.info("NMR Zip File emailer — shut down cleanly")


def _interruptible_sleep(seconds):
    """Sleep in 1-second ticks so we respond promptly to signals."""
    for _ in range(int(seconds)):
        if shutdown_requested:
            return
        time.sleep(1)


# ---------------------------------------------------------------
if __name__ == "__main__":
    main()

"""

## systemd Service Unit — `nmr-zip-processor.service`

Place this in `/etc/systemd/system/`:

```ini
[Unit]
Description=NMR Zip File Processor
After=network-online.target remote-fs.target
Wants=network-online.target

[Service]
Type=simple
User=nmr
Group=nmr
ExecStart=/usr/bin/python3 /opt/nmr_processor/nmr_zip_processor.py
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/home/nmr/processing /var/log/nmr_processor /var/run
ReadOnlyPaths=/mnt/remote/nmr_data
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Enable and start with:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now nmr-zip-processor.service
sudo systemctl status nmr-zip-processor.service
# Live logs:
sudo journalctl -fu nmr-zip-processor.service
```

---

## Installation Checklist

```bash
# 1. Create the nmr user (if it doesn't exist)
sudo useradd -r -m -d /home/nmr -s /bin/bash nmr

# 2. Create required directories
sudo mkdir -p /opt/nmr_processor
sudo mkdir -p /home/nmr/processing/zipped
sudo mkdir -p /var/log/nmr_processor
sudo chown -R nmr:nmr /home/nmr/processing /var/log/nmr_processor

# 3. Deploy the script
sudo cp nmr_zip_processor.py /opt/nmr_processor/
sudo chmod 755 /opt/nmr_processor/nmr_zip_processor.py

# 4. Ensure a local MTA is running (for email)
sudo systemctl status postfix   # or exim4

# 5. Deploy and start the service
sudo cp nmr-zip-processor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nmr-zip-processor.service
```

---

## How It Works — Processing Pipeline

```
┌──────────────────────────────────────────────────────────┐
│                    SCAN CYCLE (every 60s)                 │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  /mnt/remote/nmr_data/                                   │
│    ├── experiment42.zip   ← NEW                          │
│    └── old_run.zip        ← already in DB, skipped       │
│                                                          │
│  1. Stability check (size unchanged for 5s)              │
│  2. Copy to local /home/nmr/processing/_tmp/             │
│  3. Extract with path-traversal protection               │
│                                                          │
│     extract_experiment42/                                 │
│       ├── 1/                                             │
│       │   └── orig   ← parse this first                  │
│       ├── 2/                                             │
│       │   └── orig   ← fallback if 1/ fails              │
│       └── 3/                                             │
│           └── orig   ← fallback if 2/ fails              │
│                                                          │
│  4. Parse first valid orig:                              │
│       Group teachinglabpartii                            │
│       CRSID jb2563                                       │
│       SampleName O5_product                              │
│                                                          │
│  5. Rename directory →                                   │
│       teachinglabpartii_jb2563_O5_product_experiment42   │
│                                                          │
│  6. Re-zip → /home/nmr/processing/zipped/                │
│       teachinglabpartii_jb2563_O5_product_experiment42.zip│
│                                                          │
│  7. Email zip to jb2563@cam.ac.uk                        │
│  8. Record in .processed_files.json                      │
│  9. Clean up temp files                                  │
│                                                          │
│  Daily: delete local zips older than 30 days             │
└──────────────────────────────────────────────────────────┘
```

---

## Error Conditions Handled

| Condition | Handling |
|---|---|
| **Remote mount unavailable** | Logs error, emails admin **once** (not every cycle), retries each cycle, logs recovery |
| **Duplicate instance** | `fcntl` lock file prevents a second copy from running |
| **Zip still being written** | File-size stability check (two reads separated by 5 s) |
| **Corrupt / bad zip** | Caught by `zipfile`, logged, admin emailed, file marked as processed |
| **Zip path-traversal attack** | Every member path validated before extraction |
| **No `orig` file found** | Tries all numbered subdirectories (sorted numerically); falls through one-level-deep wrapper dirs; admin emailed if all fail |
| **`orig` file malformed** | Skips to next numbered subdirectory; admin emailed only if *all* fail |
| **Attachment too large** | Warning logged + admin emailed; delivery still attempted |
| **SMTP failure** | Logged, admin emailed (separate attempt), local zip retained |
| **SIGTERM / SIGINT** | Graceful shutdown — finishes current file, releases lock |
| **Unexpected exception in main loop** | Caught at top level, full traceback emailed to admin, service restarts via systemd |
| **Disk full / permission errors** | Caught by general exception handlers, admin notified |

> **Note:** Edit the `CONFIGURATION` block at the top of the script to match your actual paths, SMTP server, and preferences before deploying. If your mail server requires TLS or authentication (e.g., Office 365 relay), set `SMTP_USE_TLS = True` and provide credentials.
"""
