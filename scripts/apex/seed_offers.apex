// Seed demo data for the WhatsApp Agentforce Offers demo.
// Creates (or reuses) demo Contacts and a set of active, ranked Offer__c records
// linked to them (each with a RelevanceScore and a personalized Reason).
// Idempotent: re-running replaces the demo offers for each demo contact.

Date today = Date.today();

// ---------- Contact 1: Alex Morgan (loyal customer / upgrades) ----------
final String MORGAN_EMAIL = 'alex.morgan.demo@example.com';
List<Contact> morganExisting = [SELECT Id FROM Contact WHERE Email = :MORGAN_EMAIL LIMIT 1];
Contact morgan;
if (!morganExisting.isEmpty()) {
    morgan = morganExisting[0];
} else {
    morgan = new Contact(FirstName = 'Alex', LastName = 'Morgan', Email = MORGAN_EMAIL, Phone = '+1 514 555 0142');
    insert morgan;
}
delete [SELECT Id FROM Offer__c WHERE Contact__c = :morgan.Id];

List<Offer__c> morganOffers = new List<Offer__c>{
    new Offer__c(
        Name = 'Unlimited 5G Mobile Plan',
        Description__c = 'Unlimited talk, text, and 5G data with no overage charges. Includes free calls to 20 countries.',
        Category__c = 'Mobile',
        Price__c = 55.00, Discount__c = 20.00, Active__c = true,
        ExpirationDate__c = today.addDays(14),
        RelevanceScore__c = 100,
        Reason__c = 'You\'ve been on our mobile plan for 3 years - this is the upgraded 5G version with double the data at the same price.',
        Contact__c = morgan.Id
    ),
    new Offer__c(
        Name = 'Home + Mobile Triple Bundle',
        Description__c = 'Combine mobile, internet, and TV on one bill and save every month.',
        Category__c = 'Bundle',
        Price__c = 140.00, Discount__c = 30.00, Active__c = true,
        ExpirationDate__c = today.addDays(30),
        RelevanceScore__c = 85,
        Reason__c = 'You already pay for mobile and internet separately - bundling saves you the most every month.',
        Contact__c = morgan.Id
    ),
    new Offer__c(
        Name = 'Fibre Internet 1 Gbps',
        Description__c = 'Ultra-fast 1 Gbps fibre internet with free installation and a Wi-Fi 6 router included.',
        Category__c = 'Internet',
        Price__c = 70.00, Discount__c = 15.00, Active__c = true,
        ExpirationDate__c = today.addDays(45),
        RelevanceScore__c = 70,
        Reason__c = 'Your current internet is half this speed - a perfect upgrade for streaming and gaming.',
        Contact__c = morgan.Id
    ),
    new Offer__c(
        Name = 'Premium TV + Streaming Bundle',
        Description__c = '200+ channels plus bundled streaming apps. Record up to 4 shows at once.',
        Category__c = 'TV',
        Price__c = 45.00, Discount__c = 10.00, Active__c = true,
        ExpirationDate__c = today.addDays(20),
        RelevanceScore__c = 55,
        Reason__c = 'Customers with your mobile + internet setup love adding this for movie nights.',
        Contact__c = morgan.Id
    ),
    new Offer__c(
        Name = 'Travel Roaming Day Pass',
        Description__c = 'Use your plan abroad for a flat daily rate in over 100 destinations.',
        Category__c = 'Roaming',
        Price__c = 12.00, Discount__c = 0.00, Active__c = true,
        ExpirationDate__c = today.addDays(90),
        RelevanceScore__c = 40,
        Reason__c = 'You travelled internationally last year - handy to have ready for your next trip.',
        Contact__c = morgan.Id
    )
};
insert morganOffers;

// ---------- Contact 2: Alex Misfit (win-back / returning customer) ----------
List<Contact> misfitExisting = [SELECT Id FROM Contact WHERE FirstName = 'Alex' AND LastName = 'Misfit' LIMIT 1];
Contact misfit;
if (!misfitExisting.isEmpty()) {
    misfit = misfitExisting[0];
} else {
    misfit = new Contact(FirstName = 'Alex', LastName = 'Misfit');
    insert misfit;
}
delete [SELECT Id FROM Offer__c WHERE Contact__c = :misfit.Id];

List<Offer__c> misfitOffers = new List<Offer__c>{
    new Offer__c(
        Name = 'Welcome Back Unlimited 5G',
        Description__c = 'Exclusive returning-customer unlimited 5G plan - unlimited data, talk, and text.',
        Category__c = 'Mobile',
        Price__c = 45.00, Discount__c = 35.00, Active__c = true,
        ExpirationDate__c = today.addDays(10),
        RelevanceScore__c = 100,
        Reason__c = 'We\'ve missed you! Here\'s an exclusive win-back deal to welcome you back with our best price yet.',
        Contact__c = misfit.Id
    ),
    new Offer__c(
        Name = 'Comeback Fibre Internet',
        Description__c = 'Reconnect your home with 1 Gbps fibre at a special returning-customer rate.',
        Category__c = 'Internet',
        Price__c = 60.00, Discount__c = 25.00, Active__c = true,
        ExpirationDate__c = today.addDays(25),
        RelevanceScore__c = 70,
        Reason__c = 'Get back online fast - a special reconnection rate just for returning customers like you.',
        Contact__c = misfit.Id
    ),
    new Offer__c(
        Name = 'Catch-Up TV Bundle',
        Description__c = 'All the channels and streaming apps you missed, in one easy bundle.',
        Category__c = 'TV',
        Price__c = 35.00, Discount__c = 20.00, Active__c = true,
        ExpirationDate__c = today.addDays(20),
        RelevanceScore__c = 50,
        Reason__c = 'Catch up on everything you missed while you were away with this comeback TV deal.',
        Contact__c = misfit.Id
    )
};
insert misfitOffers;

System.debug('MORGAN_CONTACT_ID=' + morgan.Id + ' offers=' + morganOffers.size());
System.debug('MISFIT_CONTACT_ID=' + misfit.Id + ' offers=' + misfitOffers.size());
