// End-to-end test of the name-lookup flow (no contactId) against the live agent.
System.debug('=== Starting anonymous session (no contactId) ===');
String sessionId = AgentApiService.startSession('');
System.debug('sessionId = ' + sessionId);

System.debug('=== Kickoff greeting ===');
String reply1 = AgentApiService.sendMessage(sessionId, 'Hi', 1);
System.debug('AGENT REPLY 1 >>> ' + reply1);

System.debug('=== Providing the name ===');
String reply2 = AgentApiService.sendMessage(sessionId, 'My name is Alex Morgan', 2);
System.debug('AGENT REPLY 2 >>> ' + reply2);
