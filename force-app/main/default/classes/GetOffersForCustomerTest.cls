@IsTest
private class GetOffersForCustomerTest {

    @IsTest
    static void returnsActiveCatalogForIdentifiedLead() {
        Lead l = new Lead(
            FirstName = 'Demo',
            LastName = 'Lead',
            Email = 'demo.lead.offers@example.com',
            Company = 'Web Chat'
        );
        insert l;

        insert new Offer__c(
            Name = 'Lead-Only Plan',
            Lead__c = l.Id,
            Active__c = true,
            Price__c = 40
        );
        insert new Offer__c(
            Name = 'Newcomer Credit Card',
            Active__c = true,
            Description__c = 'Catalog newcomer card.'
        );

        GetOffersForCustomer.Request req = new GetOffersForCustomer.Request();
        req.leadId = l.Id;

        GetOffersForCustomer.Response res = GetOffersForCustomer.getOffers(new List<GetOffersForCustomer.Request>{ req })[0];
        System.assertEquals(1, res.identifiedFlag);
        System.assertEquals(1, res.offerCount);
        System.assert(res.topOfferSummary.contains('Newcomer Credit Card'));
        System.assert(!res.offersSummary.contains('Lead-Only Plan'));
    }

    @IsTest
    static void returnsActiveCatalogWhenAnonymous() {
        insert new Offer__c(
            Name = 'Newcomer Credit Card',
            Active__c = true,
            Description__c = 'Catalog newcomer card.'
        );
        insert new Offer__c(
            Name = 'Business Credit Card',
            Active__c = true,
            Description__c = 'Catalog business card.'
        );

        GetOffersForCustomer.Response res = GetOffersForCustomer.getOffers(
            new List<GetOffersForCustomer.Request>{ new GetOffersForCustomer.Request() }
        )[0];
        System.assertEquals(0, res.identifiedFlag);
        System.assertEquals(2, res.offerCount);
        System.assert(res.offersSummary.contains('Newcomer Credit Card'));
        System.assert(res.offersSummary.contains('Business Credit Card'));
    }

    @IsTest
    static void fallsBackToActiveCatalogWhenLeadHasNoOffers() {
        Lead l = new Lead(
            FirstName = 'Cat',
            LastName = 'Lead',
            Email = 'catalog.fallback@example.com',
            Company = 'Web Chat'
        );
        insert l;

        insert new Offer__c(
            Name = 'Newcomer Credit Card',
            Active__c = true,
            Category__c = 'Credit Card',
            Description__c = 'Catalog newcomer card.',
            RelevanceScore__c = 100
        );
        insert new Offer__c(
            Name = 'Business Credit Card',
            Active__c = true,
            Category__c = 'Credit Card',
            Description__c = 'Catalog business card.',
            RelevanceScore__c = 90
        );

        GetOffersForCustomer.Request req = new GetOffersForCustomer.Request();
        req.leadId = l.Id;

        GetOffersForCustomer.Response res = GetOffersForCustomer.getOffers(new List<GetOffersForCustomer.Request>{ req })[0];
        System.assertEquals(1, res.identifiedFlag);
        System.assertEquals(2, res.offerCount);
        System.assert(res.offersSummary.contains('Newcomer Credit Card'));
        System.assert(res.offersSummary.contains('Business Credit Card'));
    }
}
