/**
 * Public broker endpoint for the WhatsApp-style demo page.
 *
 * Exposed on a Salesforce Site so the static front-end (GitHub Pages) can talk
 * to Agentforce without ever holding Salesforce credentials. The guest user
 * runs this class; all Agent API secrets live in the Named Credential.
 *
 *   POST /services/apexrest/agentdemo/session   { "contactId": "003..." }
 *        -> { "sessionId": "..." }
 *   POST /services/apexrest/agentdemo/message   { "sessionId": "...", "message": "hi", "sequenceId": 2, "contactId": "003..." }
 *        -> { "reply": "..." }
 */
@RestResource(urlMapping='/agentdemo/*')
global with sharing class AgentDemoResource {

    global class ErrorResponse {
        global String error;
        global ErrorResponse(String msg) { this.error = msg; }
    }

    global class SessionResponse {
        global String sessionId;
        global SessionResponse(String id) { this.sessionId = id; }
    }

    global class MessageResponse {
        global String reply;
        global MessageResponse(String reply) { this.reply = reply; }
    }

    global class ResolveResponse {
        global Boolean found;
        global String contactId;
        global String matchedName;
        global ResolveResponse(Boolean found, String contactId, String matchedName) {
            this.found = found;
            this.contactId = contactId;
            this.matchedName = matchedName;
        }
    }

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String action = lastSegment(req.requestURI);
        String rawBody = (req.requestBody == null) ? '' : req.requestBody.toString();

        try {
            Map<String, Object> input = String.isBlank(rawBody)
                ? new Map<String, Object>()
                : (Map<String, Object>) JSON.deserializeUntyped(rawBody);

            if (action == 'session') {
                String contactId = str(input.get('contactId'));
                String sessionId = AgentApiService.startSession(contactId);
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(new SessionResponse(sessionId)));

            } else if (action == 'message') {
                String sessionId = str(input.get('sessionId'));
                String message = str(input.get('message'));
                Integer sequenceId = input.get('sequenceId') == null
                    ? null
                    : Integer.valueOf(String.valueOf(input.get('sequenceId')));
                String reply = AgentApiService.sendMessage(sessionId, message, sequenceId);
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(new MessageResponse(reply)));

            } else if (action == 'resolve') {
                String name = str(input.get('name'));
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(resolveContact(name)));

            } else {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new ErrorResponse('Unknown action: ' + action)));
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ErrorResponse(e.getMessage())));
        }
    }

    private static ResolveResponse resolveContact(String name) {
        if (String.isBlank(name)) {
            return new ResolveResponse(false, null, null);
        }
        List<Contact> contacts = new ContactFinder().byName(name.trim());
        if (contacts.isEmpty()) {
            return new ResolveResponse(false, null, null);
        }
        return new ResolveResponse(true, contacts[0].Id, contacts[0].Name);
    }

    /**
     * Runs the Contact lookup without sharing so the Site guest user can match a
     * customer by name (guest users are blocked from "View All" and are heavily
     * sharing-restricted). Object-level read is still enforced via the permission set.
     *
     * Accepts natural phrasing like "My name is Alex Morgan" by stripping common
     * lead-in phrases and punctuation, then matching the whole cleaned name and,
     * failing that, every significant word.
     */
    private without sharing class ContactFinder {
        List<Contact> byName(String rawName) {
            String cleaned = cleanName(rawName);
            if (String.isBlank(cleaned)) {
                return new List<Contact>();
            }

            // 1) Try the cleaned name as a whole.
            String full = '%' + cleaned + '%';
            List<Contact> hits = [
                SELECT Id, Name
                FROM Contact
                WHERE Name LIKE :full
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!hits.isEmpty()) {
                return hits;
            }

            // 2) Fall back to matching every significant word (handles extra words
            //    or different ordering).
            List<String> clauses = new List<String>();
            for (String word : cleaned.split(' ')) {
                if (word.length() >= 2) {
                    clauses.add('Name LIKE \'%' + String.escapeSingleQuotes(word) + '%\'');
                }
            }
            if (clauses.isEmpty()) {
                return new List<Contact>();
            }
            String soql = 'SELECT Id, Name FROM Contact WHERE '
                + String.join(clauses, ' AND ')
                + ' ORDER BY CreatedDate ASC LIMIT 1';
            return Database.query(soql);
        }

        String cleanName(String raw) {
            if (String.isBlank(raw)) {
                return '';
            }
            // Lowercase and replace any punctuation with spaces (LIKE is
            // case-insensitive, so lowercase still matches mixed-case names).
            String s = raw.toLowerCase().replaceAll('[^a-z0-9\\s]', ' ');
            s = s.trim().replaceAll('\\s+', ' ');

            List<String> leadIns = new List<String>{
                'my name is', 'the name is', 'name is', 'i am', 'i m', 'im',
                'this is', 'it is', 'it s', 'its', 'call me', 'hello', 'hey', 'hi'
            };
            Boolean changed = true;
            while (changed) {
                changed = false;
                for (String lead : leadIns) {
                    if (s == lead) {
                        return '';
                    }
                    if (s.startsWith(lead + ' ')) {
                        s = s.substring(lead.length() + 1).trim();
                        changed = true;
                        break;
                    }
                }
            }
            return s.replaceAll('\\s+', ' ').trim();
        }
    }

    private static String lastSegment(String uri) {
        if (String.isBlank(uri)) { return ''; }
        String trimmed = uri.endsWith('/') ? uri.substring(0, uri.length() - 1) : uri;
        Integer idx = trimmed.lastIndexOf('/');
        return idx < 0 ? trimmed : trimmed.substring(idx + 1);
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}
