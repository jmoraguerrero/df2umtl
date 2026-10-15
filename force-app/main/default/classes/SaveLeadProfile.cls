/**
 * Agentforce action: saves chat intake as a Lead after explicit customer confirmation.
 * DML runs without sharing so the agent user can upsert reliably.
 */
public with sharing class SaveLeadProfile {
    private static final String DEFAULT_COMPANY = 'Web Chat';
    private static final String LEAD_SOURCE = 'Offer Concierge';
    private static final String STATUS_QUALIFIED = 'Qualified';

    public class Request {
        @InvocableVariable(label='First Name')
        public String firstName;
        @InvocableVariable(label='Last Name')
        public String lastName;
        @InvocableVariable(label='Full Name' description='Optional; parsed into first/last when those are blank.')
        public String fullName;
        @InvocableVariable(label='Email')
        public String email;
        @InvocableVariable(label='Phone')
        public String phone;
        @InvocableVariable(
            required=true
            label='Confirmed'
            description='Must be true to persist. Customer must have explicitly agreed to save their details.'
        )
        public Boolean confirmed;
        @InvocableVariable(
            label='Recommended Offer'
            description='Exact catalog offer name recommended during qualification (stored on Lead Description).'
        )
        public String recommendedOffer;
        @InvocableVariable(
            label='Qualification Notes'
            description='Optional free-text notes from the fit conversation.'
        )
        public String qualificationNotes;
        @InvocableVariable(
            label='Marketing Consent'
            description='True when the customer opted in to tailored offers by email.'
        )
        public Boolean marketingConsent;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Lead Id')
        public String leadId;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Save Lead Profile'
        description='Creates or updates a Lead from chat intake after customer confirmation.'
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

        if (req == null || req.confirmed != true) {
            res.message = 'Nothing was saved because the customer has not confirmed yet.';
            return res;
        }

        NameParts parts = resolveNames(req.firstName, req.lastName, req.fullName);
        if (String.isBlank(parts.firstName) || String.isBlank(parts.lastName)) {
            res.message = 'First and last name are required before saving.';
            return res;
        }

        String email = normalizeEmail(req.email);
        if (String.isBlank(email) || !email.contains('@')) {
            res.message = 'A valid email address is required before saving.';
            return res;
        }

        String phone = String.isBlank(req.phone) ? null : req.phone.trim();

        try {
            Lead saved = new LeadWriter()
                .upsertLead(parts.firstName, parts.lastName, email, phone, req);
            res.success = true;
            res.leadId = saved.Id;
            res.message = 'Lead saved for ' + parts.firstName + ' ' + parts.lastName + '.';
        } catch (Exception e) {
            res.message = 'Could not save lead: ' + e.getMessage();
        }
        return res;
    }

    @TestVisible
    private static NameParts resolveNames(String firstName, String lastName, String fullName) {
        NameParts p = new NameParts();
        if (String.isNotBlank(firstName)) {
            p.firstName = firstName.trim();
        }
        if (String.isNotBlank(lastName)) {
            p.lastName = lastName.trim();
        }
        if (String.isNotBlank(p.firstName) && String.isNotBlank(p.lastName)) {
            return p;
        }

        String raw = String.isNotBlank(fullName)
            ? fullName.trim()
            : (String.isNotBlank(firstName) ? firstName.trim() : '');
        if (String.isBlank(raw)) {
            return p;
        }

        raw = raw.replaceAll('[^a-zA-Z0-9\\s\\-\']', ' ').replaceAll('\\s+', ' ').trim();
        List<String> tokens = raw.split(' ');
        if (tokens.isEmpty()) {
            return p;
        }
        if (tokens.size() == 1) {
            p.firstName = tokens[0];
            p.lastName = 'Unknown';
            return p;
        }
        p.firstName = tokens[0];
        List<String> rest = new List<String>();
        for (Integer i = 1; i < tokens.size(); i++) {
            rest.add(tokens[i]);
        }
        p.lastName = String.join(rest, ' ');
        if (String.isBlank(p.firstName)) {
            p.firstName = p.lastName;
        }
        return p;
    }

    private static String normalizeEmail(String email) {
        return String.isBlank(email) ? null : email.trim().toLowerCase();
    }

    @TestVisible
    private static String buildDescription(Request req) {
        List<String> lines = new List<String>();
        lines.add('Offer Concierge chat');
        if (String.isNotBlank(req.recommendedOffer)) {
            lines.add('Recommended card: ' + req.recommendedOffer.trim());
        }
        if (String.isNotBlank(req.qualificationNotes)) {
            lines.add('Notes: ' + req.qualificationNotes.trim());
        }
        if (req.marketingConsent != null) {
            lines.add(
                'Marketing consent: ' + (req.marketingConsent ? 'Opted in' : 'Not given')
            );
        }
        return String.join(lines, '\n');
    }

    @TestVisible
    private static Boolean isActivePicklistValue(Schema.SObjectField field, String value) {
        if (String.isBlank(value)) {
            return false;
        }
        for (Schema.PicklistEntry pe : field.getDescribe().getPicklistValues()) {
            if (pe.isActive() && pe.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    @TestVisible
    private class NameParts {
        public String firstName;
        public String lastName;
    }

    private without sharing class LeadWriter {
        Lead upsertLead(String firstName, String lastName, String email, String phone, Request req) {
            List<Lead> existing = [
                SELECT Id, FirstName, LastName, Email, Phone, Company, Description
                FROM Lead
                WHERE Email = :email
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            Lead row;
            if (!existing.isEmpty()) {
                row = existing[0];
            } else {
                row = new Lead(
                    FirstName = firstName,
                    LastName = lastName,
                    Email = email,
                    Company = DEFAULT_COMPANY,
                    LeadSource = LEAD_SOURCE
                );
            }

            row.FirstName = firstName;
            row.LastName = lastName;
            row.Email = email;
            if (String.isNotBlank(phone)) {
                row.Phone = phone;
            }
            if (String.isBlank(row.Company)) {
                row.Company = DEFAULT_COMPANY;
            }
            if (String.isBlank(row.LeadSource)) {
                row.LeadSource = LEAD_SOURCE;
            }

            String qualificationNotes = buildDescription(req);
            if (String.isNotBlank(qualificationNotes)) {
                row.Description = qualificationNotes;
            }

            if (req.marketingConsent != null) {
                row.HasOptedOutOfEmail = !req.marketingConsent;
            }

            if (isActivePicklistValue(Lead.Status, STATUS_QUALIFIED)) {
                row.Status = STATUS_QUALIFIED;
            }

            if (row.Id == null) {
                insert row;
            } else {
                update row;
            }
            return row;
        }
    }
}