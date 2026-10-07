// Seeds the org-default AgentBrokerConfig__c custom setting for the demo broker.
// Agent_Id__c is set after the agent is published (from the agent details page URL).
AgentBrokerConfig__c cfg = AgentBrokerConfig__c.getOrgDefaults();
if (cfg == null || cfg.Id == null) {
    cfg = new AgentBrokerConfig__c(SetupOwnerId = UserInfo.getOrganizationId());
}
cfg.Instance_Url__c = 'https://velocity-fun-8615--df2umtl.sandbox.my.salesforce.com';
cfg.Named_Credential__c = 'Agent_API';
upsert cfg;
System.debug('Seeded AgentBrokerConfig__c: ' + cfg);
