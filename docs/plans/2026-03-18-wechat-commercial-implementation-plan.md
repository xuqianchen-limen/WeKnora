# WeKnora Commercial WeChat Bot Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a commercially usable WeKnora control plane first?login-gated access, admin-managed model allocation, wallet/recharge, real-time billing, and usage overview?then integrate authenticated `wechat_v1` API access as a separate follow-up while preserving current WeKnora agent behavior and weighting UX.

**Architecture:** Keep WeKnora as the single web/API control plane and add billing, wallet, model-channel, admin, and usage modules inside the existing monolith. Delay `D:\AAAlimenAI\wechat_bot\RPA\wechat_v1` changes until the WeKnora user/admin control plane is stable, then integrate the client against finalized authenticated APIs instead of asking users for upstream LLM API credentials.

**Tech Stack:** Go, Gin, GORM, SQL migrations, Vue 3 + TypeScript, existing WeKnora auth/tenant modules, Python + PyQt5 + httpx in `wechat_v1`.

---

## Preconditions

- Work in `D:\AAAlimenAI\wechat_bot\WeKnora`
- Treat current auth, tenant, agent, session, message, model, and IM capabilities as reusable foundations
- Preserve existing WeKnora agent configuration UI and question-answer weighting behavior
- Add new UI entry points only for account, billing, recharge, overview, and admin functions

## Task 1: Establish the commercial domain model and migration set

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000025_wallet_and_billing.up.sql`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000025_wallet_and_billing.down.sql`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000026_model_channels_and_routes.up.sql`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000026_model_channels_and_routes.down.sql`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000027_usage_records.up.sql`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000027_usage_records.down.sql`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000028_admin_ops_and_payment_orders.up.sql`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\migrations\versioned\000028_admin_ops_and_payment_orders.down.sql`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\types\`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\models\`

**Step 1: Write failing migration or schema tests**

- Add migration test coverage if the repo already has a migration verification pattern.
- If no migration tests exist, create a lightweight repository-level boot test that asserts the new tables exist after migration.

**Step 2: Run the migration verification**

Run the project’s migration/test command and confirm the new schema is missing before implementation.

Expected: fail because wallet/billing/channel/usage tables do not exist yet.

**Step 3: Implement the schema**

Create tables for:

- `wallet_accounts`
- `wallet_ledger`
- `recharge_orders`
- `payment_transactions`
- `model_provider_channels`
- `model_route_policies`
- `tenant_model_entitlements`
- `usage_records`
- `usage_daily_stats`
- `admin_operation_logs`

Key design rules:

- preserve `tenant_id`
- use append-only ledger
- store price snapshots in usage rows
- store encrypted provider keys or references
- allow later team/tenant expansion

**Step 4: Run migration verification again**

Expected: pass and tables are present.

**Step 5: Commit**

```bash
git add migrations/versioned internal/models internal/types
git commit -m "feat: add wallet billing and model routing schema"
```

## Task 2: Add domain types, repositories, and interfaces

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\types\wallet.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\types\billing.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\types\model_channel.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\repository\wallet.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\repository\billing.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\repository\model_channel.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\types\interface.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\repository\wallet_test.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\repository\billing_test.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\repository\model_channel_test.go`

**Step 1: Write failing repository tests**

Cover:

- create/find wallet account by user
- append ledger row and update balance
- create recharge order
- create usage record
- list usage filters by session/document/model
- list active model channels by logical model

**Step 2: Run repository tests to verify failure**

Run targeted `go test` commands for the new repository package tests.

Expected: fail because repositories and types do not exist.

**Step 3: Implement minimal repositories and interfaces**

Add GORM repositories with exact methods for:

- `GetOrCreateWalletByUser`
- `AppendLedgerEntryWithBalanceUpdate`
- `CreateRechargeOrder`
- `UpdateRechargeOrderStatus`
- `CreateUsageRecord`
- `ListUsageRecords`
- `AggregateUsageOverview`
- `ListChannelsByLogicalModel`
- `ListEntitledModelsByTenant`

**Step 4: Re-run tests**

Expected: pass.

**Step 5: Commit**

```bash
git add internal/types internal/application/repository
git commit -m "feat: add wallet billing and model channel repositories"
```

## Task 3: Build wallet, recharge, billing, and usage services

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\wallet.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\billing.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\recharge.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\usage.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\user.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\tenant.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\wallet_test.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\billing_test.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\usage_test.go`

**Step 1: Write failing service tests**

Cover:

- auto-create wallet on first login/register
- manual recharge increases balance
- insufficient balance blocks chargeable request
- charge writes ledger + usage rows atomically
- overview aggregates today/month/total
- manual adjustment requires admin actor

**Step 2: Run service tests to verify failure**

Expected: fail because service implementations do not exist.

**Step 3: Implement minimal services**

Implement:

- wallet lifecycle
- manual recharge workflow
- billing charge workflow
- usage overview aggregation
- admin adjustment logging

Billing rule for Phase 1:

- only enforce charge on chat completions first
- preserve the service interfaces so embedding/rerank/OCR billing can be added without API changes

**Step 4: Re-run tests**

Expected: pass.

**Step 5: Commit**

```bash
git add internal/application/service
git commit -m "feat: add wallet recharge billing and usage services"
```

## Task 4: Add model channel allocation and routing services

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\model_routing.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\model_entitlement.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\model.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\chat_pipline\chat_completion.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\chat_pipline\chat_completion_stream.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\model_routing_test.go`

**Step 1: Write failing routing tests**

Cover:

- select primary active channel
- weighted selection among healthy channels
- fallback on primary failure
- deny model when tenant/user has no entitlement
- preserve current logical model UX in user flows

**Step 2: Run routing tests**

Expected: fail.

**Step 3: Implement minimal router**

Phase 1 router rules:

- map logical model to provider channels
- choose active channel by priority/weight
- fallback to next healthy channel on failure
- keep routing hidden from users

Do not expose provider selection to frontend users.

**Step 4: Re-run tests**

Expected: pass.

**Step 5: Commit**

```bash
git add internal/application/service internal/application/service/chat_pipline
git commit -m "feat: add admin managed model routing and entitlements"
```

## Task 5: Hook authenticated chat usage into billing

**Files:**
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\message.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\session.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\chat_pipline\chat_completion.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\chat_pipline\chat_completion_stream.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\knowledge.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\message_billing_test.go`

**Step 1: Write failing integration-style service tests**

Cover:

- logged-in user sends a chat message
- response uses routed logical model
- usage row gets recorded
- wallet gets charged
- insufficient balance rejects request before expensive execution

**Step 2: Run tests and confirm failure**

Expected: fail because message/session flow is not billing-aware.

**Step 3: Implement minimal charge path**

Wire billing into current message/session/chat pipeline by:

- extracting final usage metadata from model response
- writing `usage_records`
- appending ledger debit
- including enough IDs for later traceability

Do not alter current agent-weight UX or prompt behavior.

**Step 4: Re-run tests**

Expected: pass.

**Step 5: Commit**

```bash
git add internal/application/service
git commit -m "feat: charge chat usage and persist traceable billing records"
```

## Task 6: Add auth gating and admin authorization boundaries

**Files:**
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\auth.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\middleware\`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\router\router.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\user.go`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\auth_test.go`

**Step 1: Write failing auth tests**

Cover:

- unauthenticated chat endpoints blocked
- unauthenticated knowledge and custom agent endpoints blocked
- admin-only endpoints blocked for regular users
- login still works for existing flows

**Step 2: Run auth tests**

Expected: fail where admin boundaries do not exist yet.

**Step 3: Implement the access policy**

- Require login for all chargeable core features
- Add admin authorization middleware or role check
- Keep current `/auth/*` public endpoints usable

**Step 4: Re-run tests**

Expected: pass.

**Step 5: Commit**

```bash
git add internal/handler internal/middleware internal/router internal/application/service
git commit -m "feat: add login gating and admin authorization boundaries"
```

## Task 7: Expose account, recharge, usage, billing, and admin APIs

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\wallet.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\billing.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\admin_billing.go`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\admin_model_channel.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\router\router.go`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\docs\swagger.yaml`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\docs\swagger.json`

**Step 1: Write failing handler tests**

Cover:

- get current wallet
- list billing overview
- list billing details
- create manual recharge as admin
- manage model channels as admin
- list entitled models for current user

**Step 2: Run handler tests**

Expected: fail because APIs do not exist.

**Step 3: Implement minimal APIs**

Phase 1 endpoints should include:

- `GET /api/v1/account/wallet`
- `GET /api/v1/account/billing/overview`
- `GET /api/v1/account/billing/records`
- `POST /api/v1/admin/recharges/manual`
- `GET /api/v1/admin/users`
- `GET/POST/PUT /api/v1/admin/model-channels`
- `GET /api/v1/account/models`

**Step 4: Re-run tests**

Expected: pass.

**Step 5: Commit**

```bash
git add internal/handler internal/router docs/swagger.yaml docs/swagger.json
git commit -m "feat: expose wallet billing recharge and admin model APIs"
```

## Task 8: Add commercial frontend APIs and route guards

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\wallet\index.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\billing\index.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\admin\billing.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\admin\model-channel.ts`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\auth\index.ts`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\router\`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\wallet\index.test.ts`

**Step 1: Write failing frontend API tests or type checks**

Cover:

- wallet response typing
- billing overview typing
- recharge/admin payload typing
- route guard behavior for protected views

**Step 2: Run type checks**

Use the project’s frontend type-check command.

Expected: fail because the new modules/routes are not implemented.

**Step 3: Implement API clients and guards**

- add current user wallet API wrappers
- add billing overview/detail API wrappers
- add admin-only API wrappers
- gate billing/admin pages by auth state and role

**Step 4: Re-run type checks**

Expected: pass.

**Step 5: Commit**

```bash
git add frontend/src/api frontend/src/router
git commit -m "feat: add frontend billing and admin API clients"
```

## Task 9: Add user billing overview and account pages

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\account\WalletOverview.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\account\BillingRecords.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\components\billing\BillingOverviewCards.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\components\billing\BillingRecordsTable.vue`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\login\`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\layout\`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\account\WalletOverview.spec.ts`

**Step 1: Write failing component tests or snapshots**

Cover:

- balance display
- today/month/total cards
- filterable billing records list
- clear insufficient-balance messaging

**Step 2: Run component tests or type checks**

Expected: fail.

**Step 3: Implement UI**

UI rules:

- do not alter existing agent weighting/config UI
- keep user-facing terms simple
- show current balance prominently
- show recharge entry but mark online payment as “coming later” in Phase 1 if needed

**Step 4: Re-run tests/type checks**

Expected: pass.

**Step 5: Commit**

```bash
git add frontend/src/views frontend/src/components frontend/src/layout
git commit -m "feat: add user wallet and billing overview pages"
```

## Task 10: Add admin console pages for users, recharge, and model channels

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\admin\UserManagement.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\admin\ManualRecharge.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\admin\ModelChannelManagement.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\components\admin\ManualRechargeDialog.vue`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\router\`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\views\admin\ModelChannelManagement.spec.ts`

**Step 1: Write failing UI tests or snapshots**

Cover:

- list users with balances
- manual recharge flow
- create/edit model channel
- toggle channel enabled/disabled

**Step 2: Run tests or type checks**

Expected: fail.

**Step 3: Implement admin UI**

Keep Phase 1 scope tight:

- no enterprise hierarchy
- no coupon system
- no complex reports
- only user search, manual recharge, model channel config, and route basics

**Step 4: Re-run tests/type checks**

Expected: pass.

**Step 5: Commit**

```bash
git add frontend/src/views/admin frontend/src/components/admin frontend/src/router
git commit -m "feat: add admin recharge user and model channel pages"
```

## Task 11: Phase 1 end-to-end verification for the WeKnora control plane

**Files:**
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\docs\commercial-phase1-verification.md`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\README_CN.md`

**Step 1: Write the verification checklist**

Document:

- user registration/login
- admin manual recharge
- wallet overview display
- chat usage debits wallet
- billing detail traceability
- admin model channel management

**Step 2: Run the actual verification commands**

Suggested commands:

- backend targeted `go test` for repository/service/handler packages
- frontend type check/build

Expected: all pass with evidence captured in the verification doc.

**Step 3: Fix any failing checks**

Do not declare control-plane completion until all required checks pass.

**Step 4: Commit**

```bash
git add docs README_CN.md
git commit -m "docs: add commercial phase 1 verification checklist"
```

## Task 14: Add separate verification for `wechat_v1` integration

**Files:**
- Modify: `D:\AAAlimenAI\wechat_bot\RPA\wechat_v1\BUILD_GUIDE.md`
- Create: `D:\AAAlimenAI\wechat_bot\RPA\wechat_v1\docs\weknora-auth-verification.md`

**Step 1: Write the verification checklist**

Document:

- wechat_v1 login to WeKnora
- token refresh
- authenticated reply flow
- insufficient balance prompt
- invalid token / expired login prompt

**Step 2: Run targeted client verification**

- `wechat_v1` targeted tests
- manual desktop verification against a stable WeKnora environment

Expected: all pass with captured evidence.

**Step 3: Fix failing checks**

Do not merge client integration until verification passes.

**Step 4: Commit**

```bash
git add D:/AAAlimenAI/wechat_bot/RPA/wechat_v1
git commit -m "docs: add wechat client auth verification checklist"
```

## Task 15: Phase 2+ follow-up backlog for post-MVP work

**Files:**
- Update: `D:\AAAlimenAI\wechat_bot\WeKnora\docs\plans\2026-03-18-wechat-commercial-design.md`
- Update: `D:\AAAlimenAI\wechat_bot\WeKnora\docs\ROADMAP.md`

**Step 1: Add explicit post-MVP backlog items**

Record:

- billing for embedding/rerank/OCR/import jobs
- async usage aggregation jobs
- advanced channel health checks
- fallback and circuit breaker metrics
- online payment
- team account upgrade path

**Step 2: Review for scope discipline**

Confirm these items are not accidentally pulled into Phase 1 delivery.

**Step 3: Commit**

```bash
git add docs/plans/2026-03-18-wechat-commercial-design.md docs/ROADMAP.md
git commit -m "docs: record post-mvp commercial backlog"
```

## Recommended implementation order

1. Migrations and domain types
2. Repositories
3. Wallet/billing services
4. Model channel routing
5. Chat billing hook
6. Auth gating and admin auth
7. Backend APIs
8. Frontend account/admin pages
9. `wechat_v1` login client
10. WeKnora control-plane verification
11. `wechat_v1` separate integration
12. `wechat_v1` verification

## Scope guards

- Do not redesign current WeKnora agent weighting UX
- Do not expose upstream provider settings to normal users
- Do not build team/org collaboration in Phase 1
- Do not block the MVP on WeChat Pay
- Do not split a separate billing microservice yet

## Delivery definition for Phase 1

Phase 1 is complete only when all of the following are true:

- login is required for core usage
- admin can manually recharge a user
- a user can see balance and billing overview
- a user’s chat usage produces traceable debit records
- user-facing model/API complexity stays hidden
- verification evidence is recorded for the WeKnora control plane

## Separate milestone for `wechat_v1`

`wechat_v1` integration is considered complete only when:

- WeKnora control-plane APIs are already stable
- client login and refresh work
- client requests are authenticated
- wallet/auth errors are surfaced clearly
- client-side verification evidence is recorded

## Phase 1 reuse / small-change / new-build / deferred matrix

### Directly reusable in Phase 1

#### Authentication foundation
- Reuse: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\auth.go`
- Reuse: `D:\AAAlimenAI\wechat_bot\WeKnora\internal\application\service\user.go`
- Reuse: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\auth\index.ts`

Already available:
- register / login / logout
- JWT access token
- refresh token
- `/auth/me`
- `/auth/validate`
- token revoke / validate path

#### User + default workspace foundation
- Reuse existing register flow that auto-creates a default tenant/workspace for each user.
- Keep product behavior as “personal account system”, while retaining `tenant_id` in storage and APIs.

#### Agent / knowledge base / session core
- Reuse current agent CRUD, knowledge base CRUD, session/message/chat pipeline.
- Do not redesign current WeKnora agent weighting or knowledge-answer behavior.

#### Model management foundation
- Reuse current model CRUD and builtin model sensitive-field hiding.
- Existing files include `D:\AAAlimenAI\wechat_bot\WeKnora\internal\handler\model.go` and `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\api\model\index.ts`.

#### Tenant isolation foundation
- Reuse current `tenant_id`-based isolation across repository / service / handler layers.
- Reuse current selected-tenant frontend flow where it already exists.

### Small changes in Phase 1

#### Auth closure and access control
Need small changes, not rewrites:
- require login for all chargeable core pages and APIs
- tighten route guards and login redirects
- add admin-only authorization boundary for recharge/model-channel/admin pages
- reduce or remove anonymous access for production-critical features

#### Frontend auth UX
Need small changes:
- normalize expired-token handling
- normalize refresh-token failure handling
- redirect to login consistently when core pages are accessed unauthenticated

#### User-facing model UX
Need small changes:
- user side should stop exposing provider/API details as product-level concepts
- admin side can still manage actual model config and provider details
- preserve current agent configuration behavior

#### Account navigation
Need small changes:
- add wallet / billing / recharge-record entry points in user menu or account area
- add admin console navigation entries for recharge and model-channel management

### New development required in Phase 1

#### Wallet system
Must build:
- `wallet_accounts`
- `wallet_ledger`
- wallet repository/service/handler

Required capability:
- current balance
- debit records
- recharge records
- manual adjustments

#### Recharge system
Must build:
- `recharge_orders`
- admin manual recharge API
- admin manual recharge page
- audit log for operator actions

Phase 1 scope:
- manual recharge only
- user can view recharge history
- no online payment yet

#### Usage tracking and billing
Must build:
- `usage_records`
- `usage_daily_stats`
- billing aggregation service

Phase 1 billing scope:
- chat usage only
- persist model, token count, session/message/agent traceability
- persist charge snapshot

Deferred later:
- embedding billing
- rerank billing
- OCR billing
- document import billing

#### Charge closure in chat flow
Must build:
- balance check before expensive execution
- usage persistence after model response
- wallet debit after successful chargeable completion
- insufficient-balance response path

#### User billing overview
Must build:
- wallet overview page
- billing overview cards
- billing records page

Minimum fields:
- current balance
- today spend
- current month spend
- cumulative recharge
- billing detail rows with time / session / agent / model / tokens / amount

#### Admin console for commercial control
Must build:
- user list with balance
- manual recharge page / dialog
- model channel management page
- basic entitlement / pricing management APIs

#### Model channel pool (minimum viable version)
Must build:
- `model_provider_channels`
- `tenant_model_entitlements`
- primary / fallback routing support

Phase 1 route scope:
- logical model -> provider channel mapping
- admin-managed only
- user never sees provider details

### Explicitly deferred from Phase 1

#### Online payment / WeChat Pay
Defer:
- payment order checkout
- callback settlement
- reconciliation
- refund workflow

#### Team / organization monetization
Defer:
- multi-member workspace sharing
- shared wallet
- enterprise role system

#### Complex package operations
Defer:
- coupons
- monthly packages
- tiered subscriptions
- distribution / referral

#### Full-scene billing
Defer:
- embedding / rerank / OCR / import job charging

#### `wechat_v1`
Defer until the WeKnora control plane is stable:
- WeKnora login integration
- token refresh integration
- authenticated client request flow
- wallet/auth error surfacing in the desktop client

## Immediate executable Phase 1 task breakdown

### Backend track
1. Create wallet / ledger / recharge / usage tables and types.
2. Add repositories for wallet, recharge, usage, and model channels.
3. Add wallet, billing, recharge, and usage services.
4. Add chat billing hook in current message/session/chat pipeline.
5. Add admin APIs for manual recharge, model channels, and user balance views.
6. Tighten auth and admin authorization boundaries.

### Frontend user track
1. Add wallet API and billing API wrappers.
2. Add wallet overview page.
3. Add billing records page.
4. Add account navigation entries.
5. Tighten route guards for authenticated pages.

### Frontend admin track
1. Add user management list with balance column.
2. Add manual recharge UI.
3. Add model channel management UI.
4. Add admin-only route protection.

### Verification track
1. Verify login-gated access still works.
2. Verify admin can manually recharge a user.
3. Verify chat usage creates usage records and wallet debits.
4. Verify user overview and billing detail are traceable.
5. Freeze WeKnora APIs before any `wechat_v1` integration work.

## Recommended Phase 1 start sequence

1. Database schema and backend domain types
2. Repository and service layer
3. Chat billing closure
4. Admin recharge + model-channel APIs
5. User wallet/billing pages
6. Admin pages
7. Control-plane verification

## Phase 1 scope decision summary

### Reuse
- auth
- user + tenant foundation
- agent / knowledge / session core
- existing model CRUD foundation

### Small change
- auth closure
- frontend route guards
- user-facing model UX hiding
- account navigation

### New build
- wallet
- recharge
- usage tracking
- billing overview
- admin control pages
- model channel pool

### Deferred
- WeChat Pay
- enterprise/team monetization
- advanced package system
- non-chat billing scenes
- `wechat_v1` integration
