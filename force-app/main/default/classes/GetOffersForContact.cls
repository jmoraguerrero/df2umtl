/**
 * Agentforce custom action: returns the active, non-expired offers targeted to a
 * given Contact so the agent can present them to the connected customer in chat.
 *
 * Exposed to Agent Script as @actions.GetOffersForContact.
 */
public with sharing class GetOffersForContact {
    @TestVisible
    private static final Integer MAX_OFFERS = 10;

    public class Request {
        @InvocableVariable(
            required=true
            label='Contact Id'
            description='The Salesforce Contact Id of the connected customer whose offers should be returned.'
        )
        public String contactId;
    }

    public class OfferInfo {
        @InvocableVariable(label='Name')
        public String name;
        @InvocableVariable(label='Description')
        public String description;
        @InvocableVariable(label='Category')
        public String category;
        @InvocableVariable(label='Price')
        public Decimal price;
        @InvocableVariable(label='Discount Percent')
        public Decimal discountPercent;
        @InvocableVariable(label='Expiration Date')
        public String expirationDate;
    }

    public class Response {
        @InvocableVariable(label='Offer Count' description='Number of offers found for the contact.')
        public Integer offerCount;
        @InvocableVariable(label='Offers Summary' description='A human-readable summary of the offers the agent can read to the customer.')
        public String offersSummary;
        @InvocableVariable(label='Offers' description='Structured list of the offers found.')
        public List<OfferInfo> offers;
    }

    @InvocableMethod(
        label='Get Offers For Contact'
        description='Returns the active, non-expired offers targeted to the given contact.'
    )
    public static List<Response> getOffers(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(buildResponse(req == null ? null : req.contactId));
        }
        return responses;
    }

    private static Response buildResponse(String contactId) {
        Response res = new Response();
        res.offers = new List<OfferInfo>();
        res.offerCount = 0;

        if (String.isBlank(contactId) || !(contactId instanceof Id)) {
            res.offersSummary = 'No customer was identified, so no offers could be retrieved.';
            return res;
        }

        Id cId = (Id) contactId;
        List<Offer__c> records = [
            SELECT Name, Description__c, Category__c, Price__c, Discount__c, ExpirationDate__c
            FROM Offer__c
            WHERE Contact__c = :cId
              AND Active__c = true
              AND (ExpirationDate__c = null OR ExpirationDate__c >= :Date.today())
            ORDER BY Discount__c DESC NULLS LAST, Price__c ASC
            LIMIT :MAX_OFFERS
        ];

        List<String> lines = new List<String>();
        for (Offer__c o : records) {
            OfferInfo info = new OfferInfo();
            info.name = o.Name;
            info.description = o.Description__c;
            info.category = o.Category__c;
            info.price = o.Price__c;
            info.discountPercent = o.Discount__c;
            info.expirationDate = o.ExpirationDate__c == null
                ? null
                : o.ExpirationDate__c.format();
            res.offers.add(info);

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
            ? 'There are no active offers available for this customer right now.'
            : 'Here are the current offers for this customer:\n' + String.join(lines, '\n');
        return res;
    }
}
