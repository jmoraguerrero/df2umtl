/**
 * Agentforce custom action: entry point for the swag quiz.
 *
 * Runs deterministically when the agent enters the quiz. It echoes the resolved
 * contact id back to the agent (so the agent can pass it to Record Swag Answer) and
 * reports whether the contact has already completed the quiz, in which case it returns
 * the swag they already won so the agent can show it instead of letting them retake.
 *
 * Exposed to Agent Script as @actions.swag_begin (target apex://SwagQuizBegin).
 */
public with sharing class SwagQuizBegin {

    public class Request {
        @InvocableVariable(
            required=false
            label='Contact Id'
            description='The Salesforce Contact Id of the connected customer taking the quiz.'
        )
        public String contactId;
    }

    public class Response {
        @InvocableVariable(label='Contact Id Echo' description='The contact id echoed back for the agent to reuse when recording answers.')
        public String contactIdEcho;
        @InvocableVariable(label='Already Completed' description='1 when the contact already finished the quiz (show the prior result, no retake), otherwise 0.')
        public Integer alreadyCompleted;
        @InvocableVariable(label='Result Text' description='The swag the contact already won, if they have already completed the quiz.')
        public String resultText;
        @InvocableVariable(label='Swag Name' description='Name of the swag already won, if any.')
        public String swagName;
    }

    @InvocableMethod(
        label='Begin Swag Quiz'
        description='Starts (or resumes) the swag quiz for a contact and reports whether it was already completed.'
    )
    public static List<Response> begin(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            SwagQuizService.Result res = SwagQuizService.status(req == null ? null : req.contactId);
            Response out = new Response();
            out.contactIdEcho = res.contactIdEcho;
            out.alreadyCompleted = res.alreadyCompleted;
            out.resultText = res.resultText;
            out.swagName = res.swagName;
            responses.add(out);
        }
        return responses;
    }
}
