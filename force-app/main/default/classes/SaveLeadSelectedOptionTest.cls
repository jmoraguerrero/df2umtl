@IsTest
private class SaveLeadSelectedOptionTest {

    @IsTest
    static void updatesSelectedOptionWhenFieldExists() {
        String fieldName = SaveLeadSelectedOption.selectedOptionField();
        if (!SaveLeadSelectedOption.leadHasField(fieldName)) {
            return;
        }

        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Picker',
            Email = 'picker@example.com',
            Company = 'Web Chat'
        );
        insert l;

        SaveLeadSelectedOption.Request req = new SaveLeadSelectedOption.Request();
        req.leadId = l.Id;
        req.selectedOption = 'Business Credit Card';

        SaveLeadSelectedOption.Response res = SaveLeadSelectedOption.save(
            new List<SaveLeadSelectedOption.Request>{ req }
        )[0];

        System.assertEquals(true, res.success, res.message);
        Id leadId = l.Id;
        Lead updated = Database.query(
            'SELECT Id, ' + fieldName + ' FROM Lead WHERE Id = :leadId LIMIT 1'
        );
        System.assertEquals('Business Credit Card', (String) updated.get(fieldName));
    }

    @IsTest
    static void rejectsInvalidLeadId() {
        SaveLeadSelectedOption.Request req = new SaveLeadSelectedOption.Request();
        req.leadId = 'not-an-id';
        req.selectedOption = 'Newcomer Credit Card';

        SaveLeadSelectedOption.Response res = SaveLeadSelectedOption.save(
            new List<SaveLeadSelectedOption.Request>{ req }
        )[0];
        System.assertEquals(false, res.success);
    }
}
