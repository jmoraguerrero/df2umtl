@IsTest
private class GetOffersForCustomerTest {

    @IsTest
    static void returnsOffersForLead() {
        Lead l = new Lead(
            FirstName = 'Demo',
            LastName = 'Lead',
            Email = 'demo.lead.offers@example.com',
            Company = 'Web Chat'
        );
        insert l;

        insert new Offer__c(
            Name = 'Lead Mobile Plan',
            Lead__c = l.Id,
            Active__c = true,
            Price__c = 40,
            Discount__c = 10,
            RelevanceScore__c = 90,
            Reason__c = 'Welcome offer for new chat leads.'
        );

        GetOffersForCustomer.Request req = new GetOffersForCustomer.Request();
        req.leadId = l.Id;

        GetOffersForCustomer.Response res = GetOffersForCustomer.getOffers(new List<GetOffersForCustomer.Request>{ req })[0];
        System.assertEquals(1, res.identifiedFlag);
        System.assertEquals(1, res.offerCount);
        System.assert(res.topOfferSummary.contains('Lead Mobile Plan'));
    }
}
