@IsTest
private class AgentDemoResourceTest {

    private static void setConfig() {
        AgentApiService.testConfig = new AgentBrokerConfig__c(
            Agent_Id__c = '0XxAx0000000001',
            Instance_Url__c = 'https://example.my.salesforce.com',
            Named_Credential__c = 'Agent_API'
        );
    }

    private class SessionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"sessionId":"sess-abc"}');
            return res;
        }
    }

    private class MessageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"messages":[{"type":"Inform","message":"Hello from the agent"}]}');
            return res;
        }
    }

    private static void buildRequest(String uri, String body) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'POST';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void sessionEndpointReturnsSessionId() {
        setConfig();
        Test.setMock(HttpCalloutMock.class, new SessionMock());
        buildRequest('/services/apexrest/agentdemo/session', '{"contactId":"003000000000001"}');
        Test.startTest();
        AgentDemoResource.handlePost();
        Test.stopTest();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('sess-abc'));
    }

    @IsTest
    static void messageEndpointReturnsReply() {
        setConfig();
        Test.setMock(HttpCalloutMock.class, new MessageMock());
        buildRequest('/services/apexrest/agentdemo/message', '{"sessionId":"sess-abc","message":"hi","sequenceId":2}');
        Test.startTest();
        AgentDemoResource.handlePost();
        Test.stopTest();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Hello from the agent'));
    }

    @IsTest
    static void unknownActionReturns404() {
        setConfig();
        buildRequest('/services/apexrest/agentdemo/bogus', '{}');
        Test.startTest();
        AgentDemoResource.handlePost();
        Test.stopTest();
        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void errorIsReturnedAs500() {
        AgentApiService.testConfig = new AgentBrokerConfig__c(Agent_Id__c = '', Named_Credential__c = 'Agent_API');
        buildRequest('/services/apexrest/agentdemo/session', '{"contactId":"003000000000001"}');
        Test.startTest();
        AgentDemoResource.handlePost();
        Test.stopTest();
        System.assertEquals(500, RestContext.response.statusCode);
    }
}
