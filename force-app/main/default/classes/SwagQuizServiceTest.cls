@IsTest
private class SwagQuizServiceTest {

    private static Contact makeContact() {
        Contact c = new Contact(FirstName = 'Quiz', LastName = 'Taker');
        insert c;
        return c;
    }

    private static void seedQuiz() {
        insert new List<Swag_Question__c>{
            new Swag_Question__c(
                Name = 'Q1',
                Question_Text__c = 'How do you spend most of your screen time?',
                Order__c = 1,
                Active__c = true,
                Options__c = '[{"label":"Streaming","score":3},{"label":"Gaming","score":1},{"label":"Work","score":2}]'
            ),
            new Swag_Question__c(
                Name = 'Q2',
                Question_Text__c = 'Pick a vibe',
                Order__c = 2,
                Active__c = true,
                Options__c = '[{"label":"Chill","score":1},{"label":"Adventure","score":3}]'
            ),
            new Swag_Question__c(
                Name = 'Inactive',
                Question_Text__c = 'Should be ignored',
                Order__c = 3,
                Active__c = false,
                Options__c = '[{"label":"Nope","score":9}]'
            )
        };
        insert new List<Swag__c>{
            new Swag__c(Name = 'Sticker Pack', Min_Score__c = 0, Max_Score__c = 3, Active__c = true, Emoji__c = '🎟️', Description__c = 'A fun sticker pack.'),
            new Swag__c(Name = 'Premium Hoodie', Min_Score__c = 4, Max_Score__c = 10, Active__c = true, Emoji__c = '🧥', Description__c = 'A cozy hoodie.')
        };
    }

    @IsTest
    static void fullQuizAwardsHighBand() {
        Contact c = makeContact();
        seedQuiz();

        Test.startTest();
        // Entry status: not completed yet.
        SwagQuizService.Result s = SwagQuizService.status(c.Id);
        System.assertEquals(0, s.alreadyCompleted, 'Should not be completed yet');
        System.assertEquals(c.Id, s.contactIdEcho, 'Should echo contact id');

        // Entry message that does not match an option -> re-asks Q1.
        SwagQuizService.Result r1 = SwagQuizService.answer(c.Id, 'what swag can I win?');
        System.assertEquals(0, r1.done, 'Still in progress');
        System.assert(r1.replyText.contains('screen time'), 'Should ask Q1: ' + r1.replyText);

        // Answer Q1 with highest-score option.
        SwagQuizService.Result r2 = SwagQuizService.answer(c.Id, 'Streaming');
        System.assertEquals(0, r2.done, 'Still one question left');
        System.assert(r2.replyText.contains('vibe'), 'Should ask Q2: ' + r2.replyText);

        // Answer Q2 with highest-score option -> total 6 -> Premium Hoodie band.
        SwagQuizService.Result r3 = SwagQuizService.answer(c.Id, 'Adventure');
        Test.stopTest();

        System.assertEquals(1, r3.done, 'Quiz should be done');
        System.assertEquals('Premium Hoodie', r3.swagName, 'Score 6 should win the hoodie');

        Swag_Response__c resp = [SELECT Completed__c, Total_Score__c, Assigned_Swag__r.Name, Answers__c FROM Swag_Response__c WHERE Contact__c = :c.Id];
        System.assertEquals(true, resp.Completed__c, 'Should be completed');
        System.assertEquals(6, resp.Total_Score__c, 'Total should be 6');
        System.assertEquals('Premium Hoodie', resp.Assigned_Swag__r.Name, 'Assigned swag persisted');
    }

    @IsTest
    static void lowScoreAwardsLowBand() {
        Contact c = makeContact();
        seedQuiz();

        SwagQuizService.answer(c.Id, 'start'); // Q1 (no match -> re-ask)
        SwagQuizService.answer(c.Id, 'Gaming');  // score 1
        SwagQuizService.Result r = SwagQuizService.answer(c.Id, 'Chill'); // score 1 -> total 2

        System.assertEquals(1, r.done, 'Done');
        System.assertEquals('Sticker Pack', r.swagName, 'Score 2 should win sticker pack');
    }

    @IsTest
    static void numericSelectionWorks() {
        Contact c = makeContact();
        seedQuiz();

        SwagQuizService.answer(c.Id, 'begin'); // re-ask Q1
        SwagQuizService.answer(c.Id, '1');       // option 1 of Q1 = Streaming (3)
        SwagQuizService.Result r = SwagQuizService.answer(c.Id, '2'); // option 2 of Q2 = Adventure (3) -> 6

        System.assertEquals('Premium Hoodie', r.swagName, 'Numeric selection should map to options');
    }

    @IsTest
    static void alreadyCompletedShowsPriorResultNoRetake() {
        Contact c = makeContact();
        seedQuiz();
        SwagQuizService.answer(c.Id, 'x');
        SwagQuizService.answer(c.Id, 'Streaming');
        SwagQuizService.answer(c.Id, 'Adventure'); // completes

        Test.startTest();
        SwagQuizService.Result s = SwagQuizService.status(c.Id);
        SwagQuizService.Result a = SwagQuizService.answer(c.Id, 'Gaming'); // attempt retake
        Test.stopTest();

        System.assertEquals(1, s.alreadyCompleted, 'Status should report already completed');
        System.assert(s.resultText.contains('Premium Hoodie'), 'Status should include prior swag');
        System.assertEquals(1, a.alreadyCompleted, 'Answer should refuse retake');
        System.assertEquals(1, a.done, 'Answer should report done');
        System.assert(a.replyText.contains('Premium Hoodie'), 'Answer should show prior swag');

        Integer count = [SELECT COUNT() FROM Swag_Response__c WHERE Contact__c = :c.Id];
        System.assertEquals(1, count, 'Only one response record per contact');
    }

    @IsTest
    static void blankContactIsHandled() {
        SwagQuizService.Result s = SwagQuizService.status('');
        System.assertEquals(0, s.alreadyCompleted, 'No completion for blank');
        System.assert(s.replyText.contains('identify'), 'Should explain it cannot identify');

        SwagQuizService.Result a = SwagQuizService.answer('not-an-id', 'Streaming');
        System.assert(a.replyText.contains('identify'), 'Should explain it cannot identify');
    }

    @IsTest
    static void noQuestionsIsHandled() {
        Contact c = makeContact();
        // No questions seeded.
        SwagQuizService.Result a = SwagQuizService.answer(c.Id, 'Streaming');
        System.assertEquals(0, a.done, 'Not done');
        System.assert(a.replyText.contains('isn\'t available'), 'Should explain quiz unavailable: ' + a.replyText);
    }

    @IsTest
    static void invocableWrappers() {
        Contact c = makeContact();
        seedQuiz();

        SwagQuizBegin.Request br = new SwagQuizBegin.Request();
        br.contactId = c.Id;
        List<SwagQuizBegin.Response> bres = SwagQuizBegin.begin(new List<SwagQuizBegin.Request>{ br });
        System.assertEquals(c.Id, bres[0].contactIdEcho, 'Begin echoes contact id');
        System.assertEquals(0, bres[0].alreadyCompleted, 'Not completed');

        SwagQuizAnswer.Request ar = new SwagQuizAnswer.Request();
        ar.contactId = c.Id;
        ar.userMessage = 'Streaming';
        List<SwagQuizAnswer.Response> ares = SwagQuizAnswer.record(new List<SwagQuizAnswer.Request>{ ar });
        System.assertEquals(0, ares[0].done, 'One question left');
        System.assert(ares[0].replyText.contains('vibe'), 'Should move to Q2');
        System.assertEquals(2, ares[0].totalQuestions, 'Two active questions');
        System.assertEquals(2, ares[0].questionNumber, 'Now on question 2');
    }
}
