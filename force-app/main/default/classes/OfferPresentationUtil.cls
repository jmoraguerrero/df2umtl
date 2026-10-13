/**
 * Shared formatting for offer bullets used by GetOffersForContact and GetOffersForCustomer.
 */
public with sharing class OfferPresentationUtil {
    public static String formatOffer(Offer__c o) {
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
