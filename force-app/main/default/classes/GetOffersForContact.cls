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
        @InvocableVariable(label='Reason')
        public String reason;
        @InvocableVariable(label='Relevance Score')
        public Decimal relevanceScore;
    }

    public class Response {
        @InvocableVariable(label='Offer Count' description='Number of offers found for the contact.')
        public Integer offerCount;
        @InvocableVariable(label='Identified Flag' description='1 when a valid contact id was supplied (customer is known), otherwise 0.')
        public Integer identifiedFlag;
        @InvocableVariable(label='Top Offer Summary' description='The single most relevant offer, with its reason and expiry, as a bullet.')
        public String topOfferSummary;
        @InvocableVariable(label='More Offers Summary' description='The remaining offers as bullet points, shown only if the customer asks for more.')
        public String moreOffersSummary;
        @InvocableVariable(label='Offers Summary' description='A human-readable summary of all offers the agent can read to the customer.')
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
        res.identifiedFlag = 0;

        if (String.isBlank(contactId) || !(contactId instanceof Id)) {
            res.offersSummary = 'No customer was identified, so no offers could be retrieved.';
            return res;
        }

        res.identifiedFlag = 1;

        Id cId = (Id) contactId;
        List<Offer__c> records = [
            SELECT Name, Description__c, Category__c, Price__c, Discount__c, ExpirationDate__c,
                   Reason__c, RelevanceScore__c
            FROM Offer__c
            WHERE Contact__c = :cId
              AND Active__c = true
              AND (ExpirationDate__c = null OR ExpirationDate__c >= :Date.today())
            ORDER BY RelevanceScore__c DESC NULLS LAST, Discount__c DESC NULLS LAST, Price__c ASC
            LIMIT :MAX_OFFERS
        ];

        List<String> allLines = new List<String>();
        List<String> moreLines = new List<String>();
        for (Integer i = 0; i < records.size(); i++) {
            Offer__c o = records[i];

            OfferInfo info = new OfferInfo();
            info.name = o.Name;
            info.description = o.Description__c;
            info.category = o.Category__c;
            info.price = o.Price__c;
            info.discountPercent = o.Discount__c;
            info.expirationDate = o.ExpirationDate__c == null ? null : o.ExpirationDate__c.format();
            info.reason = o.Reason__c;
            info.relevanceScore = o.RelevanceScore__c;
            res.offers.add(info);

            String line = formatOffer(o);
            allLines.add(line);
            if (i == 0) {
                res.topOfferSummary = line;
            } else {
                moreLines.add(line);
            }
        }

        res.offerCount = records.size();
        res.moreOffersSummary = moreLines.isEmpty() ? '' : String.join(moreLines, '\n');
        res.offersSummary = records.isEmpty()
            ? 'There are no active offers available for this customer right now.'
            : String.join(allLines, '\n');
        if (res.topOfferSummary == null) {
            res.topOfferSummary = '';
        }
        return res;
    }

    /** Builds a single bullet line for an offer, including price, discount, expiry and reason. */
    private static String formatOffer(Offer__c o) {
        String line = '\u2022 ' + o.Name;

        List<String> bits = new List<String>();
        if (o.Price__c != null) {
            bits.add('$' + o.Price__c.setScale(2) + '/mo');
        }
        if (o.Discount__c != null && o.Discount__c > 0) {
            bits.add(o.Discount__c.stripTrailingZeros().toPlainString() + '% off');
        }
        if (!bits.isEmpty()) {
            line += ' \u2014 ' + String.join(bits, ', ');
        }
        if (o.ExpirationDate__c != null) {
            line += ' (ends ' + o.ExpirationDate__c.format() + ')';
        }
        if (String.isNotBlank(o.Description__c)) {
            line += '\n  ' + o.Description__c;
        }
        if (String.isNotBlank(o.Reason__c)) {
            line += '\n  Why it fits you: ' + o.Reason__c;
        }
        return line;
    }
}
