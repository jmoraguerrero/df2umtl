// Seed demo data for the WhatsApp Agentforce Offers demo.
// Creates (or reuses) a demo Contact and a set of active Offer__c records linked to it.
// Idempotent: re-running replaces the demo offers for the demo contact.

final String DEMO_EMAIL = 'alex.morgan.demo@example.com';

// Reuse or create the demo contact.
List<Contact> existing = [SELECT Id FROM Contact WHERE Email = :DEMO_EMAIL LIMIT 1];
Contact demo;
if (!existing.isEmpty()) {
    demo = existing[0];
} else {
    demo = new Contact(
        FirstName = 'Alex',
        LastName = 'Morgan',
        Email = DEMO_EMAIL,
        Phone = '+1 514 555 0142'
    );
    insert demo;
}

// Clear any prior demo offers for a clean seed.
delete [SELECT Id FROM Offer__c WHERE Contact__c = :demo.Id];

Date today = Date.today();
List<Offer__c> offers = new List<Offer__c>{
    new Offer__c(
        Name = 'Unlimited 5G Mobile Plan',
        Description__c = 'Unlimited talk, text, and 5G data with no overage charges. Includes free calls to 20 countries.',
        Category__c = 'Mobile',
        Price__c = 55.00,
        Discount__c = 20.00,
        Active__c = true,
        ExpirationDate__c = today.addDays(30),
        Contact__c = demo.Id
    ),
    new Offer__c(
        Name = 'Fibre Internet 1 Gbps',
        Description__c = 'Ultra-fast 1 Gbps fibre internet with free installation and a Wi-Fi 6 router included.',
        Category__c = 'Internet',
        Price__c = 70.00,
        Discount__c = 15.00,
        Active__c = true,
        ExpirationDate__c = today.addDays(45),
        Contact__c = demo.Id
    ),
    new Offer__c(
        Name = 'Premium TV + Streaming Bundle',
        Description__c = '200+ channels plus bundled streaming apps. Record up to 4 shows at once.',
        Category__c = 'TV',
        Price__c = 45.00,
        Discount__c = 10.00,
        Active__c = true,
        ExpirationDate__c = today.addDays(20),
        Contact__c = demo.Id
    ),
    new Offer__c(
        Name = 'Home + Mobile Triple Bundle',
        Description__c = 'Combine mobile, internet, and TV on one bill and save every month.',
        Category__c = 'Bundle',
        Price__c = 140.00,
        Discount__c = 30.00,
        Active__c = true,
        ExpirationDate__c = today.addDays(60),
        Contact__c = demo.Id
    ),
    new Offer__c(
        Name = 'Travel Roaming Day Pass',
        Description__c = 'Use your plan abroad for a flat daily rate in over 100 destinations.',
        Category__c = 'Roaming',
        Price__c = 12.00,
        Discount__c = 0.00,
        Active__c = true,
        ExpirationDate__c = today.addDays(90),
        Contact__c = demo.Id
    )
};
insert offers;

System.debug('DEMO_CONTACT_ID=' + demo.Id);
System.debug('DEMO_CONTACT_NAME=' + demo.FirstName + ' ' + demo.LastName);
System.debug('OFFERS_CREATED=' + offers.size());
