# Agent Spec: Offer Concierge

## Purpose & Scope
A customer-facing chat agent for the WhatsApp-style demo page. It greets the
connected customer, finds the personalized offers targeted to them, presents
those offers conversationally, and answers follow-up questions about the offers
(price, discount, what's included, expiry). It stays on the topic of offers.

## Behavioral Intent
- Open with a short, friendly WhatsApp-style greeting.
- Use the connected customer's identity (passed in as `Contact_Id`) to look up
  their offers via the `GetOffersForContact` Apex action.
- Present offers using the exact values returned (name, price, discount,
  description) - no paraphrasing of numbers.
- If there are no offers, say so politely and offer to help another way.
- Keep answers concise and chat-friendly (short paragraphs, no walls of text).
- Redirect off-topic requests back to offers; ask for clarification when unsure.

## Configuration
- Agent type: `AgentforceServiceAgent`
- Default agent user: NEW Einstein Agent User to be created (license available:
  "Einstein Agent", 801 free). Pending user approval.
- Permissions: the agent user must get the `Offer_Demo_Access` permission set so
  the action can read `Offer__c`.

## Variables
| Name | Type | Default | Set by | Read by | Purpose |
|------|------|---------|--------|---------|---------|
| `Contact_Id` | string | "" | Agent API (session/message `variables`) | `offer_discovery` | Identifies the connected customer so offers can be looked up |

## Subagent Map
```mermaid
flowchart TD
  router["start_agent: agent_router<br/>greet + route"]
  discovery["subagent: offer_discovery<br/>find + present offers"]
  offtopic["subagent: off_topic<br/>redirect to offers"]
  ambiguous["subagent: ambiguous_question<br/>ask to clarify"]

  router -->|handoff| discovery
  router -->|handoff| offtopic
  router -->|handoff| ambiguous
  discovery -->|handoff| offtopic
  discovery -->|handoff| ambiguous
```

Pattern: Hub-and-Spoke. `agent_router` is the entry point and routes to the
single domain subagent (`offer_discovery`) plus the two standard guardrails.

## Actions & Backing Logic
### get_offers (in `offer_discovery`)
- Backing: Apex class `GetOffersForContact` (invocable) - EXISTS
- Target: `apex://GetOffersForContact`
- Inputs:
  - `contactId` (string, required) - bound to `@variables.Contact_Id`
- Outputs:
  - `offersSummary` (string) - Visible to user (the readable list to present)
  - `offerCount` (integer) - Hidden (used only for internal reasoning)
- Note: the Apex also returns a structured `offers` list, but the demo agent
  presents `offersSummary` for reliable grounding, so the complex list is not
  wired into the action I/O.

## Gating Logic
No deterministic gating required. `Contact_Id` is supplied by the trusted broker
(the Apex-on-a-Site layer), not by the end user, so no identity gate is needed in
the agent itself. Loop prevention on `get_offers` is handled with explicit
post-action instructions (do not re-call once results are returned).

## Guardrails
- `off_topic`: politely redirect to offers.
- `ambiguous_question`: ask for a clarifying detail.
