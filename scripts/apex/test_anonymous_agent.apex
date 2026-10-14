String sessionId = AgentApiService.startSession(null);
System.debug('session=' + sessionId);
String reply = AgentApiService.sendMessage(sessionId, 'Hello', 1);
System.debug('REPLY >>> ' + reply);
