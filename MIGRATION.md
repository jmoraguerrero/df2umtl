# Migrating the Offer Concierge demo to another Salesforce org

Use this when moving **all** demo functionality from one org (e.g. `df2umtl`) to a new sandbox or production org.

## Summary

| Layer | In git? | Deploy alone enough? |
|--------|---------|----------------------|
| Custom objects, Apex, Site, permission sets | Yes (`force-app/main/default`) | Yes (with tests) |
| Agent Script + publish | Yes (`aiAuthoringBundles/.../OfferConcierge.agent`) | **No** — must **publish + activate** after deploy |
| ECA / External Credential / Named Credential | Yes (retrieved; see below) | **Partial** — URLs and secrets are **org-specific** |
| Org defaults (`AgentBrokerConfig__c`) | Schema only | **No** — set **Agent Id** and **Instance URL** per org |
| Demo data (offers, swag, contacts) | Scripts only (`scripts/apex/`) | **No** — run seed scripts |
| Static chat UI | `docs/` (GitHub Pages) | Update `docs/config.js` broker URL |

---

## 1. Metadata to deploy

Point the CLI at the target org, then deploy the full default package:

```powershell
sf config set target-org <new-org-alias>
sf project deploy start --source-dir force-app/main/default --test-level RunLocalTests
```

### Apex (broker + agent actions + tests)

- `AgentApiService`, `AgentDemoResource`
- `GetOffersForCustomer`, `GetOffersForContact`, `GetOffersByName`, `OfferPresentationUtil`
- `SaveLeadProfile`
- `SwagQuizService`, `SwagQuizAnswer`, `SwagQuizBegin`
- All matching `*Test.cls` classes

### Data model

- `AgentBrokerConfig__c` (custom setting: `Agent_Id__c`, `Instance_Url__c`, `Named_Credential__c`)
- `Offer__c` (including `Contact__c`, `Lead__c`)
- `Swag__c`, `Swag_Question__c`, `Swag_Response__c` (including `Lead__c`)

### Agent

- `aiAuthoringBundles/OfferConcierge/OfferConcierge.agent` (source of truth)
- `aiAuthoringBundles/OfferConcierge/OfferConcierge.bundle-meta.xml`
- Optional: `aiAgents/`, `aiAgentDefinitionVersions/` (usually **not required** if you publish from the bundle)

### Site & broker

- `sites/OfferDemo.site-meta.xml` (`urlPathPrefix`: `offerdemo`)
- `pages/OfferDemoHome.page`
- `profiles/OfferDemo Profile.profile-meta.xml` (guest profile for the Site)

### Security

- `permissionsets/Offer_Demo_Access` — assign to **Einstein Agent User**
- `permissionsets/Agent_Broker_Access` — assign to **Site Guest User** (and any user that must use the named credential principal)

### Other

- `tabs/Offer__c.tab-meta.xml`
- `corsWhitelistOrigins/github_pages.corsWhitelistOrigin-meta.xml` (change URL if your static host is not `https://jmoraguerrero.github.io`)

### Agent API authentication (now in repo)

These were retrieved from the source org and should deploy **by name**, but must be **reconfigured** in the target org:

| Metadata | API name | Purpose |
|----------|----------|---------|
| External Client App | `DF2U_ECA` | OAuth client for Agent API callouts |
| ECA OAuth settings | `DF2U_ECA_oauth`, `DF2U_ECA_glbloauth` | Scopes, client credentials flow |
| External Credential | `DF2U_EC` | Client credentials → token URL |
| Named Credential | `Agent_API` | Callout base `https://api.salesforce.com` + auth |

Paths:

- `force-app/main/default/externalClientApps/DF2U_ECA.eca-meta.xml`
- `force-app/main/default/extlClntAppOauthSettings/DF2U_ECA_oauth.ecaOauth-meta.xml`
- `force-app/main/default/extlClntAppGlobalOauthSets/DF2U_ECA_glbloauth.ecaGlblOauth-meta.xml`
- `force-app/main/default/externalCredentials/DF2U_EC.externalCredential-meta.xml`
- `force-app/main/default/namedCredentials/Agent_API.namedCredential-meta.xml`

**Important:** Retrieved ECA metadata can contain **org-scoped IDs** (`orgScopedExternalApp`, `oauthLink`) and **consumer keys**. After deploy to a **new** org, open **Setup → External Client Apps** and **External Credentials** and confirm:

1. **Client credentials** flow is enabled on the ECA.
2. **External Credential `DF2U_EC`** → principal **`AgentApiPrincipal`**: link to the ECA consumer key/secret (or re-enter credentials).
3. **`AuthProviderUrl`** on `DF2U_EC` points at the **target org** token endpoint, e.g.  
   `https://<my-domain>.my.salesforce.com/services/oauth2/token`  
   (not the old sandbox URL).
4. Named Credential **`Agent_API`** remains enabled and references `DF2U_EC`.

`Agent_Broker_Access` expects principal: **`DF2U_EC-AgentApiPrincipal`**.

---

## 2. After metadata deploy (required manual steps)

### A. Einstein Agent user

1. Create an **Einstein Agent** user in the target org (see `data-import/User.json` as a template; **ProfileId and username must match the new org**).
2. Update `OfferConcierge.agent` / published agent **`default_agent_user`** / `botUser` to that username if it still references the old org domain.
3. Assign permission set **`Offer_Demo_Access`** to the agent user.

### B. Publish and activate the agent

Deploying the `.agent` file is not enough for runtime:

```powershell
sf agent publish authoring-bundle --api-name OfferConcierge --target-org <new-org-alias>
sf agent activate --api-name OfferConcierge --target-org <new-org-alias>
```

Use **`sf data query`** on `BotVersion` if you need a specific version number.

### C. Broker custom setting

Set org-default **`AgentBrokerConfig__c`** (Custom Settings → Agent Demo Config, or run a script):

| Field | Value |
|-------|--------|
| `Named_Credential__c` | `Agent_API` |
| `Instance_Url__c` | Target org My Domain URL (no trailing path), e.g. `https://<domain>.my.salesforce.com` |
| `Agent_Id__c` | Published agent Id from Agentforce (URL or setup), e.g. `0Xx...` |

Templates: `scripts/apex/seed_broker_config.apex`, `scripts/apex/set_agent_id.apex` (edit URLs/Ids before running).

### D. Site guest access

1. Enable the **OfferDemo** site and map a **Site domain** (subdomain/path `offerdemo`).
2. Assign **`Agent_Broker_Access`** to the **OfferDemo Site Guest User** profile.
3. Ensure guest can access **`AgentDemoResource`** REST (`/services/apexrest/agentdemo/*`).

Discover public broker URL:

```powershell
sf apex run --file scripts/apex/get_site_url.apex
```

Update **`docs/config.js`** → `BROKER_BASE_URL` to:

`https://<site-domain>/offerdemo/services/apexrest/agentdemo`

### E. Demo data (optional but typical)

Run in target org (edit Ids/emails as needed):

| Script | Purpose |
|--------|---------|
| `scripts/apex/seed_offers.apex` | Sample offers on contacts |
| `scripts/apex/seed_swag.apex` | Quiz questions and swag tiers |
| `scripts/apex/seed_lead_offers.apex` | Sample lead + offers for anonymous intake |
| `scripts/apex/seed_broker_config.apex` | Instance URL + named credential name |

### F. Smoke tests

| Script | Checks |
|--------|--------|
| `scripts/apex/test_anonymous_agent.apex` | Session without `Contact_Id` → intake greeting |
| `scripts/apex/test_agent_offers.apex` | Session with contact → offers |
| `scripts/apex/test_agent_swag.apex` | Swag quiz path |

---

## 3. Retrieve auth from source org (optional)

If you prefer refreshing auth metadata from an existing org before migrating:

```powershell
sf config set target-org <source-org-alias>
sf project retrieve start --metadata ^
  "ExternalClientApplication:DF2U_ECA" ^
  "ExtlClntAppOauthSettings:DF2U_ECA_oauth" ^
  "ExtlClntAppGlobalOauthSettings:DF2U_ECA_glbloauth" ^
  "ExternalCredential:DF2U_EC" ^
  "NamedCredential:Agent_API"
```

Then deploy to the target org and complete **section 2** ECA / external credential setup there.

---

## 4. What does *not* migrate via metadata

- **Consumer secrets** (store securely; re-link in External Credential in each org).
- **Agent Id** (`AgentBrokerConfig__c.Agent_Id__c`) — new Id after each publish.
- **Contact/Lead record Ids** used in URLs (`?contactId=`) — recreate or re-seed.
- **Active agent version** — always **activate** after publish in the target org.
- **GitHub Pages** host — only `docs/config.js` URL change unless you redeploy Pages from the same repo.

---

## 5. Minimal command sequence (checklist)

1. `sf config set target-org <new>`
2. `sf project deploy start --source-dir force-app/main/default --test-level RunLocalTests`
3. Configure **ECA / External Credential / Named Credential** in Setup (token URL + principal secrets).
4. Create agent user → assign **Offer_Demo_Access**
5. Assign **Agent_Broker_Access** to Site guest profile
6. `sf agent publish authoring-bundle --api-name OfferConcierge`
7. `sf agent activate --api-name OfferConcierge`
8. Set **AgentBrokerConfig__c** (Agent Id + Instance URL)
9. Enable Site → update **docs/config.js**
10. Run seed + test scripts
