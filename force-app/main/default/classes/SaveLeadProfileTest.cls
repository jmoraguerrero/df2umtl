@IsTest
private class SaveLeadProfileTest {

    @IsTest
    static void rejectsWithoutConfirmation() {
        SaveLeadProfile.Request req = new SaveLeadProfile.Request();
        req.firstName = 'Pat';
        req.lastName = 'Lee';
        req.email = 'pat.lee@example.com';
        req.confirmed = false;

        SaveLeadProfile.Response res = SaveLeadProfile.save(new List<SaveLeadProfile.Request>{ req })[0];
        System.assertEquals(false, res.success, 'Must not save without confirm');
    }

    @IsTest
    static void createsLeadWhenConfirmed() {
        SaveLeadProfile.Request req = new SaveLeadProfile.Request();
        req.firstName = 'Jordan';
        req.lastName = 'River';
        req.email = 'jordan.river@example.com';
        req.phone = '5145550199';
        req.confirmed = true;

        Test.startTest();
        SaveLeadProfile.Response res = SaveLeadProfile.save(new List<SaveLeadProfile.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertNotEquals(null, res.leadId);
        Lead l = [SELECT FirstName, LastName, Email, Phone, Company FROM Lead WHERE Id = :res.leadId];
        System.assertEquals('Jordan', l.FirstName);
        System.assertEquals('River', l.LastName);
        System.assertEquals('jordan.river@example.com', l.Email);
    }

    @IsTest
    static void parsesFullName() {
        SaveLeadProfile.NameParts parts = SaveLeadProfile.resolveNames(null, null, 'Alex Morgan');
        System.assertEquals('Alex', parts.firstName);
        System.assertEquals('Morgan', parts.lastName);
    }
}
