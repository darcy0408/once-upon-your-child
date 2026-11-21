"""Mint a gift code by hand, with no purchase behind it.

For the owner giving Premium to family or friends. A normal gift code is
created by the Stripe webhook when someone buys one; this writes the same
kind of row straight into the database, so the code redeems in the app
exactly like a bought one ("Have a gift code?" on the subscription screen).

Run from the repo root, against production:

    railway run --service Postgres python backend/scripts/mint_gift_code.py --days 3650

The code is printed once and only its hash is stored, so copy it down.
Each code works for one account, once.
"""

import argparse
import os
import sys
import uuid
from datetime import datetime, timezone

import psycopg2

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

from backend.models.gift_code import (  # noqa: E402
    STATUS_CREATED,
    format_code,
    generate_code,
    hash_code,
)

OWNER_GIFT_MARKER = "owner-gift"


def _connect_args() -> dict | None:
    """Find an address for the database that works from outside Railway.

    The plain DATABASE_URL points at a private host name that only resolves
    inside Railway, so it is used only when it is not that private address
    or when this is running inside a Railway container.
    """
    env = os.environ
    public = env.get("DATABASE_PUBLIC_URL")
    if public:
        return {"dsn": public}
    proxy_host = env.get("RAILWAY_TCP_PROXY_DOMAIN")
    proxy_port = env.get("RAILWAY_TCP_PROXY_PORT")
    password = env.get("PGPASSWORD") or env.get("POSTGRES_PASSWORD")
    if proxy_host and proxy_port and password:
        return {
            "host": proxy_host,
            "port": proxy_port,
            "user": env.get("PGUSER") or env.get("POSTGRES_USER") or "postgres",
            "password": password,
            "dbname": env.get("PGDATABASE") or env.get("POSTGRES_DB") or "railway",
        }
    url = env.get("DATABASE_URL")
    if not url:
        return None
    if ".railway.internal" in url and not env.get("RAILWAY_REPLICA_ID"):
        # Private address, and this is not running inside Railway.
        return None
    return {"dsn": url}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, default=365, help="how long it lasts")
    parser.add_argument("--tier", choices=["premium", "family"], default="premium")
    parser.add_argument("--count", type=int, default=1, help="how many codes")
    args = parser.parse_args()
    if args.days < 1 or not 1 <= args.count <= 20:
        parser.error("--days must be at least 1 and --count between 1 and 20")

    connect_args = _connect_args()
    if connect_args is None:
        names = sorted(
            k for k in os.environ if k.startswith(("DATABASE", "PG", "RAILWAY_TCP"))
        )
        print("No database address reachable from this machine.")
        print("Variable names present (values not shown):", ", ".join(names) or "none")
        return 1

    codes = [generate_code() for _ in range(args.count)]
    conn = psycopg2.connect(**connect_args)
    try:
        with conn, conn.cursor() as cur:
            for code in codes:
                cur.execute(
                    "INSERT INTO gift_code (id, code_hash, tier, duration_days,"
                    " purchaser_email, status, created_at)"
                    " VALUES (%s, %s, %s, %s, %s, %s, %s)",
                    (
                        str(uuid.uuid4()),
                        hash_code(code),
                        args.tier,
                        args.days,
                        OWNER_GIFT_MARKER,
                        STATUS_CREATED,
                        datetime.now(timezone.utc).replace(tzinfo=None),
                    ),
                )
    finally:
        conn.close()

    print(f"{args.count} {args.tier} gift code(s), {args.days} days each:")
    for code in codes:
        print("  " + format_code(code))
    return 0


if __name__ == "__main__":
    sys.exit(main())
