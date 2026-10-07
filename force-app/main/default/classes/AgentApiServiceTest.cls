@IsTest
private class AgentApiServiceTest {

    private static AgentBrokerConfig__c buildConfig() {
        return new AgentBrokerConfig__c(
            Agent_Id__c = '0XxAx0000000001',
            Instance_Url__c = 'https://example.my.salesforce.com',
            Named_Credential__c = 'Agent_API'
        );
    }

    private class StartSessionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/agents/'), 'should hit agents endpoint');
            System.assert(req.getEndpoint().contains('/sessions'), 'should hit sessions endpoint');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"sessionId":"sess-123","messages":[]}');
            return res;
        }
    }

    private class SendMessageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/sessions/sess-123/messages'), 'should hit messages endpoint');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"messages":[{"type":"Inform","message":"Here are your offers."},{"type":"Inform","message":"Enjoy!"}]}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"bad request"}');
            return res;
        }
    }

    @IsTest
    static void startSessionReturnsSessionId() {
        AgentApiService.testConfig = buildConfig();
        Test.setMock(HttpCalloutMock.class, new StartSessionMock());
        Test.startTest();
        String sid = AgentApiService.startSession('003000000000001');
        Test.stopTest();
        System.assertEquals('sess-123', sid);
    }

    @IsTest
    static void startSessionWithoutContactStillWorks() {
        AgentApiService.testConfig = buildConfig();
        Test.setMock(HttpCalloutMock.class, new StartSessionMock());
        Test.startTest();
        String sid = AgentApiService.startSession(null);
        Test.stopTest();
        System.assertEquals('sess-123', sid);
    }

    @IsTest
    static void sendMessageJoinsReplies() {
        AgentApiService.testConfig = buildConfig();
        Test.setMock(HttpCalloutMock.class, new SendMessageMock());
        Test.startTest();
        String reply = AgentApiService.sendMessage('sess-123', 'show me offers', 2);
        Test.stopTest();
        System.assert(reply.contains('Here are your offers.'), 'reply should contain first message');
        System.assert(reply.contains('Enjoy!'), 'reply should contain second message');
    }

    @IsTest
    static void errorStatusThrows() {
        AgentApiService.testConfig = buildConfig();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        try {
            AgentApiService.startSession('003000000000001');
            System.assert(false, 'expected an exception');
        } catch (AgentApiService.AgentApiException e) {
            System.assert(e.getMessage().contains('400'), 'should surface status code');
        }
        Test.stopTest();
    }

    @IsTest
    static void missingAgentIdThrows() {
        AgentApiService.testConfig = new AgentBrokerConfig__c(
            Agent_Id__c = '',
            Named_Credential__c = 'Agent_API'
        );
        Test.startTest();
        try {
            AgentApiService.startSession('003000000000001');
            System.assert(false, 'expected an exception');
        } catch (AgentApiService.AgentApiException e) {
            System.assert(e.getMessage().contains('Agent_Id__c'), 'should complain about missing agent id');
        }
        Test.stopTest();
    }

    @IsTest
    static void extractReplyHandlesNoMessages() {
        System.assertEquals('', AgentApiService.extractReply('{"foo":"bar"}'));
    }
}
