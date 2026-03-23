# Salon V1 — Full Codebase Bug & Security Audit Report

> Generated: 2026-03-23  
> Scope: All backend controllers, models, routes, middleware, services, config, frontend pages/components, Docker/Nginx config  
> Total Issues Found: **70**

---

## Summary by Severity

| Severity | Count |
|----------|-------|
| 🔴 Critical | 8 |
| 🟠 High | 22 |
| 🟡 Medium | 26 |
| 🟢 Low | 14 |
| **Total** | **70** |

---

## Quick Index

1. [backend/.env](#backendenv)
2. [backend/config/validateEnv.js](#backendconfigvalidateenvjs)
3. [backend/routes/auth.js](#backendroutesauthjs)
4. [backend/controllers/authController.js](#backendcontrollersauthcontrollerjs)
5. [backend/routes/walkin.js](#backendrouteswalkinjs)
6. [backend/controllers/walkinController.js](#backendcontrollerswalkincontrollerjs)
7. [backend/controllers/appointmentController.js](#backendcontrollersappointmentcontrollerjs)
8. [backend/controllers/paymentController.js](#backendcontrollerspaymentcontrollerjs)
9. [backend/controllers/staffController.js](#backendcontrollersstaffcontrollerjs)
10. [backend/controllers/customerController.js](#backendcontrollerscustomercontrollerjs)
11. [backend/controllers/reportController.js](#backendcontrollersreportcontrollerjs)
12. [backend/controllers/attendanceController.js](#backendcontrollersattendancecontrollerjs)
13. [backend/controllers/packageController.js](#backendcontrollerspackagecontrollerjs)
14. [backend/controllers/expenseController.js](#backendcontrollersexpensecontrollerjs)
15. [backend/controllers/reviewController.js](#backendcontrollersreviewcontrollerjs)
16. [backend/controllers/notificationController.js](#backendcontrollersnotificationcontrollerjs)
17. [backend/controllers/userController.js](#backendcontrollersusercontrollerjs)
18. [backend/controllers/branchController.js](#backendcontrollersbranchcontrollerjs)
19. [backend/controllers/inventoryController.js](#backendcontrollersinventorycontrollerjs)
20. [backend/services/notificationService.js](#backendservicesnotificationservicejs)
21. [backend/services/recurringService.js](#backendservicesrecurringservicejs)
22. [backend/socket.js](#backendsocketjs)
23. [backend/routes/services.js](#backendroutesservicesjs)
24. [backend/models/Appointment.js](#backendmodelsappointmentjs)
25. [backend/models/Customer.js](#backendmodelscustomerjs)
26. [docker-compose.yml](#docker-composeyml)
27. [proxy/default.conf](#proxydefaultconf)
28. [frontend/nginx.conf](#frontendnginxconf)
29. [frontend/src/pages/LoginPage.jsx](#frontendsrcpagesloginpagejsx)
30. [frontend/src/pages/BookingPage.jsx](#frontendsrcpagesbookingpagejsx)
31. [frontend/src/pages/ReviewFormPage.jsx](#frontendsrcpagesreviewformpagejsx)
32. [frontend/src/pages/DashboardPage.jsx](#frontendsrcpagesdashboardpagejsx)
33. [frontend/src/pages/TokenDisplayScreen.jsx](#frontendsrcpagestokendisplayscreenjsx)
34. [Cross-Cutting / Architectural Issues](#cross-cutting--architectural-issues)

---

## `backend/.env`

| # | Type | Severity | Description |
|---|------|----------|-------------|
| 1 | Security | 🔴 **Critical** | Real database password committed to source control (`DB_PASS=kjsdksdjiereihshdks`). The `.env` file must be added to `.gitignore` and never committed to version control. |
| 2 | Security | 🔴 **Critical** | Weak default JWT secret committed to source: `JWT_SECRET=zanesalon_jwt_secret_key_change_in_production`. Anyone who clones the repo can forge valid JWT tokens. Must be replaced with a long random secret and kept out of source control. |

---

## `backend/config/validateEnv.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 3 | 8–13 | Missing Validation | 🟡 **Medium** | `DB_PASS` is not in the required list. A missing DB password causes a connection failure at runtime after 10 retries, rather than a fast startup error. |

---

## `backend/routes/auth.js`

| # | Line | Type | Severity | Description |
|---|------|------|----------|-------------|
| 4 | 7 | Security | 🔴 **Critical** | `POST /api/auth/register` has **no authentication guard**. Any unauthenticated HTTP client can create a user with any role, including `superadmin`. Complete privilege-escalation hole. |

---

## `backend/controllers/authController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 5 | 25 | Security | 🔴 **Critical** | `register()` does not validate or restrict the `role` field. `role: role \|\| 'staff'` allows the caller to set `role: 'superadmin'`, bypassing all access controls entirely. |
| 6 | 47–52, 101–105 | Security | 🟡 **Medium** | JWT token is returned in the JSON response body **in addition to** the httpOnly cookie. Any frontend code that stores this in `localStorage` becomes XSS-vulnerable. The token in the response body is unnecessary. |
| 7 | — | Security | 🟠 **High** | No rate limiting or account lockout on `login`. Brute-force attacks are unlimited. |
| 8 | 120 | Bug | 🟢 **Low** | `logout()` does not include `secure: process.env.NODE_ENV === 'production'` in `clearCookie()`. The cookie may not be cleared correctly in production where it was originally set with `secure: true`. |

---

## `backend/routes/walkin.js`

| # | Line | Type | Severity | Description |
|---|------|------|----------|-------------|
| 9 | 7–8 | Security | 🟠 **High** | `GET /api/walkin` and `GET /api/walkin/stats` have **no authentication**. They are publicly accessible and expose customer PII (names, phone numbers, service details) without any login. |

---

## `backend/controllers/walkinController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 10 | 26–30 | Bug / Security | 🟠 **High** | `list()`: if `branchId` query param is missing, `where.branch_id = undefined` is set. Sequelize may silently ignore `undefined` values in `where`, potentially returning **all walk-in entries across all branches**. No guard requires `branchId`. |
| 11 | 11–17 | Race Condition | 🟠 **High** | `generateToken()` does a `COUNT` then adds 1. Two simultaneous check-ins at the same branch will get the same count and generate **duplicate tokens** (e.g., two customers both get token `T003`). Needs a DB-level unique constraint or atomic sequence. |
| 12 | 112–113 | Logic Error | 🟢 **Low** | `updateStatus()` when status becomes `'serving'` overwrites `check_in_time` (the original queue arrival time) with the current time, destroying the check-in timestamp. Should write to a separate `service_start_time` field. |

---

## `backend/controllers/appointmentController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 13 | 122–127 | Security | 🟠 **High** | `update()`, `changeStatus()`, `remove()`, and `stopRecurring()` fetch by `req.params.id` **without checking `branch_id`**. A manager at Branch A can modify or delete appointments belonging to Branch B by guessing their IDs. |
| 14 | 143 | Bug | 🟡 **Medium** | `changeStatus()` reads appointment data from the **pre-update** in-memory object to pass to the notification. While FK fields don't change, this fragile pattern could cause bugs if the object is ever reloaded. |
| 15 | 241–249 | Logic Error | 🟡 **Medium** | `stopRecurring()` uses `parentId = appt.recurrence_parent_id \|\| appt.id`. If a child appointment's ID is passed, the bulk cancel targets children-of-children (which don't exist), but the actual parent appointment is never cancelled. |

---

## `backend/controllers/paymentController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 16 | 173–174 | Bug | 🔴 **Critical** | `Payment.update({ review_token: reviewToken }, { where: { id: payment.id } })` is **not awaited**. The token is fire-and-forgotten. `notifyReviewRequest()` is called immediately after and passes the token to the notification, but the token may not be persisted in the DB yet. Review links will be broken intermittently. |
| 17 | 90–97 | Logic Error | 🟠 **High** | Commission is calculated on `total_amount` (full payment), not on the net amount after loyalty discount. If a customer pays Rs. 1000 but Rs. 200 is a loyalty discount, commission is calculated on Rs. 1000 instead of Rs. 800. |
| 18 | 117–120 | Logic Error | 🟠 **High** | Loyalty points deduction uses `Math.ceil(loyalty_discount)` but earning uses `Math.floor(total / 10)`. The redemption cost is 10× higher than the earning rate — creates an inconsistent loyalty system. |
| 19 | 75, 141, 155 | Code Quality | 🟢 **Low** | `require('../models')` is called multiple times inside the request handler body instead of at the top of the file. While cached by Node, this is confusing and against best practice. |
| 20 | — | Code Quality | 🟢 **Low** | After the transaction commits, the code re-fetches the customer from the DB just to get the updated loyalty_points for a notification. The updated balance should be tracked locally to avoid an extra DB query. |

---

## `backend/controllers/staffController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 21 | 102 | Security | 🟠 **High** | `update()`: `await staff.update(req.body)` passes the **entire unvalidated request body**. A manager could send `{ branch_id: 1, commission_value: 0 }` or other arbitrary fields. No whitelist of allowed fields exists. |
| 22 | 137–163 | Performance | 🟠 **High** | `commissionSummary()` executes one `Payment.findAll()` per staff member in a loop — **classic N+1 query problem**. For 50 staff = 51 DB queries. Should use a single aggregated query with `GROUP BY staff_id`. |
| 23 | 102 | Security | 🟡 **Medium** | `update()` does not verify the staff member belongs to the requesting manager's branch. A manager can update any staff record across all branches. |

---

## `backend/controllers/customerController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 24 | 80 | Security | 🟠 **High** | `update()`: `await cust.update(req.body)` — full mass assignment, no field whitelist. A caller could directly overwrite `loyalty_points`, `visits`, and `total_spent`. |
| 25 | 111 | Logic Error | 🟡 **Medium** | `loyalty()`: after `action === 'redeem'`, the response returns `cust.loyalty_points`. While Sequelize patches the in-memory model instance, this should be explicitly verified with a fresh fetch to ensure correctness. |

---

## `backend/controllers/reportController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 26 | 56, 88, 116 | Bug | 🟡 **Medium** | Month end date is hardcoded as `-31`. Months with fewer than 31 days (Feb, Apr, Jun, Sep, Nov) will produce invalid or empty date ranges. The correct approach: `new Date(year, month, 0).getDate()`. |
| 27 | 161 | Bug | 🟡 **Medium** | `dashboard()` also uses hardcoded `'${yrStr}-${moStr}-31'` — same hardcoded `-31` bug. February and short months will return wrong data. |
| 28 | 98–112 | Logic Error | 🟡 **Medium** | `staffReport()`: when no date filter is set, the appointment `where` becomes `{}` — ALL appointments are fetched for all branches, not just the selected branch. |

---

## `backend/controllers/attendanceController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 29 | 5–9 | Dead Code | 🟢 **Low** | Empty `if (req.userBranchId) { // Join with staff to filter by branch }` block is completely dead. The actual branch filtering is done via `staffWhere` 10 lines later. Misleads readers. |
| 30 | 46–52 | Bug | 🟡 **Medium** | `upsert()`: the subsequent `record.update({ check_in, check_out, status, note })` on existing records will attempt to set `undefined` fields, potentially **clearing existing values**. Should only set fields that are explicitly provided in the request. |

---

## `backend/controllers/packageController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 31 | ~167–179 | Performance | 🟡 **Medium** | `customerPackages()` loops over results and calls `await cp.update()` for each expired package — N+1 write problem. Should use a single bulk `CustomerPackage.update(...)` with a `WHERE` clause. |
| 32 | ~256 | Logic Error | 🟡 **Medium** | `purchase()`: `sessions_total: pkg.sessions_count \|\| 0` — if `sessions_count` is `null` (membership/unlimited packages), `sessions_total` is set to `0`, making the package immediately appear depleted. Membership packages need separate logic. |

---

## `backend/controllers/expenseController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 33 | ~196 | Bug | 🟡 **Medium** | `create()` never sets `created_by: req.user.id`. The `created_by` foreign key will always be `null` in the DB even though the model defines the field and the FK exists. |

---

## `backend/controllers/reviewController.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 34 | 22, 38 | Security | 🟡 **Medium** | `review_token` (UUID) is never nullified after a successful submission. The token remains valid indefinitely for lookups. Best practice: null the token after successful review submission to prevent token reuse. |

---

## `backend/controllers/notificationController.js`

| # | Line | Type | Severity | Description |
|---|------|------|----------|-------------|
| 35 | 62 | Logic Error | 🟢 **Low** | `getSettings()` only fetches settings where `branch_id = null` (global settings). Per-branch notification settings are never supported, which contradicts the multi-branch architecture. |

---

## `backend/controllers/userController.js`

| # | Line | Type | Severity | Description |
|---|------|------|----------|-------------|
| 58 | 67 | Security | 🟠 **High** | `update()` allows an `admin` to change any user's `role`, including promoting `staff` to `superadmin`. Role elevation should require the `superadmin` role. |
| 59 | 62 | Security | 🟡 **Medium** | `update()` allows changing a user's `username` with no uniqueness pre-check. The DB UNIQUE constraint will return an unhandled 500 instead of a proper 409 Conflict response. |

---

## `backend/controllers/branchController.js`

| # | Line | Type | Severity | Description |
|---|------|------|----------|-------------|
| 60 | 52 | Security | 🟠 **High** | `update()`: `await branch.update(req.body)` — full mass assignment. A caller can set arbitrary columns (e.g., `status`) with no field whitelist. |

---

## `backend/controllers/inventoryController.js`

| # | Line | Type | Severity | Description |
|---|------|------|----------|-------------|
| 61 | 63 | Security | 🟡 **Medium** | `update()`: `await item.update(req.body)` — same mass assignment problem as above. No field whitelist. |

---

## `backend/services/notificationService.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 36 | ~150 | Security | 🟡 **Medium** | `buildEmailWrapper()`: `branchName` and `branchPhone` from the DB are interpolated directly into HTML without escaping. If a branch name contains `<script>` or HTML tags, they will be injected into outgoing emails (HTML injection). |

---

## `backend/services/recurringService.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 37 | 25–35 | Race Condition | 🟡 **Medium** | Staff availability check (`Appointment.findOne()` conflict check) and `Appointment.create()` are not atomic. Two concurrent requests can both pass the check and book the same slot. Needs a transaction with pessimistic locking or a unique DB constraint on `(staff_id, date, time)`. |
| 38 | — | Race Condition | 🟡 **Medium** | `changeStatus()` uses `setImmediate(() => createNextRecurring(appt))`. If status is changed to `'completed'` twice (network retry / double-click), two recurring child appointments will be spawned with no idempotency check. |

---

## `backend/socket.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 39 | 10–16 | Security | 🟠 **High** | **No authentication for WebSocket connections.** Any external client can connect, emit `join({ branchId: X })` with any `branchId`, and receive real-time queue updates including customer names, phone numbers, and service details for any branch. |

---

## `backend/routes/services.js`

| # | Line | Type | Severity | Description |
|---|------|------|----------|-------------|
| 40 | 14–15 | Bug | 🟠 **High** | `router.put('/categories/rename', ...)` and `router.post('/categories/delete', ...)` are registered **after** `router.put('/:id', ...)`. Express will match `PUT /categories/rename` against `/:id` first (with `id = 'categories'`). The rename and delete category handlers will **never be reached**. These routes must be registered before the `/:id` wildcard routes. |

---

## `backend/models/Appointment.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 62 | 65–70 | Missing Constraint | 🟡 **Medium** | `recurrence_parent_id` and `next_appointment_id` have no `onDelete: 'CASCADE'` defined. Deleting a parent appointment will leave orphaned child records in the database. |

---

## `backend/models/Customer.js`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 63 | — | Missing Validation | 🟢 **Low** | `email` field has no format validation (`validate: { isEmail: true }`). Invalid email addresses will be silently stored and cause notification delivery failures. |
| 64 | — | Missing Constraint | 🟢 **Low** | No unique constraint on `(phone, branch_id)`. Duplicate customers with the same phone number can be created, splitting their visit history and loyalty points. |

---

## `docker-compose.yml`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 41 | 29 | Security | 🟠 **High** | MySQL port `3306` is exposed to the host via `"${DB_PORT:-3307}:3306"`. If the host firewall allows inbound connections, the database is directly reachable from the internet. The `ports` mapping for the DB service should be removed in production (keep only internal Docker network access). |
| 42 | 34 | Security | 🟠 **High** | Default `JWT_SECRET=zanesalon_docker_jwt_secret_change_me` in the compose file. If a `.env` file is missing, the entire deployment uses this publicly-known default, making all JWTs forgeable by anyone. |
| 43 | ~64 | Security | 🟠 **High** | `phpmyadmin` is deployed with no additional access control. The `pma.zanesalon.com` subdomain gives any internet visitor access to a full database management UI, protected only by the (weak/default) MySQL credentials. Should be IP-restricted or removed from production. |
| 44 | — | Security | 🟡 **Medium** | No network segmentation. All services share the default bridge network. phpMyAdmin can directly reach all backend API containers. Should use separate `frontend`, `backend`, and `db` Docker networks. |

---

## `proxy/default.conf`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 45 | 44–53 | Bug | 🔴 **Critical** | The WebSocket `location /socket.io/` block under the HTTPS frontend server proxies to `http://frontend:80` — the **nginx static-file server**, not the Node.js backend. All Socket.io / WebSocket connections from the production frontend will fail. Must proxy to `http://backend:5000`. |
| 46 | — | Security | 🟡 **Medium** | Missing security headers on all virtual hosts: no `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, or `Content-Security-Policy`. |
| 47 | 104 | Security | 🟢 **Low** | phpMyAdmin vhost has `client_max_body_size 50M`. Unnecessarily large for a DB admin UI. |

---

## `frontend/nginx.conf`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 48 | — | Security | 🟡 **Medium** | Missing security headers: no `Content-Security-Policy`, `X-Frame-Options`, or `X-Content-Type-Options`. The SPA is served without any security headers. |

---

## `frontend/src/pages/LoginPage.jsx`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 49 | 23–28 | Security | 🔴 **Critical** | `DEMO_ACCOUNTS` array containing real usernames and passwords (`admin123`, `manager123`, `staff123`) is **hardcoded and shipped to every browser** as part of the JavaScript bundle. Any visitor who opens DevTools can see all credentials. Must be removed before any real deployment. |

---

## `frontend/src/pages/BookingPage.jsx`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 50 | 75 | Bug | 🔴 **Critical** | `handleSubmit` posts to `POST /api/public/bookings` — **this endpoint does not exist**. The public routes file only defines `/branches`, `/services`, `/staff`, and `/availability`. All booking form submissions will receive a 404. The entire public booking feature is broken. |
| 51 | 47, 53, 60, 66 | Missing Error Handling | 🟡 **Medium** | All `useEffect` fetch calls use `.catch(() => {})` — errors are completely swallowed with no user feedback when branches, services, or staff fail to load. |
| 52 | 74 | UX / Bug | 🟢 **Low** | Uses native `alert()` for error messages. Blocks the JS thread, cannot be styled, and behaves differently across browsers/systems. |
| 53 | 53 | Bug | 🟢 **Low** | `useEffect` has `[step]` as dependency array but also reads `services.length` inside, which is missing from the dependencies. Stale closure could prevent reload under certain conditions. |

---

## `frontend/src/pages/ReviewFormPage.jsx`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 54 | 22 | Bug | 🟡 **Medium** | `const [submitting, setSubmitting] = useState('')` is used as **both a boolean loading flag** (`setSubmitting('sending')`) and an **error message string** (`setSubmitting('Please rate the service.')`). Two separate concerns are conflated into one state variable, making the render logic ambiguous. |

---

## `frontend/src/pages/DashboardPage.jsx`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 55 | ~155–164 | Code Quality | 🟢 **Low** | Branch filter is built via manual string interpolation (`` `?branchId=${branchId}` ``) and appended to URL strings instead of using axios's `params` option. Error-prone and bypasses axios's built-in sanitization. |

---

## `frontend/src/pages/TokenDisplayScreen.jsx`

| # | Lines | Type | Severity | Description |
|---|-------|------|----------|-------------|
| 56 | 4 | Security | 🟡 **Medium** | Imports raw `axios` directly instead of the configured `api` instance. No interceptors are present — 401 responses will not redirect to login; errors will fail silently. |
| 57 | 47 | Bug | 🟢 **Low** | `const branchId = searchParams.get('branchId') \|\| '1'` defaults to branch ID `1` when no param is provided. In a multi-branch deployment this will silently show the wrong branch's queue. |

---

## Cross-Cutting / Architectural Issues

| # | Type | Severity | Description |
|---|------|----------|-------------|
| 65 | Security | 🟠 **High** | **No CSRF protection.** The app uses `SameSite: lax` cookies, which blocks cross-site form POSTs but not `fetch()`/`XMLHttpRequest` from same eTLD+1. No CSRF token mechanism is implemented. |
| 66 | Security | 🟠 **High** | **No rate limiting on any endpoint.** Login, register, and review submission can be called unlimited times. `express-rate-limit` is entirely absent from the codebase. |
| 67 | Security | 🟡 **Medium** | **No JWT revocation / blacklist.** Logging out only clears the client-side cookie. The JWT remains valid server-side for 7 days. A stolen token cannot be revoked. |
| 68 | Security | 🟡 **Medium** | **No input sanitization middleware** (e.g., `helmet`, `xss-clean`). No global middleware strips XSS characters from string inputs before they reach controllers. |
| 69 | Security | 🟡 **Medium** | **Mass assignment is a systemic pattern.** `model.update(req.body)` is used without field whitelists across `appointment`, `staff`, `customer`, `branch`, `inventory`, `attendance`, `reminder`, and `service` controllers. Should be replaced with explicit field whitelists everywhere. |
| 70 | Security | 🟠 **High** | **Cross-branch authorization not enforced for resource ownership.** A manager at Branch A can read, update, or delete a `Customer`, `Appointment`, or `Payment` belonging to Branch B by guessing the record ID. Most `getOne`/`update`/`remove` operations fetch only by primary key without verifying `branch_id` matches `req.userBranchId`. |

---

## Recommended Fix Priority

### 🔴 Fix Immediately (Critical — Production Blockers)

1. **Issue #4 / #5** — Remove auth guard from `/register` and restrict `role` field in `authController.register()`.
2. **Issue #49** — Remove `DEMO_ACCOUNTS` with plaintext passwords from `LoginPage.jsx`.
3. **Issue #50** — Implement `POST /api/public/bookings` route or fix the endpoint URL — the booking page is completely broken.
4. **Issue #45** — Fix WebSocket proxy config in `proxy/default.conf` — all Socket.io connects fail in production.
5. **Issue #16** — Add `await` before `Payment.update({ review_token })` in `paymentController.js`.
6. **Issue #1 / #2** — Add `.env` to `.gitignore`, rotate exposed DB password and JWT secret immediately.

### 🟠 Fix Before Public Launch (High)

7. **Issue #39** — Add authentication to Socket.io connections.
8. **Issue #40** — Move `/categories/rename` and `/categories/delete` routes before `/:id` wildcard in `routes/services.js`.
9. **Issue #9** — Add `authenticate` middleware to walk-in list and stats routes.
10. **Issue #17 / #18** — Fix commission base amount and loyalty points earn/redeem rate inconsistency.
11. **Issue #66** — Add `express-rate-limit` to login, register, and sensitive endpoints.
12. **Issue #70** — Enforce `branch_id` ownership checks in all `getOne`/`update`/`remove` operations.
13. **Issue #41 / #42 / #43** — Remove DB port exposure, fix default JWT secret, and restrict phpMyAdmin access in `docker-compose.yml`.
14. **Issue #13** — Add `branch_id` ownership check to appointment `update()`, `changeStatus()`, `remove()`, `stopRecurring()`.
15. **Issue #58** — Restrict role changes to `superadmin` in `userController.update()`.
16. **Issues #21, #24, #60, #61** — Replace `model.update(req.body)` with explicit field whitelists.
17. **Issue #22** — Fix N+1 in `commissionSummary()` with a single aggregated query.
18. **Issue #11** — Fix duplicate walk-in token generation race condition.

### 🟡 Fix Soon (Medium)

19. **Issues #26 / #27** — Fix hardcoded `-31` day in `reportController.js` for all date range queries.
20. **Issue #36** — HTML-escape `branchName` and `branchPhone` before interpolating into email HTML.
21. **Issue #30** — Fix `attendance.upsert()` to only update explicitly provided fields.
22. **Issue #32** — Handle `null` `sessions_count` for membership-type packages in `packageController.purchase()`.
23. **Issue #33** — Add `created_by: req.user.id` to `Expense.create()`.
24. **Issue #65 / #66 / #67 / #68** — Add CSRF protection, rate limiting, JWT revocation, and input sanitization middleware.
25. **Issue #37** — Wrap staff availability check + appointment create in an atomic transaction.
26. **Issue #54** — Split `submitting` state into separate loading and error states in `ReviewFormPage.jsx`.

---

*Report covers all files read as of 2026-03-23. Some line numbers are approximate for compiled/minified files.*
