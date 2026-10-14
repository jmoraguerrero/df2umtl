GetOffersForCustomer.Request req = new GetOffersForCustomer.Request();
GetOffersForCustomer.Response res = GetOffersForCustomer.getOffers(new List<GetOffersForCustomer.Request>{ req })[0];
System.debug('flag=' + res.identifiedFlag + ' summary=' + res.offersSummary);
