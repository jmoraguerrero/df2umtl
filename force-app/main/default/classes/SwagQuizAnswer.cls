/**
 * Agentforce custom action: records the customer's latest message as their answer to
 * the current swag quiz question and advances the quiz. When every question has been
 * answered it scores the answers and awards the matching swag band.
 *
 * The agent calls this each turn, passing the contact id (from Begin Swag Quiz) and the
 * customer's latest message. The returned Reply Text is what the agent should say next.
 *
 * Exposed to Agent Script as @actions.record_swag_answer (target apex://SwagQuizAnswer).
 */
public with sharing class SwagQuizAnswer {

    public class Request {
        @InvocableVariable(
            required=false
            label='Contact Id'
            description='The Salesforce Contact Id of the connected customer taking the quiz.'
        )
        public String contactId;
        @InvocableVariable(
            required=false
            label='User Message'
            description='The customer\'s latest message, word for word, treated as their answer to the current question.'
        )
        public String userMessage;
    }

    public class Response {
        @InvocableVariable(label='Reply Text' description='Exactly what the agent should present next: the next question (with options) or the final result.')
        public String replyText;
        @InvocableVariable(label='Done' description='1 when the quiz is finished and a swag has been awarded, otherwise 0.')
        public Integer done;
        @InvocableVariable(label='Already Completed' description='1 when the contact had already finished the quiz before this turn.')
        public Integer alreadyCompleted;
        @InvocableVariable(label='Swag Name' description='Name of the awarded swag, when the quiz is done.')
        public String swagName;
        @InvocableVariable(label='Total Questions' description='Total number of questions in the quiz.')
        public Integer totalQuestions;
        @InvocableVariable(label='Question Number' description='1-based number of the question being asked (or the total when the quiz is done).')
        public Integer questionNumber;
    }

    @InvocableMethod(
        label='Record Swag Answer'
        description='Records the customer\'s answer, advances the quiz, and awards a swag once all questions are answered.'
    )
    public static List<Response> record(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            SwagQuizService.Result res = SwagQuizService.answer(
                req == null ? null : req.contactId,
                req == null ? null : req.userMessage
            );
            Response out = new Response();
            out.replyText = res.replyText;
            out.done = res.done;
            out.alreadyCompleted = res.alreadyCompleted;
            out.swagName = res.swagName;
            out.totalQuestions = res.totalQuestions;
            out.questionNumber = res.questionNumber;
            responses.add(out);
        }
        return responses;
    }
}
