/**
 * Thin wrapper around the Salesforce Agentforce Agent API.
 *
 * All callouts go through a Named Credential (client credentials flow) so no
 * secrets ever live in code or in the static front-end. Configuration (agent
 * Id, instance URL, Named Credential name) is read from the AgentBrokerConfig__c
 * org-default custom setting so it can be changed without a redeploy.
 */
public with sharing class AgentApiService {

    private static final String API_BASE = '/einstein/ai-agent/v1';

    public class AgentApiException extends Exception {}

    @TestVisible
    private static AgentBrokerConfig__c testConfig;

    private static AgentBrokerConfig__c config() {
        AgentBrokerConfig__c c = (testConfig != null)
            ? testConfig
            : AgentBrokerConfig__c.getOrgDefaults();
        if (c == null || String.isBlank(c.Agent_Id__c)) {
            throw new AgentApiException('AgentBrokerConfig__c.Agent_Id__c is not set. Publish the agent and set its Id in the Agent Demo Config custom setting.');
        }
        if (String.isBlank(c.Named_Credential__c)) {
            throw new AgentApiException('AgentBrokerConfig__c.Named_Credential__c is not set.');
        }
        return c;
    }

    /**
     * Starts an Agent API session for the given contact and returns the session Id.
     */
    public static String startSession(String contactId) {
        AgentBrokerConfig__c c = config();

        Map<String, Object> body = new Map<String, Object>{
            'externalSessionKey' => generateUuid(),
            'instanceConfig' => new Map<String, Object>{ 'endpoint' => c.Instance_Url__c },
            'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{ 'Text' } },
            'bypassUser' => true
        };
        if (String.isNotBlank(contactId)) {
            body.put('variables', new List<Object>{
                new Map<String, Object>{ 'name' => 'Contact_Id', 'type' => 'Text', 'value' => contactId }
            });
        }

        HttpResponse res = doPost(
            'callout:' + c.Named_Credential__c + API_BASE + '/agents/' + c.Agent_Id__c + '/sessions',
            JSON.serialize(body)
        );

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object sessionId = parsed.get('sessionId');
        if (sessionId == null) {
            throw new AgentApiException('Agent API did not return a sessionId. Raw: ' + res.getBody());
        }
        return String.valueOf(sessionId);
    }

    /**
     * Sends a user message to an existing session and returns the agent's reply text.
     */
    public static String sendMessage(String sessionId, String text, Integer sequenceId) {
        AgentBrokerConfig__c c = config();
        if (String.isBlank(sessionId)) {
            throw new AgentApiException('sessionId is required.');
        }

        Map<String, Object> message = new Map<String, Object>{
            'sequenceId' => (sequenceId == null ? 1 : sequenceId),
            'type' => 'Text',
            'text' => text
        };
        Map<String, Object> body = new Map<String, Object>{ 'message' => message };

        HttpResponse res = doPost(
            'callout:' + c.Named_Credential__c + API_BASE + '/sessions/' + sessionId + '/messages',
            JSON.serialize(body)
        );

        return extractReply(res.getBody());
    }

    /**
     * Pulls the human-readable reply out of the Agent API messages payload.
     */
    @TestVisible
    private static String extractReply(String rawBody) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
        Object messagesObj = parsed.get('messages');
        if (!(messagesObj instanceof List<Object>)) {
            return '';
        }
        List<String> parts = new List<String>();
        for (Object m : (List<Object>) messagesObj) {
            Map<String, Object> msg = (Map<String, Object>) m;
            Object textVal = msg.get('message');
            if (textVal != null && String.isNotBlank(String.valueOf(textVal))) {
                parts.add(String.valueOf(textVal));
            }
        }
        return String.join(parts, '\n\n');
    }

    private static HttpResponse doPost(String endpoint, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        req.setBody(body);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AgentApiException(
                'Agent API error ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }
        return res;
    }

    private static String generateUuid() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0, 8) + '-' + h.substring(8, 12) + '-' + h.substring(12, 16)
            + '-' + h.substring(16, 20) + '-' + h.substring(20, 32);
    }
}
