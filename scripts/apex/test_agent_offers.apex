// Test the ranked-offer presentation: top offer first, then "show me more".
String contactId = '003As00001B8DVtIAN'; // Alex Morgan
String sessionId = AgentApiService.startSession(contactId);
System.debug('sessionId = ' + sessionId);
System.debug('REPLY 1 (greeting) >>>\n' + AgentApiService.sendMessage(sessionId, 'Hi! What offers do you have for me?', 1));
System.debug('REPLY 2 (more)     >>>\n' + AgentApiService.sendMessage(sessionId, 'Show me more', 2));
