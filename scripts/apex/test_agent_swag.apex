// End-to-end test of the conversational swag quiz via the Agent API.
// Flow: get offer -> enter quiz -> answer 3 questions -> receive swag -> attempt retake.
String contactId = '003As00001B8DVtIAN'; // Alex Morgan
// Note: reset the quiz separately (reset_swag_response.apex) before running - callouts
// can't follow uncommitted DML in the same transaction.

String sessionId = AgentApiService.startSession(contactId);
System.debug('sessionId = ' + sessionId);
String[] msgs = new String[]{ 'Hi! What offers do you have for me?', 'What swag could I win?', 'Streaming & movies', 'Outdoor adventure', 'Giant smart TV', 'Can I play the quiz again?' };
String[] tags = new String[]{ 'OFFER', 'ENTER QUIZ', 'ANSWER 1', 'ANSWER 2', 'ANSWER 3', 'RETAKE?' };
for (Integer i = 0; i < msgs.size(); i++) {
    String reply;
    try {
        reply = AgentApiService.sendMessage(sessionId, msgs[i], i + 1);
    } catch (Exception e) {
        reply = 'EXCEPTION: ' + e.getMessage();
    }
    System.debug('REPLY ' + tags[i] + ' >>> ' + (reply == null ? 'NULL' : reply.replace('\n', ' / ')));
}

List<Swag_Response__c> resps = [SELECT Completed__c, Total_Score__c, Assigned_Swag__r.Name, Answers__c FROM Swag_Response__c WHERE Contact__c = :contactId LIMIT 1];
if (resps.isEmpty()) {
    System.debug('DB RESULT >>> NO Swag_Response__c record was created!');
} else {
    Swag_Response__c resp = resps[0];
    System.debug('DB RESULT >>> completed=' + resp.Completed__c + ' score=' + resp.Total_Score__c + ' swag=' + resp.Assigned_Swag__r.Name);
    System.debug('DB ANSWERS >>> ' + resp.Answers__c);
}
