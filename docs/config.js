// Demo configuration for the Offer Concierge chat page.
//
// BROKER_BASE_URL must point at the public Salesforce Site that hosts the
// Apex REST broker. The page calls {BROKER_BASE_URL}/session, /message and
// /resolve.
//
// If the Site URL ever changes (different sandbox / My Domain), update it here.
window.OFFER_DEMO_CONFIG = {
  BROKER_BASE_URL:
    "https://velocity-fun-8615--df2umtl.sandbox.my.salesforce-sites.com/offerdemo/services/apexrest/agentdemo",

  // Cosmetic: the name shown in the chat header.
  AGENT_NAME: "Offer Concierge",
  AGENT_STATUS: "online",
};
