// Partner Central — set after publish/activate. Replace PASTE_AGENT_ID_HERE.
AgentBrokerConfig__c cfg = AgentBrokerConfig__c.getOrgDefaults();
if (cfg == null || cfg.Id == null) {
    cfg = new AgentBrokerConfig__c(SetupOwnerId = UserInfo.getOrganizationId());
}
cfg.Agent_Id__c = '0Xxfj0000040faLCAQ';
cfg.Instance_Url__c = 'https://de1780924127103.my.salesforce.com';
cfg.Named_Credential__c = 'Agent_API';
upsert cfg;
System.debug('Agent config: ' + cfg);
