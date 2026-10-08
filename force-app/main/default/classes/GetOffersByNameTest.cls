@IsTest
private class GetOffersByNameTest {

    @TestSetup
    static void setup() {
        Contact c = new Contact(FirstName = 'Alex', LastName = 'Morgan');
        insert c;

        List<Offer__c> offers = new List<Offer__c>{
            new Offer__c(
                Name = 'Unlimited 5G Mobile Plan',
                Contact__c = c.Id,
                Active__c = true,
                Price__c = 55,
                Discount__c = 20,
                Category__c = 'Mobile',
                Description__c = 'Unlimited talk, text, and 5G data.'
            ),
            new Offer__c(
                Name = 'Fibre Internet 1 Gbps',
                Contact__c = c.Id,
                Active__c = true,
                Price__c = 70,
                Discount__c = 15,
                Category__c = 'Internet'
            ),
            new Offer__c(
                Name = 'Expired Plan',
                Contact__c = c.Id,
                Active__c = true,
                Price__c = 10,
                Category__c = 'Mobile',
                ExpirationDate__c = Date.today().addDays(-5)
            )
        };
        insert offers;
    }

    private static GetOffersByName.Response run(String name) {
        GetOffersByName.Request req = new GetOffersByName.Request();
        req.customerName = name;
        return GetOffersByName.getOffers(new List<GetOffersByName.Request>{ req })[0];
    }

    @IsTest
    static void findsContactAndReturnsActiveOffers() {
        Test.startTest();
        GetOffersByName.Response res = run('Alex Morgan');
        Test.stopTest();
        System.assertEquals(true, res.customerFound, 'should find the contact');
        System.assertEquals('Alex Morgan', res.matchedName);
        System.assertEquals(2, res.offerCount, 'expired offer should be excluded');
        System.assert(res.offersSummary.contains('Unlimited 5G Mobile Plan'));
        System.assert(res.contactId != null);
    }

    @IsTest
    static void partialNameMatches() {
        Test.startTest();
        GetOffersByName.Response res = run('Morgan');
        Test.stopTest();
        System.assertEquals(true, res.customerFound);
        System.assertEquals(2, res.offerCount);
    }

    @IsTest
    static void noMatchReturnsNotFound() {
        Test.startTest();
        GetOffersByName.Response res = run('Nobody Here');
        Test.stopTest();
        System.assertEquals(false, res.customerFound);
        System.assertEquals(0, res.offerCount);
        System.assert(res.offersSummary.contains('could not find'));
    }

    @IsTest
    static void blankNameHandled() {
        Test.startTest();
        GetOffersByName.Response res = run('   ');
        Test.stopTest();
        System.assertEquals(false, res.customerFound);
        System.assertEquals(0, res.offerCount);
    }
}
