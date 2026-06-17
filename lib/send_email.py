#!/usr/bin/env python3
"""Send a digest email: rendered-HTML body + plain-text fallback + PDF attachment.

Uses only the Python standard library (no pip installs). Configuration is read from
environment variables (typically exported from the project's .env by run.sh):

    SMTP_SERVER, SMTP_PORT, SENDER_EMAIL, SENDER_PASSWORD, RECIPIENT_EMAIL

Usage:
    python3 send_email.py --subject "..." --html body.html --text body.md --attach report.pdf

--attach is optional; everything else is required.
"""
import argparse
import os
import smtplib
import ssl
import sys
from email.message import EmailMessage
from pathlib import Path


def _require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"[send_email] Missing required environment variable: {name}")
    return value


def _read(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        sys.exit(f"[send_email] Could not read {path}: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Send digest email via SMTP (STARTTLS).")
    parser.add_argument("--subject", required=True)
    parser.add_argument("--html", required=True, help="Path to the rendered HTML body.")
    parser.add_argument("--text", required=True, help="Path to the plain-text body (markdown).")
    parser.add_argument("--attach", help="Optional path to a PDF to attach.")
    args = parser.parse_args()

    smtp_server = _require_env("SMTP_SERVER")
    smtp_port = int(_require_env("SMTP_PORT"))
    sender = _require_env("SENDER_EMAIL")
    password = _require_env("SENDER_PASSWORD")
    recipient = _require_env("RECIPIENT_EMAIL")

    msg = EmailMessage()
    msg["Subject"] = args.subject
    msg["From"] = sender
    msg["To"] = recipient

    # Plain-text first, then HTML alternative.
    msg.set_content(_read(args.text))
    msg.add_alternative(_read(args.html), subtype="html")

    if args.attach:
        pdf_path = Path(args.attach)
        try:
            data = pdf_path.read_bytes()
        except OSError as exc:
            sys.exit(f"[send_email] Could not read attachment {pdf_path}: {exc}")
        msg.add_attachment(
            data,
            maintype="application",
            subtype="pdf",
            filename=pdf_path.name,
        )

    context = ssl.create_default_context()
    try:
        with smtplib.SMTP(smtp_server, smtp_port, timeout=60) as server:
            server.ehlo()
            server.starttls(context=context)
            server.ehlo()
            server.login(sender, password)
            server.send_message(msg)
    except smtplib.SMTPAuthenticationError:
        sys.exit(
            "[send_email] Authentication failed. For Gmail, SENDER_PASSWORD must be a "
            "16-character App Password (not your normal account password)."
        )
    except (smtplib.SMTPException, OSError) as exc:
        sys.exit(f"[send_email] Failed to send: {exc}")

    print(f"[send_email] Sent '{args.subject}' to {recipient}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
