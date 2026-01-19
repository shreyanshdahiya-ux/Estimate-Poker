/**
 * @description Test class for GuidanceController
 */
@isTest
private class GuidanceControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create help articles
        List<Help_Article__c> articles = new List<Help_Article__c>();
        articles.add(new Help_Article__c(
            Name = 'Getting Started',
            Content__c = 'Welcome to Planning Poker!',
            Category__c = 'Basics',
            Context__c = 'roomList',
            Order__c = 1,
            Active__c = true
        ));
        articles.add(new Help_Article__c(
            Name = 'How to Vote',
            Content__c = 'Click on a card to vote.',
            Category__c = 'Voting',
            Context__c = 'estimationSession',
            Order__c = 1,
            Active__c = true
        ));
        articles.add(new Help_Article__c(
            Name = 'Inactive Article',
            Content__c = 'This should not appear.',
            Category__c = 'Hidden',
            Context__c = 'roomList',
            Active__c = false
        ));
        insert articles;
    }

    @isTest
    static void testGetUserGuidanceStateNewUser() {
        Test.startTest();
        Map<String, Object> state = GuidanceController.getUserGuidanceState('roomList');
        Test.stopTest();

        System.assertNotEquals(null, state, 'Should return state');
        System.assertEquals(true, state.get('isFirstTimeUser'), 'Should be first time user');
        System.assertNotEquals(null, state.get('guidanceItems'), 'Should have guidance items');
    }

    @isTest
    static void testGetUserGuidanceStateWithProgress() {
        // Complete a guidance item
        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'welcome_prompt',
            Completed__c = true,
            Completed_Date__c = Datetime.now()
        );

        Test.startTest();
        Map<String, Object> state = GuidanceController.getUserGuidanceState('roomList');
        Test.stopTest();

        System.assertEquals(false, state.get('isFirstTimeUser'), 'Should not be first time user');
        Integer completed = (Integer) state.get('completedItems');
        System.assert(completed >= 1, 'Should have at least 1 completed item');
    }

    @isTest
    static void testGetUserGuidanceStateUnknownContext() {
        Test.startTest();
        Map<String, Object> state = GuidanceController.getUserGuidanceState('unknownContext');
        Test.stopTest();

        System.assertNotEquals(null, state, 'Should return state');
        List<Map<String, Object>> items = (List<Map<String, Object>>) state.get('guidanceItems');
        System.assertEquals(0, items.size(), 'Should have no items for unknown context');
    }

    @isTest
    static void testCompleteGuidanceNew() {
        Test.startTest();
        GuidanceController.completeGuidance('test_guidance');
        Test.stopTest();

        List<User_Guidance_Progress__c> progress = [
            SELECT Id, Completed__c
            FROM User_Guidance_Progress__c
            WHERE Guidance_Name__c = 'test_guidance'
        ];
        System.assertEquals(1, progress.size(), 'Should create progress record');
        System.assertEquals(true, progress[0].Completed__c, 'Should be completed');
    }

    @isTest
    static void testCompleteGuidanceExisting() {
        // Create existing incomplete progress
        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'existing_guidance',
            Completed__c = false
        );

        Test.startTest();
        GuidanceController.completeGuidance('existing_guidance');
        Test.stopTest();

        User_Guidance_Progress__c progress = [
            SELECT Completed__c, Completed_Date__c
            FROM User_Guidance_Progress__c
            WHERE Guidance_Name__c = 'existing_guidance'
        ];
        System.assertEquals(true, progress.Completed__c, 'Should be completed');
        System.assertNotEquals(null, progress.Completed_Date__c, 'Should have completion date');
    }

    @isTest
    static void testGetHelpForContext() {
        Test.startTest();
        List<Map<String, Object>> articles = GuidanceController.getHelpForContext('roomList');
        Test.stopTest();

        System.assertEquals(1, articles.size(), 'Should return 1 active article for roomList');
        System.assertEquals('Getting Started', (String)articles[0].get('Name'), 'Should return correct article');
    }

    @isTest
    static void testGetHelpForContextNoResults() {
        Test.startTest();
        List<Map<String, Object>> articles = GuidanceController.getHelpForContext('nonexistentContext');
        Test.stopTest();

        System.assertEquals(0, articles.size(), 'Should return empty list');
    }

    @isTest
    static void testSearchHelp() {
        Test.startTest();
        List<Map<String, Object>> results = GuidanceController.searchHelp('Vote');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find 1 article');
        System.assertEquals('How to Vote', (String)results[0].get('Name'), 'Should find voting article');
    }

    @isTest
    static void testSearchHelpNoResults() {
        Test.startTest();
        List<Map<String, Object>> results = GuidanceController.searchHelp('xyznonexistent');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list');
    }

    @isTest
    static void testSubmitFeedback() {
        Test.startTest();
        GuidanceController.submitFeedback('test_guidance', 5, 'Great help!');
        Test.stopTest();

        List<Guidance_Feedback__c> feedback = [
            SELECT Rating__c, Comments__c
            FROM Guidance_Feedback__c
            WHERE Guidance_Name__c = 'test_guidance'
        ];
        System.assertEquals(1, feedback.size(), 'Should create feedback record');
        System.assertEquals(5, feedback[0].Rating__c, 'Rating should be 5');
        System.assertEquals('Great help!', feedback[0].Comments__c, 'Comments should match');
    }

    @isTest
    static void testGetHelpArticlesByCategory() {
        Test.startTest();
        Map<String, List<Map<String, Object>>> articlesByCategory = GuidanceController.getHelpArticlesByCategory();
        Test.stopTest();

        System.assertNotEquals(null, articlesByCategory, 'Should return map');
        System.assert(articlesByCategory.containsKey('Basics'), 'Should have Basics category');
        System.assert(articlesByCategory.containsKey('Voting'), 'Should have Voting category');
        System.assert(!articlesByCategory.containsKey('Hidden'), 'Should not have inactive category');
    }

    @isTest
    static void testGetTourStepsGettingStarted() {
        Test.startTest();
        List<Map<String, Object>> steps = GuidanceController.getTourSteps('gettingStarted');
        Test.stopTest();

        System.assert(steps.size() > 0, 'Should return tour steps');
        Map<String, Object> firstStep = steps[0];
        System.assertEquals(1, firstStep.get('step'), 'First step should be 1');
        System.assertNotEquals(null, firstStep.get('title'), 'Should have title');
        System.assertNotEquals(null, firstStep.get('content'), 'Should have content');
    }

    @isTest
    static void testGetTourStepsFacilitatorGuide() {
        Test.startTest();
        List<Map<String, Object>> steps = GuidanceController.getTourSteps('facilitatorGuide');
        Test.stopTest();

        System.assert(steps.size() > 0, 'Should return facilitator tour steps');
    }

    @isTest
    static void testGetTourStepsTeamMemberGuide() {
        Test.startTest();
        List<Map<String, Object>> steps = GuidanceController.getTourSteps('teamMemberGuide');
        Test.stopTest();

        System.assert(steps.size() > 0, 'Should return team member tour steps');
    }

    @isTest
    static void testGetTourStepsUnknownTour() {
        Test.startTest();
        List<Map<String, Object>> steps = GuidanceController.getTourSteps('unknownTour');
        Test.stopTest();

        System.assertEquals(0, steps.size(), 'Should return empty list for unknown tour');
    }

    @isTest
    static void testResetGuidanceProgress() {
        // Create some progress records
        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'test1',
            Completed__c = true
        );
        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'test2',
            Completed__c = true
        );

        Test.startTest();
        GuidanceController.resetGuidanceProgress();
        Test.stopTest();

        List<User_Guidance_Progress__c> remaining = [
            SELECT Id FROM User_Guidance_Progress__c
            WHERE User__c = :UserInfo.getUserId()
        ];
        System.assertEquals(0, remaining.size(), 'All progress should be deleted');
    }

    @isTest
    static void testGetUserGuidanceStateEstimationSession() {
        Test.startTest();
        Map<String, Object> state = GuidanceController.getUserGuidanceState('estimationSession');
        Test.stopTest();

        System.assertNotEquals(null, state, 'Should return state');
        List<Map<String, Object>> items = (List<Map<String, Object>>) state.get('guidanceItems');
        System.assert(items.size() > 0, 'Should have guidance items for estimation session');
    }

    @isTest
    static void testGetUserGuidanceStateVoteResults() {
        Test.startTest();
        Map<String, Object> state = GuidanceController.getUserGuidanceState('voteResults');
        Test.stopTest();

        System.assertNotEquals(null, state, 'Should return state');
        List<Map<String, Object>> items = (List<Map<String, Object>>) state.get('guidanceItems');
        System.assert(items.size() > 0, 'Should have guidance items for vote results');
    }
}