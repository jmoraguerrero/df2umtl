/**
 * Agentforce action: returns offers for a Contact (Contact__c) or Lead (Lead__c).
 * Supply contactId OR leadId — contact wins when both are set.
 */
public with sharing class GetOffersForCustomer {
    @TestVisible
    private static final Integer MAX_OFFERS = 10;

    public class Request {
        @InvocableVariable(
            required=false
            label='Contact Id'
            description='Salesforce Contact Id when the customer is a known contact.'
        )
        public String contactId;
        @InvocableVariable(
            required=false
            label='Lead Id'
            description='Salesforce Lead Id when the customer was captured via chat intake.'
        )
        public String leadId;
        @InvocableVariable(
            required=false
            label='Email'
            description='Fallback: find Lead by email when leadId is not set yet.'
        )
        public String email;
    }

    public class Response {
        @InvocableVariable(label='Offer Count')
        public Integer offerCount;
        @InvocableVariable(label='Identified Flag' description='1 when a valid contact or lead id was supplied.')
        public Integer identifiedFlag;
        @InvocableVariable(label='Top Offer Summary')
        public String topOfferSummary;
        @InvocableVariable(label='More Offers Summary')
        public String moreOffersSummary;
        @InvocableVariable(label='Offers Summary')
        public String offersSummary;
    }

    @InvocableMethod(
        label='Get Offers For Customer'
        description='Returns active offers for the given contact or lead.'
    )
    public static List<Response> getOffers(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            responses.add(buildResponse(req));
        }
        return responses;
    }

    private static Response buildResponse(Request req) {
        Response res = new Response();
        res.offerCount = 0;
        res.identifiedFlag = 0;
        res.topOfferSummary = '';
        res.moreOffersSummary = '';
        res.offersSummary = 'No customer was identified, so no offers could be retrieved.';

        String contactId = req == null ? null : req.contactId;
        String leadId = req == null ? null : req.leadId;

        Id cId = validId(contactId);
        Id lId = validId(leadId);
        if (lId == null && req != null) {
            lId = resolveLeadIdByEmail(req.email);
        }

        if (cId == null && lId == null) {
            return res;
        }

        res.identifiedFlag = 1;
        List<Offer__c> records = queryLinkedOffers(cId, lId);
        if (records.isEmpty()) {
            records = queryActiveCatalogOffers();
        }

        List<String> allLines = new List<String>();
        List<String> moreLines = new List<String>();
        for (Integer i = 0; i < records.size(); i++) {
            Offer__c o = records[i];
            String line = OfferPresentationUtil.formatOffer(o);
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

    @TestVisible
    private static Map<String, Schema.SObjectField> offerFieldMap() {
        return Schema.SObjectType.Offer__c.fields.getMap();
    }

    @TestVisible
    private static Boolean offerHasField(String apiName) {
        return offerFieldMap().containsKey(apiName);
    }

    @TestVisible
    private static List<Offer__c> queryLinkedOffers(Id contactId, Id leadId) {
        String selectClause = offerSelectClause();
        if (contactId != null && offerHasField('Contact__c')) {
            String soql =
                'SELECT ' +
                selectClause +
                ' FROM Offer__c WHERE Contact__c = :contactId';
            soql += activeAndExpirationFilters();
            soql += ' ORDER BY Name ASC LIMIT :maxRows';
            Integer maxRows = MAX_OFFERS;
            return Database.query(soql);
        }
        if (leadId != null && offerHasField('Lead__c')) {
            String soql =
                'SELECT ' +
                selectClause +
                ' FROM Offer__c WHERE Lead__c = :leadId';
            soql += activeAndExpirationFilters();
            soql += ' ORDER BY Name ASC LIMIT :maxRows';
            Integer maxRows = MAX_OFFERS;
            return Database.query(soql);
        }
        return new List<Offer__c>();
    }

    /** Active offers with no Contact/Lead — banking demo product catalog. */
    @TestVisible
    private static List<Offer__c> queryActiveCatalogOffers() {
        String selectClause = offerSelectClause();
        List<String> filters = new List<String>();
        if (offerHasField('Contact__c')) {
            filters.add('Contact__c = null');
        }
        if (offerHasField('Lead__c')) {
            filters.add('Lead__c = null');
        }
        String soql = 'SELECT ' + selectClause + ' FROM Offer__c';
        if (!filters.isEmpty()) {
            soql += ' WHERE ' + String.join(filters, ' AND ');
            soql += activeAndExpirationFilters().replace(' AND ', ' AND ');
        } else if (offerHasField('Active__c')) {
            soql += ' WHERE Active__c = true';
        }
        if (offerHasField('RelevanceScore__c')) {
            soql += ' ORDER BY RelevanceScore__c DESC NULLS LAST, Name ASC';
        } else {
            soql += ' ORDER BY Name ASC';
        }
        soql += ' LIMIT :maxRows';
        Integer maxRows = MAX_OFFERS;
        return Database.query(soql);
    }

    private static String offerSelectClause() {
        List<String> parts = new List<String>{ 'Name' };
        for (String fieldName : new List<String>{
            'Description__c',
            'Category__c',
            'Price__c',
            'Discount__c',
            'ExpirationDate__c',
            'Reason__c',
            'RelevanceScore__c'
        }) {
            if (offerHasField(fieldName)) {
                parts.add(fieldName);
            }
        }
        return String.join(parts, ', ');
    }

    private static String activeAndExpirationFilters() {
        String clause = '';
        if (offerHasField('Active__c')) {
            clause += ' AND Active__c = true';
        }
        if (offerHasField('ExpirationDate__c')) {
            clause += ' AND (ExpirationDate__c = null OR ExpirationDate__c >= TODAY)';
        }
        return clause;
    }

    private static Id validId(String raw) {
        if (String.isBlank(raw) || !(raw instanceof Id)) {
            return null;
        }
        return (Id) raw;
    }

    private static Id resolveLeadIdByEmail(String email) {
        if (String.isBlank(email) || !email.contains('@')) {
            return null;
        }
        String normalized = email.trim().toLowerCase();
        List<Lead> rows = [
            SELECT Id
            FROM Lead
            WHERE Email = :normalized
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }
}