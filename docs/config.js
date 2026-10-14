// Demo configuration for the Offer Concierge chat page.
//
// BROKER_BASE_URL must point at the public Salesforce Site that hosts the
// Apex REST broker. The page calls {BROKER_BASE_URL}/session, /message and
// /resolve.
window.OFFER_DEMO_CONFIG = {
  BROKER_BASE_URL:
    "https://de1780924127103.my.salesforce-sites.com/offerdemo/services/apexrest/agentdemo",

  AGENT_NAME: "Offer Concierge",
  AGENT_SUBTITLE: "Prize draw entry",
  AGENT_STATUS: "online",

  // Goal chips only at session start; labels must match OfferConcierge.agent goal mapping.
  GIVEAWAY_FLOW: {
    goals: [
      { label: "Buy a home" },
      { label: "Save and invest" },
      { label: "Pay down debt" },
      { label: "Plan for retirement" },
      { label: "Something else" },
    ],
  },
};
