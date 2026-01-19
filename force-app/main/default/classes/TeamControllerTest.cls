/**
 * @description Test class for TeamController
 */
@isTest
private class TeamControllerTest {

    @isTest
    static void testCreateTeam() {
        Map<String, Object> teamData = new Map<String, Object>{
            'name' => 'New Test Team',
            'description' => 'Test Description',
            'department' => 'Engineering'
        };

        Test.startTest();
        Team__c team = TeamController.createTeam(teamData);
        Test.stopTest();

        System.assertNotEquals(null, team.Id, 'Team should be created');
        System.assertEquals('New Test Team', team.Name, 'Name should match');
        System.assertEquals(true, team.Active__c, 'Team should be active');

        // Verify creator was added as team member
        List<Team_Member__c> members = [SELECT Id, Role__c FROM Team_Member__c WHERE Team__c = :team.Id];
        System.assertEquals(1, members.size(), 'Creator should be added as member');
        System.assertEquals('Scrum Master', members[0].Role__c, 'Creator should be Scrum Master');
    }

    @isTest
    static void testGetAllTeams() {
        TestDataFactory.createTeam('Team 1');
        TestDataFactory.createTeam('Team 2');

        Test.startTest();
        List<Map<String, Object>> teams = TeamController.getAllTeams();
        Test.stopTest();

        System.assert(teams.size() >= 2, 'Should return at least 2 teams');
    }

    @isTest
    static void testGetTeamsForUser() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Team__c team = TestDataFactory.createTeam('User Team');
        TestDataFactory.createTeamMember(team.Id, testUser.Id, 'Developer');

        Test.startTest();
        List<Map<String, Object>> teams = TeamController.getTeamsForUser(testUser.Id);
        Test.stopTest();

        System.assert(teams.size() >= 1, 'Should return teams for user');

        Boolean foundTeam = false;
        for (Map<String, Object> teamMap : teams) {
            if (teamMap.get('id') == team.Id) {
                foundTeam = true;
                System.assertEquals('Developer', teamMap.get('myRole'), 'Role should be Developer');
            }
        }
        System.assert(foundTeam, 'Should find the created team');
    }

    @isTest
    static void testGetTeamsForCurrentUser() {
        Test.startTest();
        List<Map<String, Object>> teams = TeamController.getTeamsForUser(null);
        Test.stopTest();

        // Just verify it doesn't throw an exception
        System.assertNotEquals(null, teams, 'Should return a list');
    }

    @isTest
    static void testGetTeamMembers() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Team__c team = TestDataFactory.createTeam('Member Team');
        TestDataFactory.createTeamMember(team.Id, testUser.Id, 'Developer');

        Test.startTest();
        List<Map<String, Object>> members = TeamController.getTeamMembers(team.Id);
        Test.stopTest();

        System.assert(members.size() >= 1, 'Should return team members');
    }

    @isTest
    static void testAddTeamMember() {
        Team__c team = TestDataFactory.createTeam('Add Member Team');
        User testUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        Test.startTest();
        Team_Member__c member = TeamController.addTeamMember(team.Id, testUser.Id, 'Developer');
        Test.stopTest();

        System.assertNotEquals(null, member.Id, 'Member should be created');
        System.assertEquals('Developer', member.Role__c, 'Role should be Developer');
    }

    @isTest
    static void testAddTeamMemberDefaultRole() {
        Team__c team = TestDataFactory.createTeam('Default Role Team');
        User testUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        Test.startTest();
        Team_Member__c member = TeamController.addTeamMember(team.Id, testUser.Id, null);
        Test.stopTest();

        System.assertEquals('Developer', member.Role__c, 'Default role should be Developer');
    }

    @isTest
    static void testRemoveTeamMember() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Team__c team = TestDataFactory.createTeam('Remove Team');
        Team_Member__c member = TestDataFactory.createTeamMember(team.Id, testUser.Id, 'Developer');

        Test.startTest();
        TeamController.removeTeamMember(member.Id);
        Test.stopTest();

        Team_Member__c updated = [SELECT Active__c FROM Team_Member__c WHERE Id = :member.Id];
        System.assertEquals(false, updated.Active__c, 'Member should be inactive');
    }

    @isTest
    static void testUpdateTeamMemberRole() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Team__c team = TestDataFactory.createTeam('Update Role Team');
        Team_Member__c member = TestDataFactory.createTeamMember(team.Id, testUser.Id, 'Developer');

        Test.startTest();
        TeamController.updateTeamMemberRole(member.Id, 'Scrum Master');
        Test.stopTest();

        Team_Member__c updated = [SELECT Role__c FROM Team_Member__c WHERE Id = :member.Id];
        System.assertEquals('Scrum Master', updated.Role__c, 'Role should be updated');
    }

    @isTest
    static void testUpdateTeam() {
        Team__c team = TestDataFactory.createTeam('Update Team');

        Map<String, Object> updateData = new Map<String, Object>{
            'name' => 'Updated Team Name',
            'description' => 'Updated Description',
            'department' => 'Product'
        };

        Test.startTest();
        Team__c updatedTeam = TeamController.updateTeam(team.Id, updateData);
        Test.stopTest();

        System.assertEquals('Updated Team Name', updatedTeam.Name, 'Name should be updated');
        System.assertEquals('Updated Description', updatedTeam.Description__c, 'Description should be updated');
        System.assertEquals('Product', updatedTeam.Department__c, 'Department should be updated');
    }

    @isTest
    static void testDeactivateTeam() {
        Team__c team = TestDataFactory.createTeam('Deactivate Team');

        Test.startTest();
        TeamController.deactivateTeam(team.Id);
        Test.stopTest();

        Team__c updated = [SELECT Active__c FROM Team__c WHERE Id = :team.Id];
        System.assertEquals(false, updated.Active__c, 'Team should be inactive');
    }

    @isTest
    static void testSearchUsers() {
        Test.startTest();
        List<User> users = TeamController.searchUsers('Test');
        Test.stopTest();

        // Just verify it doesn't throw an exception
        System.assertNotEquals(null, users, 'Should return a list');
    }

    @isTest
    static void testGetTeamDetails() {
        Team__c team = TestDataFactory.createTeam('Details Team');

        Test.startTest();
        Team__c details = TeamController.getTeamDetails(team.Id);
        Test.stopTest();

        System.assertEquals(team.Id, details.Id, 'Should return correct team');
        System.assertEquals('Details Team', details.Name, 'Name should match');
    }

    @isTest
    static void testAddDuplicateTeamMember() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Team__c team = TestDataFactory.createTeam('Duplicate Team');
        TestDataFactory.createTeamMember(team.Id, testUser.Id, 'Developer');

        Test.startTest();
        try {
            TeamController.addTeamMember(team.Id, testUser.Id, 'Scrum Master');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already a member'), 'Should indicate duplicate');
        }
        Test.stopTest();
    }
}