// Help Articles for Teams Context
List<Help_Article__c> articles = new List<Help_Article__c>();

articles.add(new Help_Article__c(
    Name = 'Teams Overview',
    Category__c = 'Teams',
    Content__c = 'Teams allow you to organize groups of estimators for quick room creation. Instead of adding members one by one, you can add an entire team to a room.',
    Context__c = 'teams',
    Order__c = 1,
    Active__c = true
));

articles.add(new Help_Article__c(
    Name = 'Creating a Team',
    Category__c = 'Teams',
    Content__c = 'Click the "New Team" button to create a team. Give it a name, optional description, and department. You\'ll become the team lead automatically.',
    Context__c = 'teams',
    Order__c = 2,
    Active__c = true
));

articles.add(new Help_Article__c(
    Name = 'Managing Members',
    Category__c = 'Teams',
    Content__c = 'Click on a team card to view details. Use the "Add Member" button to search for and invite users. You can remove members or change their roles from the list.',
    Context__c = 'teams',
    Order__c = 3,
    Active__c = true
));

articles.add(new Help_Article__c(
    Name = 'Team Roles',
    Category__c = 'Teams',
    Content__c = 'Team Leads can manage the team structure. Members are regular participants. Departments help categorize teams across the organization.',
    Context__c = 'teams',
    Order__c = 4,
    Active__c = true
));

// Check for existing to avoid duplicates (upsert using external ID if available, otherwise just insert if empty)
List<Help_Article__c> existing = [SELECT Id FROM Help_Article__c WHERE Context__c = 'teams'];
if (existing.isEmpty()) {
    insert articles;
    System.debug('Inserted ' + articles.size() + ' help articles for teams.');
} else {
    System.debug('Help articles for teams already exist. Skipping insertion.');
}
