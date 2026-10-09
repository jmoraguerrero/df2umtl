// Seed demo data for the "win some swag" quiz.
// Creates the active quiz questions (with per-option scores as JSON) and the
// score-banded swags. Idempotent: re-running replaces the demo questions and swags,
// and clears any existing Swag_Response__c records so the quiz can be retaken in demos.

// ---------- Reset ----------
delete [SELECT Id FROM Swag_Response__c];
delete [SELECT Id FROM Swag_Question__c];
delete [SELECT Id FROM Swag__c];

// ---------- Questions (ordered; Options__c is a JSON array of {label, score}) ----------
List<Swag_Question__c> questions = new List<Swag_Question__c>{
    new Swag_Question__c(
        Name = 'Screen Time',
        Question_Text__c = 'First up - how do you spend most of your screen time?',
        Order__c = 1,
        Active__c = true,
        Options__c = '[{"label":"Streaming & movies","score":3},{"label":"Gaming","score":3},{"label":"Social media","score":2},{"label":"Work & email","score":1}]'
    ),
    new Swag_Question__c(
        Name = 'Ideal Weekend',
        Question_Text__c = 'What\'s your ideal weekend?',
        Order__c = 2,
        Active__c = true,
        Options__c = '[{"label":"Outdoor adventure","score":3},{"label":"Social hangouts","score":2},{"label":"Chill at home","score":1}]'
    ),
    new Swag_Question__c(
        Name = 'Dream Upgrade',
        Question_Text__c = 'Last one - pick your dream gadget upgrade.',
        Order__c = 3,
        Active__c = true,
        Options__c = '[{"label":"Giant smart TV","score":3},{"label":"Latest phone","score":2},{"label":"Noise-cancelling headphones","score":2},{"label":"New laptop","score":1}]'
    )
};
insert questions;

// ---------- Swags (score bands cover every possible total, 3-9) ----------
List<Swag__c> swags = new List<Swag__c>{
    new Swag__c(
        Name = 'Sticker & Decal Pack',
        Description__c = 'A pack of premium stickers and decals to deck out your gear.',
        Emoji__c = '\uD83C\uDF9F\uFE0F',
        Min_Score__c = 0, Max_Score__c = 4, Active__c = true
    ),
    new Swag__c(
        Name = 'Wireless Earbuds',
        Description__c = 'A sleek pair of wireless earbuds for music, calls, and gaming on the go.',
        Emoji__c = '\uD83C\uDFA7',
        Min_Score__c = 5, Max_Score__c = 6, Active__c = true
    ),
    new Swag__c(
        Name = 'Premium Hoodie',
        Description__c = 'A super-cozy premium branded hoodie - the crowd favourite!',
        Emoji__c = '\uD83E\uDDE5',
        Min_Score__c = 7, Max_Score__c = 9, Active__c = true
    )
};
insert swags;

System.debug('Seeded ' + questions.size() + ' questions and ' + swags.size() + ' swags.');
