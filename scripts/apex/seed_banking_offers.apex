// Banking demo: clear offers, seed two active catalog rows (no Contact/Lead).
// Uses only fields that exist on Offer__c in this org (Active__c may be missing until metadata sync).
// Run: sf apex run --target-org partnercentral --file scripts/apex/seed_banking_offers.apex

Map<String, Schema.SObjectField> offerFields = Schema.SObjectType.Offer__c.fields.getMap();
Date today = Date.today();

List<Offer__c> existing = [SELECT Id FROM Offer__c];
if (!existing.isEmpty()) {
    if (offerFields.containsKey('Active__c')) {
        for (Offer__c row : existing) {
            row.put('Active__c', false);
        }
        update existing;
    } else {
        delete existing;
    }
}

Set<String> catalogNames = new Set<String>{
    'Newcomer Credit Card',
    'Business Credit Card'
};
delete [SELECT Id FROM Offer__c WHERE Name IN :catalogNames];

Offer__c newcomer = new Offer__c(Name = 'Newcomer Credit Card');
Offer__c business = new Offer__c(Name = 'Business Credit Card');

if (offerFields.containsKey('Active__c')) {
    newcomer.put('Active__c', true);
    business.put('Active__c', true);
}
if (offerFields.containsKey('Category__c')) {
    newcomer.put('Category__c', 'Credit Card');
    business.put('Category__c', 'Credit Card');
}
if (offerFields.containsKey('Price__c')) {
    newcomer.put('Price__c', 0);
    business.put('Price__c', 29);
}
if (offerFields.containsKey('Discount__c')) {
    newcomer.put('Discount__c', 0);
    business.put('Discount__c', 0);
}
if (offerFields.containsKey('ExpirationDate__c')) {
    newcomer.put('ExpirationDate__c', today.addYears(1));
    business.put('ExpirationDate__c', today.addYears(1));
}
if (offerFields.containsKey('RelevanceScore__c')) {
    newcomer.put('RelevanceScore__c', 100);
    business.put('RelevanceScore__c', 90);
}
if (offerFields.containsKey('Reason__c')) {
    newcomer.put(
        'Reason__c',
        'Best fit when the customer is new to banking or building their first credit relationship.'
    );
    business.put(
        'Reason__c',
        'Best fit when the customer mentions a company, LLC, freelance work, or business expenses.'
    );
}
if (offerFields.containsKey('Description__c')) {
    newcomer.put(
        'Description__c',
        'Designed for people who are new to credit or rebuilding. No annual fee for the first year, '
            + 'straightforward approval for thin credit files, basic rewards on everyday purchases, '
            + 'and digital-first servicing. Ideal when the conversation mentions first card, student, '
            + 'new job, immigrating, or limited credit history.'
    );
    business.put(
        'Description__c',
        'For small businesses and sole proprietors who need to separate business spending. '
            + 'Employee cards, spend controls, accounting export, and higher limits tied to business revenue. '
            + 'Ideal when the conversation mentions business, startup, contractor, incorporated, '
            + 'or mixed personal and business purchases.'
    );
}

insert new List<Offer__c>{ newcomer, business };
System.debug('Seeded 2 banking catalog offers on Offer__c.');
