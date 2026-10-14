# Org-specific Offer Concierge config

The **canonical** Agent Script in git is under `force-app/.../OfferConcierge.agent` and targets the **df2umtl** sandbox agent user. Each org has a **local overlay** here so publish/activate does not overwrite the other environment.

## Layout

| Path | Purpose |
|------|---------|
| `df2umtl/OfferConcierge.agent` | Same script as force-app; user = `offerconcierge.agent@df2umtl.velocityfun.demo` |
| `partnercentral/OfferConcierge.agent` | Same script; **`default_agent_user`** = `offerconcierge@00dfj00000ryet71173413824.ext` (same as committed v1 **Agent Access**) |
| `*/create_agent_user.apex` | Create Einstein agent user + `Offer_Demo_Access` in that org |
| `*/set_agent_id.apex` | Org-default `AgentBrokerConfig__c` after publish |
| `*/org.env.json` | Instance URL, broker URL, agent user (reference only) |

## Before publish (pick one org)

**Partner Central:**

```powershell
Copy-Item org-config/partnercentral/OfferConcierge.agent `
  force-app/main/default/aiAuthoringBundles/OfferConcierge/OfferConcierge.agent -Force
sf config set target-org partnercentral
sf agent publish authoring-bundle --api-name OfferConcierge
sf agent activate --api-name OfferConcierge
sf apex run --file org-config/partnercentral/set_agent_id.apex
```

**DF2U MTL (restore default):**

```powershell
Copy-Item org-config/df2umtl/OfferConcierge.agent `
  force-app/main/default/aiAuthoringBundles/OfferConcierge/OfferConcierge.agent -Force
sf config set target-org df2umtl
sf agent publish authoring-bundle --api-name OfferConcierge
sf agent activate --api-name OfferConcierge
sf apex run --file org-config/df2umtl/set_agent_id.apex
```

After editing shared script logic, update **both** `org-config/*/OfferConcierge.agent` copies (or re-copy from force-app and fix only the `default_agent_user` line).

## Agent user

Run once per org:

```powershell
sf apex run --target-org partnercentral --file org-config/partnercentral/create_agent_user.apex
sf apex run --target-org df2umtl --file org-config/df2umtl/create_agent_user.apex
```

Committed agent user (v1 Agent Access): `005fj00000QDTDJAA5` (`offerconcierge@00dfj00000ryet71173413824.ext`). Use this username in `default_agent_user` before **Commit Version**. Alternate manual user: `offerconcierge.agent@00dfj00000ryet7ead.org.force.com`.
