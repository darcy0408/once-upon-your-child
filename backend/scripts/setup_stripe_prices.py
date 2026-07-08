"""One-time Stripe setup for the single-tier launch pricing (2026-07-07).

Creates (idempotently) the Premium product and its two prices:

    premium_monthly  $9.99 / month
    premium_annual   $59.99 / year

Run it yourself from the repo root — it needs your Stripe secret key in the
environment and never prints it:

    # test mode first
    set STRIPE_SECRET_KEY=<your sk_test_... key>   (or $env:... in PowerShell)
    python backend/scripts/setup_stripe_prices.py

    # then live mode with your sk_live_... key

The script prints the resulting Price IDs. Set them on Railway
(story-weaver-app service) as:

    STRIPE_PRICE_ID_PREMIUM         -> the premium_monthly price id
    STRIPE_PRICE_ID_PREMIUM_ANNUAL  -> the premium_annual price id

Re-running is safe: prices are looked up by lookup_key and reused. Stripe
prices are immutable — to change an amount, this script deactivates the old
price and creates a replacement with the same lookup_key (existing
subscriptions keep their old price; only new checkouts see the new one).
"""

import os
import sys

import stripe

PRODUCT_NAME = "Once Upon YOUR Child — Premium"
PRODUCT_METADATA = {"app": "story-weaver", "tier": "premium"}

PRICES = [
    {
        "lookup_key": "premium_monthly",
        "unit_amount": 999,  # $9.99
        "interval": "month",
        "nickname": "Premium monthly",
    },
    {
        "lookup_key": "premium_annual",
        "unit_amount": 5999,  # $59.99 (~$5/mo, the headline offer)
        "interval": "year",
        "nickname": "Premium annual",
    },
]


def find_or_create_product() -> stripe.Product:
    for product in stripe.Product.list(active=True, limit=100).auto_paging_iter():
        meta = product.get("metadata") or {}
        if meta.get("app") == "story-weaver" and meta.get("tier") == "premium":
            return product
    return stripe.Product.create(name=PRODUCT_NAME, metadata=PRODUCT_METADATA)


def ensure_price(product_id: str, spec: dict) -> stripe.Price:
    existing = stripe.Price.list(
        lookup_keys=[spec["lookup_key"]], active=True, limit=1
    ).data
    if existing:
        price = existing[0]
        if (
            price["unit_amount"] == spec["unit_amount"]
            and price["recurring"]["interval"] == spec["interval"]
        ):
            return price
        # Amount changed: retire the old price and transfer its lookup_key.
        stripe.Price.modify(price["id"], active=False)
        print(f"  retired old {spec['lookup_key']} price {price['id']}")
    return stripe.Price.create(
        product=product_id,
        currency="usd",
        unit_amount=spec["unit_amount"],
        recurring={"interval": spec["interval"]},
        lookup_key=spec["lookup_key"],
        transfer_lookup_key=True,
        nickname=spec["nickname"],
    )


def main() -> int:
    key = os.environ.get("STRIPE_SECRET_KEY", "")
    if not key:
        print("STRIPE_SECRET_KEY is not set. Set it and re-run.", file=sys.stderr)
        return 1
    stripe.api_key = key
    mode = "TEST" if key.startswith("sk_test") else "LIVE"
    print(f"Running against Stripe {mode} mode.")

    product = find_or_create_product()
    print(f"Product: {product['id']}  ({product['name']})")

    env_var_by_key = {
        "premium_monthly": "STRIPE_PRICE_ID_PREMIUM",
        "premium_annual": "STRIPE_PRICE_ID_PREMIUM_ANNUAL",
    }
    print("\nSet these on Railway (story-weaver-app service):")
    for spec in PRICES:
        price = ensure_price(product["id"], spec)
        print(f"  {env_var_by_key[spec['lookup_key']]}={price['id']}")

    print(
        "\nAlso confirm in the Stripe Dashboard (one-time toggles):\n"
        "  - Settings > Billing > Subscriptions: Smart Retries ON\n"
        "  - Settings > Billing > Subscriptions: trial-ending reminder emails ON\n"
        "  - Leave STRIPE_PRICE_ID_FAMILY unset — the Family tier is hidden at launch."
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except stripe.StripeError as exc:  # stripe-python v15: no stripe.error module
        print(f"Stripe API error: {exc.user_message or exc}", file=sys.stderr)
        sys.exit(2)
