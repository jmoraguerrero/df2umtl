// Partner Central — Einstein agent user for Offer Concierge (must match v1 Agent Access / botUser).
// Username from committed Bot metadata: OfferConcierge.bot-meta.xml botUser field.
String username = 'offerconcierge@00dfj00000ryet71173413824.ext';

List<User> existing = [SELECT Id FROM User WHERE Username = :username LIMIT 1];
User agentUser;
if (!existing.isEmpty()) {
    agentUser = existing[0];
    System.debug('Agent user already exists: ' + agentUser.Id);
} else {
    Profile agentProfile = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Einstein Agent User'
        LIMIT 1
    ];
    agentUser = new User(
        ProfileId = agentProfile.Id,
        Username = username,
        LastName = 'Concierge',
        FirstName = 'Offer',
        Email = 'noreply-offerconcierge@example.com',
        Alias = 'ofrcnc',
        TimeZoneSidKey = 'America/New_York',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        CommunityNickname = 'OfferConciergePC'
    );
    insert agentUser;
    System.debug('Created agent user: ' + agentUser.Id);
}

assignPermSetIfMissing(agentUser.Id, 'AgentforceServiceAgentUser');
assignPermSetIfMissing(agentUser.Id, 'Offer_Demo_Access');
assignPermSetIfMissing(agentUser.Id, 'Agent_Broker_Access');

static void assignPermSetIfMissing(Id userId, String permSetName) {
    PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permSetName LIMIT 1];
    if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSetId = :ps.Id] == 0) {
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
        System.debug('Assigned ' + permSetName);
    }
}
