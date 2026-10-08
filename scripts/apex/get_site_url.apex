for (Domain dm : [SELECT Domain FROM Domain]) {
    System.debug('DOMAIN >>> ' + dm.Domain);
}
for (DomainSite ds : [SELECT Domain.Domain, PathPrefix FROM DomainSite]) {
    System.debug('SITE URL >>> https://' + ds.Domain.Domain + (ds.PathPrefix == null ? '' : ds.PathPrefix));
}
