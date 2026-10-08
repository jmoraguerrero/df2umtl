/**
 * Agentforce custom action: looks up a Contact by name and returns that
 * contact's active, non-expired offers. Used when the chat has no contactId
 * (the agent asks the customer for their name and calls this to find them).
 *
 * Exposed to Agent Script as @actions.GetOffersByName.
 */
public with sharing class GetOffersByName {
    @TestVisible
    private static final Integer MAX_OFFERS = 10;

    public class Request {
        @InvocableVariable(
            required=true
            label='Customer Name'
            description='The customer full name (or part of it) to search for.'
        )
        public String customerName;
    }

    public class Response {
        @InvocableVariable(label='Customer Found' description='True when a matching contact was found.')
        public Boolean customerFound;
        @InvocableVariable(label='Matched Name' description='The full name of the contact that was matched.')
        public String matchedName;
        @InvocableVariable(label='Contact Id' description='The Id of the matched contact.')
        public String contactId;
        @InvocableVariable(label='Offer Count' description='Number of offers found for the matched contact.')
        public Integer offerCount;
        @InvocableVariable(label='Offers Summary' description='A human-readable summary of the offers the agent can read to the customer.')
        public String offersSummary;
    }

    @InvocableMethod(
        label='Get Offers By Name'
        description='Finds a contact by name and returns their active, non-expired offers.'
    )
    public static List<Response> getOffers(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(buildResponse(req == null ? null : req.customerName));
        }
        return responses;
    }

    private static Response buildResponse(String customerName) {
        Response res = new Response();
        res.customerFound = false;
        res.offerCount = 0;

        if (String.isBlank(customerName)) {
            res.offersSummary = 'No name was provided, so I could not look up an account.';
            return res;
        }

        String pattern = '%' + customerName.trim() + '%';
        List<Contact> contacts = [
            SELECT Id, Name
            FROM Contact
            WHERE Name LIKE :pattern
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            res.offersSummary = 'I could not find an account under the name "' + customerName.trim() + '".';
            return res;
        }

        Contact matched = contacts[0];
        res.customerFound = true;
        res.matchedName = matched.Name;
        res.contactId = matched.Id;

        List<Offer__c> records = [
            SELECT Name, Description__c, Category__c, Price__c, Discount__c, ExpirationDate__c
            FROM Offer__c
            WHERE Contact__c = :matched.Id
              AND Active__c = true
              AND (ExpirationDate__c = null OR ExpirationDate__c >= :Date.today())
            ORDER BY Discount__c DESC NULLS LAST, Price__c ASC
            LIMIT :MAX_OFFERS
        ];

        List<String> lines = new List<String>();
        for (Offer__c o : records) {
            String line = '- ' + o.Name;
            if (o.Price__c != null) {
                line += ' (' + o.Price__c.setScale(2) + ' / month';
                if (o.Discount__c != null && o.Discount__c > 0) {
                    line += ', ' + o.Discount__c.stripTrailingZeros().toPlainString() + '% off';
                }
                line += ')';
            }
            if (String.isNotBlank(o.Description__c)) {
                line += ': ' + o.Description__c;
            }
            lines.add(line);
        }

        res.offerCount = records.size();
        res.offersSummary = records.isEmpty()
            ? 'There are no active offers available for ' + matched.Name + ' right now.'
            : 'Here are the current offers for ' + matched.Name + ':\n' + String.join(lines, '\n');
        return res;
    }
}
