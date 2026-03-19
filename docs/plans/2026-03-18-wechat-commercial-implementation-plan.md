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
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\shared\api\request.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\shared\auth\session.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\api\wallet.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\api\billing.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\api\recharges.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\api\model-channels.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\router\routes.ts`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\router\routes.ts`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\router\index.ts`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\api\wallet.test.ts`

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
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\views\account\WalletOverview.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\views\account\BillingRecords.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\components\billing\BalanceSummaryCards.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\components\billing\BillingRecordsTable.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\stores\account.ts`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\router\index.ts`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\stores\menu.ts`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\views\account\WalletOverview.spec.ts`

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
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\views\UserManagement.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\views\ManualRecharge.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\views\ModelChannelManagement.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\components\ManualRechargeDialog.vue`
- Create: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\stores\adminCommercial.ts`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\router\index.ts`
- Modify: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\stores\menu.ts`
- Test: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\views\ModelChannelManagement.spec.ts`

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

## Frontend-first file organization and module boundary plan

This section is the Phase 1 code-organization baseline. The goal is to keep the current WeKnora runtime and build pipeline, but isolate frontend code into user-side, admin-side, and shared layers so later changes stay low-risk and local.

### Approved isolation approach

Adopt a single frontend repo with three explicit partitions:

- `frontend/src/apps/user/*` for normal-user product code
- `frontend/src/apps/admin/*` for management-console code
- `frontend/src/shared/*` for truly shared infrastructure only

This is the approved Phase 1 frontend isolation strategy because it gives real separation without introducing a second Vite project, a second deployment pipeline, or duplicated auth/request infrastructure.

### Target frontend directories for Phase 1

#### Root-level shell retained

Keep these root entries small and orchestration-only:

- Reuse: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\main.ts`
- Modify lightly: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\App.vue`
- Modify lightly: `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\router\index.ts`

Root-level files should only bootstrap the app, assemble route modules, and mount the correct layout shell. They must not become a new business-logic dumping ground.

#### User-side isolated code

Create:

- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\api\`
  - `wallet.ts`
  - `billing.ts`
  - `recharge.ts`
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\stores\`
  - `account.ts`
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\views\account\`
  - `WalletOverview.vue`
  - `BillingRecords.vue`
  - `RechargeRecords.vue` (optional late Phase 1)
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\components\billing\`
  - `BalanceSummaryCards.vue`
  - `BillingRecordsTable.vue`
  - `RechargeStatusTag.vue`
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\router\`
  - `routes.ts`
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\user\layout\`
  - user-side wrappers only if current platform layout cannot stay flat

#### Admin-side isolated code

Create:

- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\api\`
  - `users.ts`
  - `recharges.ts`
  - `model-channels.ts`
  - `pricing.ts` (only if Phase 1 pricing is exposed)
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\stores\`
  - `adminCommercial.ts`
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\views\`
  - `UserManagement.vue`
  - `ManualRecharge.vue`
  - `ModelChannelManagement.vue`
  - `UsageOverview.vue` (optional and hidable)
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\components\`
  - `ManualRechargeDialog.vue`
  - `ModelChannelForm.vue`
  - `UserBalanceTable.vue`
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\router\`
  - `routes.ts`
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\apps\admin\layout\`
  - admin wrappers only if needed

#### Shared layer only for true cross-cutting code

Create or migrate only genuinely shared code into:

- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\shared\api\`
  - request client
  - interceptors
  - HTTP base config
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\shared\auth\`
  - auth persistence helpers
  - role / capability helpers
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\shared\components\`
  - pure generic UI only
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\shared\types\`
  - cross-app DTOs only
- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\shared\utils\`
  - formatting / utility functions only

Do not move business pages into `shared`. Shared is infrastructure, not a third business app.

### Isolation rules

#### Dependency direction

Allowed:
- `apps/user -> shared`
- `apps/admin -> shared`
- root bootstrap -> `apps/user`, `apps/admin`, `shared`

Forbidden:
- `apps/user -> apps/admin`
- `apps/admin -> apps/user`
- business logic in root router/store files

This rule is what makes the isolation real instead of nominal.

#### Store ownership

- `shared/auth/*` owns token persistence, current identity hydration, and auth helper primitives
- `apps/user/stores/account.ts` owns wallet, billing overview, billing filters, recharge history
- `apps/admin/stores/adminCommercial.ts` owns user list, recharge operator state, model-channel management state

Do not store wallet summary, admin list state, or billing tables in the old global `auth.ts` beyond backward-compatible bridging during transition.

#### API ownership

- `apps/user/api/*` contains only user-facing commercial API wrappers
- `apps/admin/api/*` contains only admin-facing commercial API wrappers
- `shared/api/*` contains only request base and transport helpers

Do not place user and admin request wrappers in the same directory anymore.

#### View/component ownership

- `apps/user/views/*` and `apps/user/components/*` are for user product flows only
- `apps/admin/views/*` and `apps/admin/components/*` are for admin flows only
- `shared/components/*` may contain buttons, tables, dialogs, and status tags only if they are domain-neutral

If a component contains recharge-specific or model-channel-specific behavior, it does not belong in `shared`.

### Routing and menu assembly under isolation

#### Router strategy

Keep one root router file:

- `D:\AAAlimenAI\wechat_bot\WeKnora\frontend\src\router\index.ts`

But move business route definitions out of it:

- `apps/user/router/routes.ts`
- `apps/admin/router/routes.ts`

Root router responsibilities:
- import user/admin route arrays
- merge them into the current platform route tree
- keep global auth guard registration
- evaluate `requiresAuth` and `requiresAdmin`

Business route modules responsibilities:
- declare their own pages only
- not perform token mutation logic

Recommended route prefixes:
- user: `/platform/account/*`
- admin: `/platform/admin/*`

#### Menu strategy

Current menu state should be progressively reduced to a shell assembler.

Recommended split:
- `apps/user` exports user menu definitions
- `apps/admin` exports admin menu definitions
- root-level menu store assembles visible entries based on auth role/capability

That means the existing `frontend/src/stores/menu.ts` should become a composition layer, not the long-term home of all account/admin menu definitions.

### Transition plan for minimal modification

To preserve minimal-change delivery, do not refactor the whole old frontend before adding commercial pages. Instead apply a staged move:

#### Stage 1: keep old business modules running

Do not relocate current knowledge base / agent / chat / organization pages yet.

#### Stage 2: all new commercial code uses isolated partitions from day one

All newly added commercial frontend code must be created only under:
- `apps/user/*`
- `apps/admin/*`
- `shared/*`

This prevents the new commercial layer from polluting the old flat `src/api`, `src/views`, and `src/stores` layout.

#### Stage 3: only extract old common infrastructure when necessary

Move code into `shared/*` only when both user/admin partitions genuinely need it. Do not do speculative migration.

This keeps the refactor small while still ensuring future code remains clean.

### What remains hidden from users in Phase 1

User-side isolated pages still must not expose:

- provider names as operational concepts
- upstream API keys
- route policy / fallback internals
- channel pool details
- admin pricing controls

Users focus only on:
- agent
- knowledge base
- chat
- balance
- billing details

Admins focus on:
- user account operations
- manual recharge
- model-channel allocation
- pricing / availability controls when enabled

### Frontend-first execution order under the approved isolation model

#### Layer A: isolated frontend skeleton first

1. Add `shared/api` and `shared/auth` primitives or adapters.
2. Add `apps/user/router/routes.ts` and `apps/admin/router/routes.ts`.
3. Add user/admin API wrappers in their own app partitions.
4. Add `apps/user/stores/account.ts` and `apps/admin/stores/adminCommercial.ts`.
5. Add isolated user/admin views and components.
6. Update root router and root menu assembler to consume those partitions.

#### Layer B: backend contract alignment second

1. Freeze request/response DTOs used by user/admin partitions.
2. Implement backend wallet/billing/admin APIs against those contracts.
3. Replace temporary fallback loading with real API integration.
4. Tighten unauthorized / forbidden / insufficient-balance handling.

### UI consistency constraints

All frontend work in Phase 1 must preserve the current WeKnora visual language and interaction style. User-side and admin-side code are isolated structurally, but they must still feel like one product.

#### Visual consistency rules

- reuse the current color system, spacing rhythm, border radius, shadows, and typography hierarchy
- match the existing card, table, form, dialog, empty-state, and loading-state styles
- prefer reusing existing generic components before creating new visual variants
- if a new component is required, align its spacing, icon style, button style, and feedback states with current WeKnora pages

#### Interaction consistency rules

- keep the existing platform navigation pattern, including left-side menu and main content layout
- keep current feedback behavior for loading, success, warning, error, and empty states
- use the same interaction expectations for dialogs, forms, tables, filters, and pagination
- admin pages may be denser in information, but must not introduce a separate visual system

#### Implementation rules for UI changes

- isolate code structure with `apps/user` and `apps/admin`, but do not fork the design language
- check existing components such as `UserMenu.vue`, `menu.vue`, selector components, dialog components, and list/sidebar patterns before creating new UI
- avoid introducing a new admin dashboard style that looks disconnected from the current product
- if a backend feature is unfinished, hide the entry or use a restrained placeholder state instead of shipping a visually inconsistent temporary page

### Guardrails

- no second frontend project in Phase 1
- no shared business logic between user and admin apps
- no new commercial code under old flat `src/views/account` or `src/views/admin` paths
- no provider/channel details exposed to users
- no `wechat_v1` changes in this stage
- if an admin page is not ready, hide it instead of leaking partial behavior

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

1. Finalize `apps/user + apps/admin + shared` isolation boundaries
2. Add isolated frontend skeleton: shared primitives, user/admin route modules, partitioned stores and pages
3. Freeze frontend-backend contract for wallet, billing, recharge, and admin pages
4. Implement backend schema and domain types against that contract
5. Implement repository and service layer
6. Add chat billing closure and admin APIs
7. Connect real backend data into the isolated user/admin frontend partitions
8. Run control-plane verification

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
