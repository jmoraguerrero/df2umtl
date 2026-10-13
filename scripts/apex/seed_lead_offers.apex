// Demo Lead + personalized offers for anonymous chat intake (Offer__c.Lead__c).
// Idempotent: re-running replaces offers for the template lead email.

Date today = Date.today();
final String EMAIL = 'demo.lead.chat@example.com';

List<Lead> existing = [SELECT Id FROM Lead WHERE Email = :EMAIL LIMIT 1];
Lead l;
if (!existing.isEmpty()) {
    l = existing[0];
} else {
    l = new Lead(
        FirstName = 'Demo',
        LastName = 'ChatLead',
        Email = EMAIL,
        Phone = '+1 514 555 0100',
        Company = 'Web Chat',
        LeadSource = 'Offer Concierge'
    );
    insert l;
}

delete [SELECT Id FROM Offer__c WHERE Lead__c = :l.Id];

insert new List<Offer__c>{
    new Offer__c(
        Name = 'New Visitor Mobile Welcome',
        Description__c = 'Unlimited talk, text, and 5G data for new chat sign-ups.',
        Category__c = 'Mobile',
        Price__c = 45.00,
        Discount__c = 25.00,
        Active__c = true,
        ExpirationDate__c = today.addDays(21),
        RelevanceScore__c = 95,
        Reason__c = 'You just joined us through chat — this welcome plan is priced for first-time customers.',
        Lead__c = l.Id
    ),
    new Offer__c(
        Name = 'Stream & Save Bundle',
        Description__c = 'Mobile plus streaming partner discount on one bill.',
        Category__c = 'Bundle',
        Price__c = 65.00,
        Discount__c = 15.00,
        Active__c = true,
        ExpirationDate__c = today.addDays(30),
        RelevanceScore__c = 80,
        Reason__c = 'Great if you love streaming on the go.',
        Lead__c = l.Id
    )
};

System.debug('Seeded Lead ' + l.Id + ' with offers for email ' + EMAIL);
