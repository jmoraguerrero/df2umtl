// Demo configuration for the Offer Concierge chat page.
//
// BROKER_BASE_URL must point at the public Salesforce Site that hosts the
// Apex REST broker. The page calls {BROKER_BASE_URL}/session and /message.
//
// If the Site URL ever changes (different sandbox / My Domain), update it here.
window.OFFER_DEMO_CONFIG = {
  BROKER_BASE_URL:
    "https://velocity-fun-8615--df2umtl.sandbox.my.salesforce-sites.com/offerdemo/services/apexrest/agentdemo",

  // Fallback contact used when the page is opened without a ?contactId= param.
  // Alex Morgan (seeded demo contact).
  DEFAULT_CONTACT_ID: "003As00001B8DVtIAN",

  // Cosmetic: the name shown in the chat header.
  AGENT_NAME: "Offer Concierge",
  AGENT_STATUS: "online",
};
