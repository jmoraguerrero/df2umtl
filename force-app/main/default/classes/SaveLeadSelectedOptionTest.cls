@IsTest
private class SaveLeadSelectedOptionTest {

    @IsTest
    static void updatesSelectedOptionWhenFieldExists() {
        if (!SaveLeadSelectedOption.leadHasField('Selected_Option__c')) {
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
        Lead updated = [
            SELECT Selected_Option__c
            FROM Lead
            WHERE Id = :l.Id
        ];
        System.assertEquals('Business Credit Card', updated.Selected_Option__c);
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
