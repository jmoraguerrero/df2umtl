/**
 * Agentforce action: persists the customer's chosen catalog offer name on Lead.Selected_Option__c.
 */
public with sharing class SaveLeadSelectedOption {
    public class Request {
        @InvocableVariable(
            required=true
            label='Lead Id'
            description='Salesforce Lead Id from intake.'
        )
        public String leadId;
        @InvocableVariable(
            required=true
            label='Selected Option'
            description='Exact Offer__c Name the customer chose (must match catalog).'
        )
        public String selectedOption;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Save Lead Selected Option'
        description='Sets Lead Selected Option to the chosen offer name.'
    )
    public static List<Response> save(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            out.add(process(req));
        }
        return out;
    }

    private static Response process(Request req) {
        Response res = new Response();
        res.success = false;

        if (req == null || String.isBlank(req.leadId) || !(req.leadId instanceof Id)) {
            res.message = 'A valid Lead Id is required.';
            return res;
        }
        if (String.isBlank(req.selectedOption)) {
            res.message = 'Selected option (offer name) is required.';
            return res;
        }
        if (!leadHasField('Selected_Option__c')) {
            res.message = 'Lead Selected Option field is not available in this org.';
            return res;
        }

        String choice = req.selectedOption.trim();
        try {
            Lead row = new Lead(Id = (Id) req.leadId);
            row.put('Selected_Option__c', choice);
            update row;
            res.success = true;
            res.message = 'Saved selected option: ' + choice;
        } catch (Exception e) {
            res.message = 'Could not update lead: ' + e.getMessage();
        }
        return res;
    }

    @TestVisible
    private static Boolean leadHasField(String apiName) {
        return Schema.SObjectType.Lead.fields.getMap().containsKey(apiName);
    }
}