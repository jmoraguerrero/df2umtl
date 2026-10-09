/**
 * Stateful engine for the conversational "win some swag" quiz.
 *
 * The agent drives the quiz conversationally, but all state lives here so the
 * flow is deterministic and reliable:
 *   - status(contactId): reports whether the contact already completed the quiz
 *     (no retakes) and echoes the resolved contact id back to the agent.
 *   - answer(contactId, userMessage): records the customer's latest message as the
 *     answer to the current question, advances the quiz, and - once every question
 *     is answered - scores the answers and awards the matching Swag band.
 *
 * One Swag_Response__c record is kept per contact; Answers__c holds a JSON array of
 * the answers so far, and Completed__c marks the quiz as finished.
 */
public with sharing class SwagQuizService {

    /** Shared result shape returned to both invocable wrappers. */
    public class Result {
        public String contactIdEcho;
        public Integer alreadyCompleted = 0; // 1 when the quiz was already finished
        public Integer done = 0;             // 1 when the quiz is finished (now or before)
        public String replyText;             // the next thing the agent should say
        public String resultText;            // the final / already-won result text
        public String swagName;
        public Integer totalQuestions = 0;   // total active questions in the quiz
        public Integer questionNumber = 0;    // 1-based number of the question being asked (or total when done)
    }

    /** A single recorded answer, serialized into Swag_Response__c.Answers__c. */
    public class Answer {
        public String questionId;
        public String label;
        public Integer score;
    }

    /** A parsed option from Swag_Question__c.Options__c. */
    public class Option {
        public String label;
        public Integer score;
    }

    /**
     * Entry status: does NOT advance the quiz. Echoes the contact id and reports
     * whether the contact has already completed the quiz (so we can show their prior
     * result instead of letting them retake it).
     */
    public static Result status(String contactId) {
        Result r = new Result();
        r.contactIdEcho = contactId;
        if (String.isBlank(contactId) || !(contactId instanceof Id)) {
            r.replyText = 'I could not identify your account, so I can\'t start the quiz right now.';
            return r;
        }
        Swag_Response__c existing = findResponse((Id) contactId);
        if (existing != null && existing.Completed__c) {
            r.alreadyCompleted = 1;
            r.done = 1;
            r.resultText = buildResultText(existing);
            r.swagName = existing.Assigned_Swag__c == null ? null : existing.Assigned_Swag__r.Name;
        }
        return r;
    }

    /**
     * Records the customer's latest message as the answer to the current question and
     * advances the quiz. When all questions are answered, scores and awards a swag.
     */
    public static Result answer(String contactId, String userMessage) {
        Result r = new Result();
        r.contactIdEcho = contactId;
        if (String.isBlank(contactId) || !(contactId instanceof Id)) {
            r.replyText = 'I could not identify your account, so I can\'t run the quiz right now.';
            return r;
        }
        Id cId = (Id) contactId;

        List<Swag_Question__c> questions = getQuestions();
        if (questions.isEmpty()) {
            r.replyText = 'The quiz isn\'t available right now, but I\'m happy to keep helping with your offers!';
            return r;
        }
        r.totalQuestions = questions.size();

        Swag_Response__c resp = findResponse(cId);
        if (resp != null && resp.Completed__c) {
            // Already finished - show the prior result, never retake.
            r.alreadyCompleted = 1;
            r.done = 1;
            r.questionNumber = questions.size();
            r.resultText = buildResultText(resp);
            r.replyText = r.resultText;
            r.swagName = resp.Assigned_Swag__c == null ? null : resp.Assigned_Swag__r.Name;
            return r;
        }
        if (resp == null) {
            resp = new Swag_Response__c(Contact__c = cId, Completed__c = false, Answers__c = '[]');
            insert resp;
        }

        List<Answer> answers = parseAnswers(resp.Answers__c);
        Integer idx = answers.size(); // index of the question we're currently on

        // Try to record the incoming message as the answer to the current question.
        if (String.isNotBlank(userMessage) && idx < questions.size()) {
            Swag_Question__c q = questions[idx];
            Option chosen = matchOption(q, userMessage);
            if (chosen != null) {
                Answer a = new Answer();
                a.questionId = q.Id;
                a.label = chosen.label;
                a.score = chosen.score;
                answers.add(a);
                idx++;
            } else {
                // Couldn't map the message to an option. If no questions have been answered yet, this is
                // just the entry message (e.g. "what swag can I win?"), so present the first question
                // cleanly. Otherwise, gently re-ask the current question.
                resp.Answers__c = JSON.serialize(answers);
                update resp;
                r.questionNumber = idx + 1;
                String prefix = (idx == 0) ? '' : 'Hmm, I didn\'t quite catch that. ';
                r.replyText = prefix + formatQuestion(q, idx + 1, questions.size());
                return r;
            }
        }

        resp.Answers__c = JSON.serialize(answers);

        if (idx < questions.size()) {
            // Still more questions to ask.
            update resp;
            r.questionNumber = idx + 1;
            r.replyText = formatQuestion(questions[idx], idx + 1, questions.size());
            return r;
        }

        // Every question answered - score and award.
        Integer total = 0;
        for (Answer a : answers) {
            total += (a.score == null ? 0 : a.score);
        }
        Swag__c swag = matchSwag(total);
        resp.Total_Score__c = total;
        resp.Completed__c = true;
        resp.Completed_Date__c = System.now();
        resp.Assigned_Swag__c = (swag == null ? null : swag.Id);
        update resp;

        r.done = 1;
        r.questionNumber = questions.size();
        r.swagName = (swag == null ? null : swag.Name);
        r.resultText = buildResultTextFrom(swag, total);
        r.replyText = r.resultText;
        return r;
    }

    // ---- helpers ------------------------------------------------------------

    private static List<Swag_Question__c> getQuestions() {
        return [
            SELECT Id, Question_Text__c, Options__c, Order__c
            FROM Swag_Question__c
            WHERE Active__c = true
            ORDER BY Order__c ASC NULLS LAST, Name ASC
        ];
    }

    private static Swag_Response__c findResponse(Id contactId) {
        List<Swag_Response__c> rows = [
            SELECT Id, Contact__c, Completed__c, Total_Score__c, Answers__c,
                   Assigned_Swag__c, Assigned_Swag__r.Name, Assigned_Swag__r.Description__c,
                   Assigned_Swag__r.Emoji__c
            FROM Swag_Response__c
            WHERE Contact__c = :contactId
            ORDER BY Completed__c DESC, LastModifiedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static List<Answer> parseAnswers(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new List<Answer>();
        }
        try {
            List<Answer> parsed = (List<Answer>) JSON.deserialize(rawJson, List<Answer>.class);
            return parsed == null ? new List<Answer>() : parsed;
        } catch (Exception e) {
            return new List<Answer>();
        }
    }

    private static List<Option> parseOptions(String rawJson) {
        List<Option> options = new List<Option>();
        if (String.isBlank(rawJson)) {
            return options;
        }
        try {
            List<Option> parsed = (List<Option>) JSON.deserialize(rawJson, List<Option>.class);
            if (parsed != null) {
                for (Option o : parsed) {
                    if (o != null && String.isNotBlank(o.label)) {
                        if (o.score == null) {
                            o.score = 0;
                        }
                        options.add(o);
                    }
                }
            }
        } catch (Exception e) {
            // leave options empty on malformed JSON
        }
        return options;
    }

    /**
     * Maps the customer's free-text message to one of the question's options.
     * Accepts a numeric choice (1-based), an exact label, or a case-insensitive
     * partial match in either direction.
     */
    private static Option matchOption(Swag_Question__c q, String userMessage) {
        List<Option> options = parseOptions(q.Options__c);
        if (options.isEmpty()) {
            return null;
        }
        String msg = userMessage.trim().toLowerCase();
        if (String.isBlank(msg)) {
            return null;
        }

        // 1) numeric selection ("1", "2", ...)
        if (msg.isNumeric()) {
            Integer n = Integer.valueOf(msg);
            if (n >= 1 && n <= options.size()) {
                return options[n - 1];
            }
        }

        // 2) exact label match
        for (Option o : options) {
            if (o.label.toLowerCase() == msg) {
                return o;
            }
        }

        // 3) partial match in either direction
        for (Option o : options) {
            String lbl = o.label.toLowerCase();
            if (msg.contains(lbl) || lbl.contains(msg)) {
                return o;
            }
        }
        return null;
    }

    private static String formatQuestion(Swag_Question__c q, Integer qNum, Integer total) {
        List<Option> options = parseOptions(q.Options__c);
        List<String> labels = new List<String>();
        for (Option o : options) {
            labels.add(o.label);
        }
        String text = 'Question ' + qNum + ' of ' + total + ': ';
        text += String.isBlank(q.Question_Text__c) ? '' : q.Question_Text__c.trim();
        if (!labels.isEmpty()) {
            text += '\nOptions: ' + String.join(labels, ' / ');
        }
        return text;
    }

    private static Swag__c matchSwag(Integer total) {
        List<Swag__c> rows = [
            SELECT Id, Name, Description__c, Emoji__c, Min_Score__c, Max_Score__c
            FROM Swag__c
            WHERE Active__c = true
              AND (Min_Score__c = null OR Min_Score__c <= :total)
              AND (Max_Score__c = null OR Max_Score__c >= :total)
            ORDER BY Min_Score__c DESC NULLS LAST
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static String buildResultText(Swag_Response__c resp) {
        Integer total = resp.Total_Score__c == null ? 0 : (Integer) resp.Total_Score__c;
        if (resp.Assigned_Swag__c == null) {
            return 'You\'ve already taken the quiz! Unfortunately there wasn\'t a swag match for your score of ' + total + '.';
        }
        return formatSwag(resp.Assigned_Swag__r.Name, resp.Assigned_Swag__r.Description__c, resp.Assigned_Swag__r.Emoji__c, total);
    }

    private static String buildResultTextFrom(Swag__c swag, Integer total) {
        if (swag == null) {
            return 'Thanks for playing! Your score is ' + total + ', but there isn\'t a swag match for that score right now.';
        }
        return formatSwag(swag.Name, swag.Description__c, swag.Emoji__c, total);
    }

    private static String formatSwag(String name, String description, String emoji, Integer total) {
        String prefix = String.isBlank(emoji) ? '' : emoji + ' ';
        String line = prefix + 'You won: ' + name + '! (score: ' + total + ')';
        if (String.isNotBlank(description)) {
            line += '\n' + description;
        }
        return line;
    }
}
