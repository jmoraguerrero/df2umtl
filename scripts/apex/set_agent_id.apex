// Writes the published agent Id into the broker config custom setting.
AgentBrokerConfig__c cfg = AgentBrokerConfig__c.getOrgDefaults();
if (cfg == null || cfg.Id == null) {
    cfg = new AgentBrokerConfig__c(SetupOwnerId = UserInfo.getOrganizationId());
}
cfg.Agent_Id__c = '0XxAs0000005gbJKAQ';
cfg.Instance_Url__c = 'https://velocity-fun-8615--df2umtl.sandbox.my.salesforce.com';
cfg.Named_Credential__c = 'Agent_API';
upsert cfg;
System.debug('Agent config: ' + cfg);
