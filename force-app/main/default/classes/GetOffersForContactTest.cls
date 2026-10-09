@IsTest
private class GetOffersForContactTest {
    private static Contact makeContact() {
        Contact c = new Contact(FirstName = 'Test', LastName = 'Customer');
        insert c;
        return c;
    }

    private static Offer__c makeOffer(Id contactId, String name, String category, Decimal price, Decimal discount, Boolean active, Date expiration) {
        return new Offer__c(
            Name = name,
            Description__c = name + ' description',
            Category__c = category,
            Price__c = price,
            Discount__c = discount,
            Active__c = active,
            ExpirationDate__c = expiration,
            Contact__c = contactId
        );
    }

    @IsTest
    static void returnsActiveNonExpiredOffers() {
        Contact c = makeContact();
        insert new List<Offer__c>{
            makeOffer(c.Id, 'Active A', 'Mobile', 55, 20, true, Date.today().addDays(10)),
            makeOffer(c.Id, 'Active B', 'Internet', 70, 10, true, null),
            makeOffer(c.Id, 'Inactive', 'TV', 45, 5, false, Date.today().addDays(10)),
            makeOffer(c.Id, 'Expired', 'Roaming', 12, 0, true, Date.today().addDays(-1))
        };

        GetOffersForContact.Request req = new GetOffersForContact.Request();
        req.contactId = c.Id;

        Test.startTest();
        List<GetOffersForContact.Response> result =
            GetOffersForContact.getOffers(new List<GetOffersForContact.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, result.size(), 'One response per request expected');
        GetOffersForContact.Response res = result[0];
        System.assertEquals(2, res.offerCount, 'Only active, non-expired offers should be returned');
        System.assertEquals(2, res.offers.size(), 'Structured list should match the count');
        System.assert(res.offersSummary.contains('Active A'), 'Summary should mention the highest-discount offer');
        System.assertEquals('Active A', res.offers[0].name, 'Offers should be ordered by discount desc');
    }

    @IsTest
    static void ordersByRelevanceAndSplitsTopVsMore() {
        Contact c = makeContact();
        Offer__c high = makeOffer(c.Id, 'Top Pick', 'Mobile', 55, 10, true, Date.today().addDays(10));
        high.RelevanceScore__c = 100;
        high.Reason__c = 'Upgrade of your current plan';
        Offer__c mid = makeOffer(c.Id, 'Second Choice', 'Internet', 70, 30, true, null);
        mid.RelevanceScore__c = 50;
        insert new List<Offer__c>{ mid, high };

        GetOffersForContact.Request req = new GetOffersForContact.Request();
        req.contactId = c.Id;

        Test.startTest();
        List<GetOffersForContact.Response> result =
            GetOffersForContact.getOffers(new List<GetOffersForContact.Request>{ req });
        Test.stopTest();

        GetOffersForContact.Response res = result[0];
        System.assertEquals(2, res.offerCount);
        System.assertEquals('Top Pick', res.offers[0].name, 'Highest relevance should rank first even with a lower discount');
        System.assert(res.topOfferSummary.contains('Top Pick'), res.topOfferSummary);
        System.assert(res.topOfferSummary.contains('Upgrade of your current plan'), 'Top summary should include the reason');
        System.assert(res.moreOffersSummary.contains('Second Choice'), res.moreOffersSummary);
        System.assert(!res.topOfferSummary.contains('Second Choice'), 'Top summary should contain only the top offer');
    }

    @IsTest
    static void handlesNoOffers() {
        Contact c = makeContact();
        GetOffersForContact.Request req = new GetOffersForContact.Request();
        req.contactId = c.Id;

        List<GetOffersForContact.Response> result =
            GetOffersForContact.getOffers(new List<GetOffersForContact.Request>{ req });

        System.assertEquals(0, result[0].offerCount, 'No offers expected');
        System.assert(result[0].offersSummary.contains('no active offers'), 'Should return a friendly empty message');
    }

    @IsTest
    static void handlesBlankAndInvalidContactId() {
        GetOffersForContact.Request blank = new GetOffersForContact.Request();
        blank.contactId = '';
        GetOffersForContact.Request invalid = new GetOffersForContact.Request();
        invalid.contactId = 'not-an-id';

        List<GetOffersForContact.Response> result = GetOffersForContact.getOffers(
            new List<GetOffersForContact.Request>{ blank, invalid }
        );

        System.assertEquals(2, result.size());
        System.assertEquals(0, result[0].offerCount);
        System.assert(result[0].offersSummary.contains('No customer'), 'Blank id should report no customer');
        System.assertEquals(0, result[1].offerCount);
    }
}
