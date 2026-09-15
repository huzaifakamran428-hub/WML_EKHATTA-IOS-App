# Waqare Medina Computers and Laptop — Management System

## ✅ Update — bill fixes: laptop details on re-view, trimmed fields, sale edit/delete

Per owner report ("bills are not showing me the details of the laptop
after creating the bill... in customer section when I view the bill it
does not show the laptop details"):

1. **Root cause**: the laptop details box on a bill was only ever drawn
   when a `Laptop` object was passed in — and that only happened right
   after *creating* a sale (`NewSaleViewController` already had it in
   memory). Re-opening an older receipt from the Customer section always
   passed `laptop: nil`, so the box silently didn't render. Fixed in
   `CustomerSaleDetailsViewController`: it now fetches the laptop by the
   sale item's product id before building the bill, so either path into
   this screen behaves identically.
2. **Bill now only prints brand, model, generation, CPU, RAM and storage**
   for the laptop — condition, serial number and CPU core count are
   dropped from the printed bill (`PDFBuilder.buildBillPDF`). Still
   visible on the in-app Laptop Details screen, just not on the receipt.
3. **Sales can now be edited and deleted** (admin-only), same principle as
   the earlier shopkeeper laptops/payments change: `SaleViewSet` was
   previously `get/post` only ("financial records aren't edited in
   place") — that restriction is lifted. Editing quantity reconciles
   stock under lock (raising it checks against live inventory; lowering
   it gives units back); editing price/discount/payment recalculates the
   final total and payment status the same way a new sale does. Deleting
   a sale returns its unit(s) to inventory stock. Both write an audit log
   entry and both require re-confirming in a dialog before submitting.
   The laptop a sale was made against can't be changed via edit — record
   a new sale for that instead.
   - New iOS screen: `EditSaleViewController`, reached via "Edit Bill" /
     "Delete Bill" buttons on the Receipt screen (admin only).
   - Backend: new `SaleSerializer.update()`, `SaleViewSet.perform_destroy`.

**No new migrations this round** — this only changed serializer/view
logic and the printed bill layout, no model fields.

---

## ✅ Update — session inactivity timeout + centralized session-expiry handling

Per owner request ("middleware is missing... session should expire after
some time of no activity", "shows error messages if any issue arises
instead of crashing"):

1. **Backend**: JWT access/refresh tokens alone don't detect idleness — a
   client can silently keep refreshing forever without the user ever
   touching the app. Added `apps.core.authentication.InactivityAwareJWTAuthentication`
   (wraps `JWTAuthentication`) plus a new `User.last_activity` field
   (migration `accounts/0003_user_last_activity.py`) and a
   `SESSION_INACTIVITY_TIMEOUT_MINUTES` setting (default 30). Every
   authenticated request stamps `last_activity`; if too much time has
   passed since the last one, the request is rejected with a 401 forcing
   re-login, even with an otherwise-still-valid access token. (A plain
   Django `MIDDLEWARE` entry can't see `request.user` for JWT — DRF
   authenticates later in the request cycle — so this had to live at the
   authentication-class layer instead; see the file's docstring.)
2. **iOS**: `InactivityMonitor` + `ActivityTrackingWindow` track real
   touches app-wide and time spent backgrounded, signing the user out
   locally if idle past the timeout without waiting on a network call.
   Any involuntary session end (idle timeout, or the server rejecting an
   expired/invalid token) now posts `.sessionDidExpire`, which
   `SceneDelegate` uses to bounce the whole app back to Login with a
   clear "Signed Out" alert instead of leaving stale, now-unauthorized
   screens on display.
3. Cleaned up the shared error-alert helper into its own
   `Utilities/ErrorPresentation.swift` and taught it to skip showing a
   second, vaguer alert on top of the new session-expiry redirect.

**Migrations included** (`apps/accounts/migrations/0003_user_last_activity.py`)
— run `python manage.py migrate`.

---

## ✅ Update — app renamed, shopkeeper edit/delete, CEO/contact on bills

Per owner request:

1. **App renamed** to "Waqar E Madina EKhatta" -- `Info.plist`
   (`CFBundleName`/`CFBundleDisplayName`, so this is what shows under the
   home-screen icon) and the login screen's title/heading. The Xcode
   target name, bundle identifier, and the business/store name printed on
   bills (`StoreSettings.store_name`, still "Waqare Medina Computers and
   Laptop" by default) were deliberately left alone -- shout if you want
   those renamed too, they're a bigger/riskier change and a separate
   concern from the app's display name.
2. **Shopkeeper laptops and payments can now be edited and deleted**,
   not just added. `ShopkeeperLaptopItemViewSet` / `ShopkeeperPaymentViewSet`
   previously hard-restricted `http_method_names` to `get/post` only
   ("immutable once added" was the original design) -- that restriction
   is removed (admin-only, same as everywhere else: SHOPKEEPER-role
   logins still can't write). Editing a payment amount re-validates it
   against the shopkeeper's combined balance with the payment's *own old
   amount excluded first* (otherwise it'd double-count against itself).
   All edits/deletes write an audit log entry, same as creates.
3. **Shopkeeper accounts can now be deleted**, and deleting one cascades
   to every laptop and payment recorded under it instead of being
   blocked. This needed a model change: `ShopkeeperLaptopItem.shopkeeper`
   and `ShopkeeperPayment.shopkeeper` were `on_delete=PROTECT` (by
   design, to stop *accidental* loss of financial history) --changed to
   `CASCADE` since an explicit "delete this account" action should take
   everything under it with it. The legacy `CreditPlan.shopkeeper` link
   (unused by the current shopkeeper flow -- see
   `apps/shopkeepers/models.py`'s docstring) was changed from `PROTECT`
   to `SET_NULL` for the same reason: it must not silently block deleting
   a shopkeeper account.
4. **CEO name + contact number now print on every generated bill**
   (customer sale bill and the shopkeeper combined bill both -- they
   share `PDFBuilder.drawHeader`), right under the store phone. Added as
   two new, editable `StoreSettings` fields (`ceo_name`, default
   "Yasir"; `ceo_contact_number`, default "03288621265") rather than
   hardcoded, so they can be changed from the app's Store Profile screen
   later without a code change/redeploy.

**Migrations included** (`apps/core/migrations/0002_...py`,
`apps/shopkeepers/migrations/0003_...py`,
`apps/credit/migrations/0002_...py`) -- run `python manage.py migrate`
(locally and/or let Render's build command do it) to apply them. These
were hand-written in the same sandbox-with-no-internet conditions
described below, so please run `python manage.py makemigrations --check`
once on a machine with the real dependencies installed to confirm they
match Django's own output exactly before you rely on them in production.

Your Render backend / Neon database: none of this needs any Render or
Neon dashboard changes -- it's the same `DB_ENGINE`/`DB_HOST`/etc.
environment variables either way, Neon or Render's own Postgres. Just
make sure your build command runs `python manage.py migrate` (the
`render.yaml` blueprint's `buildCommand` already does) so these three new
migrations get applied on deploy.

---

## ✅ Update — fixed "missing or invalid CFBundleExecutable" on install

After the `.xcodeproj` fix below got the project building, installing to
the Simulator failed with:
`Bundle ... has missing or invalid CFBundleExecutable in its Info.plist`.

Cause: the custom `Info.plist` never declared `CFBundleExecutable`. Xcode
only auto-fills that key when it generates the Info.plist itself
(`GENERATE_INFOPLIST_FILE = YES`); since this project supplies its own
plist file, that key has to be present in it. Fixed by adding
`CFBundleExecutable = $(EXECUTABLE_NAME)` (plus `CFBundleInfoDictionaryVersion`
and `CFBundleDevelopmentRegion`, both standard companions to that key) to
`ios/WaqareMedinaApp/Resources/Info.plist`. No project-file changes were
needed for this one — just re-download this project and Build & Run again.

---

## ✅ Update — Xcode project file added (fixes "Build input file cannot be found: Info.plist")

That error happened because this project never had an actual `.xcodeproj`
file in it — the previous README told you to manually create a new Xcode
project yourself and drag these files in, which is what led to Xcode
looking for `Info.plist` at a stale/incorrect absolute path on your Mac.

That manual step is no longer necessary. A ready-to-open
**`ios/WaqareMedinaApp.xcodeproj`** is now included, with:
- Both targets already wired up: `WaqareMedinaApp` (the app) and
  `WaqareMedinaAppTests` (the unit tests, `TEST_HOST`-linked to the app so
  `@testable import WaqareMedinaApp` works).
- Every existing `.swift` file already added to the correct target's
  Sources build phase, grouped to mirror the folder structure
  (App, Models, Networking, Resources, Services, Storage, Utilities,
  ViewControllers, Views).
- `INFOPLIST_FILE` set to the **relative** path
  `WaqareMedinaApp/Resources/Info.plist` (relative to the `.xcodeproj`
  location) — no more hardcoded absolute path, so this will work on any
  machine/any folder location, including after you move or re-clone the
  project.
- A shared scheme (`WaqareMedinaApp`) so Xcode has a working
  build/run/test scheme the moment you open the project — no scheme
  setup needed.
- Deployment target iOS 16.0, Swift 5, automatic code signing (you still
  need to pick your own Team in Signing & Capabilities before
  Build & Run, since that's tied to your personal Apple Developer
  account and can't be preset here).

**To build:** just double-click `ios/WaqareMedinaApp.xcodeproj` to open it
in Xcode, pick your Team under Signing & Capabilities, select a
Simulator, and hit ⌘R. Section 2 below (the old "create a new project by
hand" instructions) is now unnecessary and left only for reference/context
on how the target is configured.

---

## ✅ Update — this round's fixes (verified against a live server, not just read)

This time the backend was actually installed, migrated, and run against a
live SQLite database with real HTTP requests (login, create laptop, create
customer, create a sale, add a credit payment, pull every report) — not
just compiled. That found and fixed two real bugs:

1. **Admin lockout.** `python manage.py createsuperuser` gave you Django's
   `is_superuser` flag but left the app's own `role` field at `READ_ONLY`,
   so your first admin account got 403'd on `/api/users/` and
   `/api/audit-logs/`. Fixed in `apps/accounts/models.py`: saving a
   superuser now always sets `role = ADMIN`.
2. **Sale totals were wrong for quantity > 1.** `apps/sales/serializers.py`
   applied the discount to a single unit's price and used that as the
   *whole sale's* total, so selling 2 units silently billed the customer
   for 1 and produced a deeply negative "profit" figure. Fixed so the
   total is `(unit price × quantity) − discount`, and confirmed correct
   with a live 2-unit sale (Rs. 188,000 total / Rs. 28,000 profit instead
   of the previous Rs. 93,000 / -Rs. 67,000).

All 30 business-rule unit tests still pass, `manage.py check` is clean,
and every endpoint (`laptops`, `customers`, `sales`, `credit-plans`,
`payments`, all 6 report endpoints, `audit-logs`) was hit live and
returned correct data.

On the iOS side (still can't be compiled here — see below), the New Sale
screen was creating a brand-new Customer record on every single sale
instead of reusing an existing one by phone number, which would have
fragmented a repeat customer's purchase history across duplicate
records. Fixed in `CustomerService.swift` (added `findOrCreate`) and
`NewSaleViewController.swift` (uses it instead of always calling
`create`).

**Known limitation, not fixed:** the New Sale screen still always submits
`quantity: 1` — there's no quantity stepper in that screen's UI yet, even
though the backend now correctly supports selling more than one unit in
a single sale. Add a quantity field to `NewSaleViewController` if you
need multi-unit sales from the app (the API already handles it correctly
either way).

---

Built from `Waqare_Medina_Computers_Laptop_SRS_Swift_MVC_v3_0.docx` (SRS v3.0).
Native iOS app in **Swift + UIKit + MVC**, backend in **Python Django REST
Framework**, database **PostgreSQL** (MySQL supported).

---

## ⚠️ Read this first — what was actually verified here, and what needs your machine

I built this in a Linux sandbox with **no internet access and no
Xcode/macOS**. That has two real consequences, stated plainly:

| Layer | What I verified in this sandbox | What still needs to happen on your machine |
|---|---|---|
| **Business logic** (`backend/apps/core/business_rules.py`) | ✅ **30/30 unit tests pass**, run live with plain Python — no Django needed. This is the pricing/discount, profit, inventory, installment-balance, clearance and receipt-numbering logic from SRS Section 11 & Section 20. | Nothing — this module is done and tested. |
| **Django backend** | ✅ Every `.py` file compiles (no syntax errors) — `python3 -m py_compile` was run over all 98 backend files. ✅ URL/app wiring cross-checked by hand (settings ↔ apps ↔ urls). ❌ Could **not** run `pip install django` (no network in this sandbox) and so could **not** run `manage.py test` / a live server here. | Run `pip install -r requirements.txt` and `python manage.py test` yourself (instructions below) — I expect this to work, but you should confirm it in an environment with internet access. |
| **iOS Swift app** | ✅ Every `.swift` file checked for balanced braces/parens and required imports (a lightweight structural check, since no Swift compiler exists on Linux). | ❌ **Cannot be compiled or run outside Xcode on macOS** — that's an Apple platform requirement, not a limitation I can work around. Open the project in Xcode (instructions below) to build, run in Simulator, and execute the XCTest suite. |

I'm telling you this so you know exactly what "no errors, all tests
passing" currently rests on, versus what you still need to confirm
yourself once you're on a Mac with internet access. Everything below is
written to make that next step as fast as possible.

---

## What's in this folder

```
WaqareMedinaProject/
├── backend/                  Django REST API (SRS Section 3.2, 9, 13, 21)
│   ├── apps/
│   │   ├── core/              StoreSettings, permissions, shared business_rules.py, error handling
│   │   ├── accounts/          Users, roles, login (email/password, Google, Apple), JWT
│   │   ├── inventory/         Laptop records, stock, inventory movements
│   │   ├── customers/         Customer records
│   │   ├── shopkeepers/       Shopkeeper records
│   │   ├── sales/             Sales, sale items, receipt numbering
│   │   ├── credit/            Installment/credit plans, payments
│   │   ├── notifications/     In-app + push notifications, daily reminder sweep
│   │   ├── reports/           Sales/profit/inventory/outstanding/payment reports
│   │   └── audit/             Audit log of every financial/security change
│   ├── config/                 settings.py, urls.py, wsgi.py, asgi.py
│   ├── tests/                  test_business_rules.py — 30 passing unit tests
│   ├── manage.py
│   ├── requirements.txt
│   └── .env.example
├── ios/
│   ├── WaqareMedinaApp/
│   │   ├── App/                 AppDelegate, SceneDelegate (programmatic UIKit, no storyboards)
│   │   ├── Models/               Codable models: User, Laptop, Sale, CreditPlan, Payment, Notification…
│   │   ├── Views/                 Reusable cells, dashboard cards, form fields, empty states
│   │   ├── ViewControllers/      All 23 screens from SRS Section 5 (+1 supporting form)
│   │   ├── Services/              One service per SRS module (Auth, Inventory, Sales, Payment, Reports…)
│   │   ├── Networking/            APIClient (URLSession + async/await), APIConfig, APIError
│   │   ├── Storage/                KeychainManager (secure token storage), AppState
│   │   ├── Utilities/              CurrencyFormatter (Rs.), DateFormatting, Validation, PDFBuilder, Logger
│   │   └── Resources/              Info.plist
│   └── Tests/
│       └── BusinessRulesPreviewTests.swift   XCTest mirroring the backend's business rules
└── README.md                      (this file)
```

---

## 1. Run the backend (Django REST API)

### Requirements
- Python 3.11+ (3.12 recommended)
- PostgreSQL 14+ (or MySQL 8+, or SQLite for quick local testing — already the default)
- pip

### Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Only if you're switching to DB_ENGINE=postgres in .env — needs
# PostgreSQL's pg_config on your PATH (e.g. `brew install postgresql`
# on macOS) to build:
# pip install -r requirements-postgres.txt

cp .env.example .env
# Edit .env: set DJANGO_SECRET_KEY to a long random string.
# Leave DB_ENGINE=sqlite for the fastest path to a running server, or
# set DB_ENGINE=postgres (or mysql) and fill in DB_NAME/DB_USER/DB_PASSWORD
# to match SRS Section 21 (PostgreSQL recommended for production).

python manage.py makemigrations accounts core inventory customers shopkeepers sales credit notifications reports audit
python manage.py migrate
python manage.py createsuperuser   # creates your first Admin user (SRS Section 2)
python manage.py runserver
```

The API is now live at `http://127.0.0.1:8000/api/` and the Django admin
at `http://127.0.0.1:8000/admin/`.

### Run the tests

```bash
# Pure business-logic tests (no Django/DB required, runs in <1 second):
python3 -m unittest discover -s tests -v

# Full Django test suite, once you've written model-level tests
# (business_rules.py is already 100% covered above; add
# apps/*/tests.py files as you build out integration tests):
python manage.py test
```

### Schedule the daily notification sweep (SRS 4.11)

Low-stock alerts and 2-day/due-today/overdue installment reminders are
computed by `apps/notifications/tasks.py`. Run it daily via cron or Celery
beat:

```bash
python manage.py run_notification_sweep
```

Example cron entry (daily at 8 AM):
```
0 8 * * * cd /path/to/backend && venv/bin/python manage.py run_notification_sweep
```

### Google / Apple Sign-In

`apps/accounts/auth_views.py` has working endpoint scaffolding for both:
- **Google**: install `google-auth` (`pip install google-auth`) and set
  `GOOGLE_OAUTH_CLIENT_ID` in `.env`. The verification call is already wired up.
- **Apple**: `AppleLoginView._verify_apple_token` currently raises
  `NotImplementedError` — plug in JWKS verification (e.g. with
  `python-jose` against Apple's public keys) using
  `APPLE_SIGNIN_CLIENT_ID` / `APPLE_SIGNIN_TEAM_ID` / `APPLE_SIGNIN_KEY_ID`
  from `.env` before shipping.

### Deployment (SRS Section 21)

- Set `DJANGO_DEBUG=False`, a real `DJANGO_SECRET_KEY`, and
  `DJANGO_ALLOWED_HOSTS` in production.
- Use PostgreSQL (`DB_ENGINE=postgres`) with regularly scheduled backups.
- Serve behind HTTPS (SRS 13) — e.g. gunicorn + nginx with a valid SSL cert,
  or a managed platform (Render, Railway, an EC2/DigitalOcean box + nginx).
- `requirements.txt` already includes `gunicorn` and `whitenoise` for that.

---

## 2. Run the iOS app (Swift + UIKit + MVC)

### Requirements
- **A Mac** running Xcode 15+ (Swift/iOS can only be built and run on macOS — this is an Apple tooling requirement, not something any environment can work around)
- iOS 16+ target recommended (SRS: "recommended current supported iOS baseline")
- Apple Developer account (for device deployment / App Store, per SRS 21)

### Setup

1. Open Xcode → **File → New → Project → iOS → App**.
   - Product Name: `WaqareMedinaApp`
   - Interface: **Storyboard** (we won't use it — delete `Main.storyboard`
     after creation, since this project is fully programmatic UIKit)
   - Language: **Swift**
   - Uncheck "Use Core Data" / "Include Tests" is fine either way (a test
     target is added manually below)
2. Delete the auto-generated `Main.storyboard`, `ViewController.swift`,
   and the default `Info.plist` Xcode created.
3. Drag the entire `ios/WaqareMedinaApp/` folder from this project into
   your new Xcode project (check **"Copy items if needed"** and
   **"Create groups"**).
4. Use the `Info.plist` provided in `WaqareMedinaApp/Resources/Info.plist`
   as your target's Info.plist (Project settings → target → Build
   Settings → search "Info.plist File" → point it at this file, or copy
   its contents into the one Xcode generated).
5. In your target's **Signing & Capabilities**:
   - Add **Push Notifications** capability (SRS 4.11 / APNs)
   - Add **Sign in with Apple** capability (SRS 4.1)
   - Set your Team / Bundle Identifier (`com.waqaremedina.app` or your own)
6. Add a **Unit Testing Bundle** target (File → New → Target → Unit
   Testing Bundle), name it `WaqareMedinaAppTests`, and drag
   `ios/Tests/BusinessRulesPreviewTests.swift` into it.
7. Point `APIConfig.baseURL` (in `Networking/APIConfig.swift`) at your
   running backend — `http://127.0.0.1:8000/api/` works against the local
   `manage.py runserver` from Part 1 when running in the iOS **Simulator**
   (not a physical device, which can't reach your Mac's `127.0.0.1` —
   use your Mac's LAN IP instead for device testing).
8. **Build & Run** (⌘R) — target the iOS Simulator first.
9. **Run tests** (⌘U) to execute `BusinessRulesPreviewTests`.

### Optional: Google Sign-In

`LoginViewController.handleGoogleLogin` is stubbed with a clear
placeholder. Add the
[GoogleSignIn-iOS SDK](https://github.com/google/GoogleSignIn-iOS) via
Swift Package Manager, configure your `GIDClientID` in Info.plist, obtain
an ID token from the SDK, and call
`AuthService.shared.loginWithGoogle(idToken:)` — that call is already
wired to the backend.

### App Store / device deployment

Standard Xcode flow: Signing & Capabilities → your Apple Developer Team →
Archive → distribute. Set `APIConfig.baseURL`'s release branch to your
deployed HTTPS backend URL first (SRS 13: all production traffic must use
HTTPS).

---

## 3. How the two sides map to the SRS

- Every Django app and Swift file has a doc-comment citing the SRS
  section(s) it implements (e.g. `SRS 4.9`, `SRS 20 acceptance criteria
  #53`) — search for `SRS` in either folder to trace any requirement to
  its code.
- The **30 passing unit tests** in `backend/tests/test_business_rules.py`
  map directly to SRS Section 20's acceptance criteria (discount/final
  price math, profit, low-stock threshold, inventory never going
  negative, remaining-balance-never-negative, payment-can't-exceed-
  remaining, CLEARED status transition, 2-day reminder logic, overdue
  detection, and receipt-number formatting/uniqueness/cap).
- `ios/Tests/BusinessRulesPreviewTests.swift` mirrors the same rules on
  the Swift side, since SRS 3.3 requires the Swift app to give instant UI
  feedback while Django remains the authoritative validator.

## 4. What's intentionally left as a "wire this up" stub

A few things are genuinely credential-/environment-specific and can't be
meaningfully filled in without your accounts and keys:
- Apple Sign-In JWKS verification (`apps/accounts/auth_views.py`)
- Google Sign-In client SDK on the iOS side
- Production database credentials, SSL certs, and hosting choice
- Store logo image, real phone number (SRS 24: "Actual store logo/phone
  number will be inserted before production")

Everything else in the SRS — all 23 screens, all REST modules, all
business rules, RBAC, receipt numbering, installment lifecycle, audit
logging, reports — is implemented.
# WML_EKHATTA-IOS-App
