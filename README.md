# DF2UMtl - WhatsApp-style Agentforce Offers Demo

A demo where a WhatsApp-style web page (hosted on GitHub Pages) chats with a
Salesforce Agentforce agent. The agent finds personalized offers for the
connected contact and converses with the user.

## Architecture

```
Static page (GitHub Pages)
  -> fetch -> Apex REST broker on a public Salesforce Site (/agentdemo/*)
     -> Named Credential (client credentials token)
        -> Agentforce Agent API
           -> Agent Script subagent
              -> Apex action GetOffersForContact
                 -> Offer__c records
```

- Frontend: static HTML/CSS/JS (no secrets), identifies the user via a
  `contactId` URL parameter.
- Broker: Apex REST exposed on a public Site holds the OAuth credentials and
  calls the Agentforce Agent API.
- Agent: authored in Agent Script (config / access / variables / start_agent /
  subagent), deployed with Agentforce DX.
- Data: custom `Offer__c` records queried per contact.

## Repository layout

- `force-app/` - Salesforce DX source (objects, Apex, agent, site, auth config)
- `docs/` - static WhatsApp-style frontend served by GitHub Pages

## Status

Work in progress. See the project plan for the full build order.
