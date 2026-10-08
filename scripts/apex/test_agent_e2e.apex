// End-to-end test of the Agent API broker against the live published agent.
String contactId = '003As00001B8DVtIAN'; // Alex Morgan (seeded)
System.debug('=== Starting session ===');
String sessionId = AgentApiService.startSession(contactId);
System.debug('sessionId = ' + sessionId);

System.debug('=== Sending message ===');
String reply = AgentApiService.sendMessage(sessionId, 'Hi! What offers do you have for me?', 1);
System.debug('AGENT REPLY >>> ' + reply);
