// DF2U MTL sandbox (alias: df2umtl). See also data-import/User.json for bulk import.
Profile agentProfile = [
    SELECT Id
    FROM Profile
    WHERE Name = 'Einstein Agent User'
    LIMIT 1
];
String username = 'offerconcierge.agent@df2umtl.velocityfun.demo';
List<User> existing = [SELECT Id FROM User WHERE Username = :username LIMIT 1];
User agentUser;
if (!existing.isEmpty()) {
    agentUser = existing[0];
    System.debug('Agent user already exists: ' + agentUser.Id);
} else {
    agentUser = new User(
        ProfileId = agentProfile.Id,
        Username = username,
        LastName = 'Concierge',
        FirstName = 'Offer',
        Email = 'noreply@example.com',
        Alias = 'ofrcnc',
        TimeZoneSidKey = 'America/Toronto',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        CommunityNickname = 'OfferConciergeAgent'
    );
    insert agentUser;
    System.debug('Created agent user: ' + agentUser.Id);
}
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Offer_Demo_Access' LIMIT 1];
if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :agentUser.Id AND PermissionSetId = :ps.Id] == 0) {
    insert new PermissionSetAssignment(AssigneeId = agentUser.Id, PermissionSetId = ps.Id);
    System.debug('Assigned Offer_Demo_Access');
}
