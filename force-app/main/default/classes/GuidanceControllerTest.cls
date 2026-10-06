@isTest
public with sharing class GuidanceControllerTest {

    private static User adminUser {
        get {
            if (adminUser == null) {
                adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
            }
            return adminUser;
        }
        set;
    }

    @testSetup
    static void setupData() {
        // Optional baseline data
    }

    @isTest
    static void testGetUserGuidanceState_NewUser() {
        System.runAs(adminUser) {
            Test.startTest();
            Map<String, Object> state = GuidanceController.getUserGuidanceState('roomList');
            Test.stopTest();

            System.assertNotEquals(null, state);
            System.assertEquals(2, (Integer) state.get('totalItems'));
            System.assertEquals(0, (Integer) state.get('completedItems'));
            System.assertEquals(0, (Integer) state.get('progressPercent'));
            System.assertEquals(true, (Boolean) state.get('isFirstTimeUser'));
            
            List<Map<String, Object>> items = (List<Map<String, Object>>) state.get('guidanceItems');
            System.assertEquals(2, items.size());
            System.assertEquals(false, (Boolean) items[0].get('completed'));
        }
    }

    @isTest
    static void testGetUserGuidanceState_ExistingProgress() {
        System.runAs(adminUser) {
            // Mark one as complete
            GuidanceController.completeGuidance('welcome_prompt');

            Test.startTest();
            Map<String, Object> state = GuidanceController.getUserGuidanceState('roomList');
            Test.stopTest();

            System.assertEquals(2, (Integer) state.get('totalItems'));
            System.assertEquals(1, (Integer) state.get('completedItems'));
            System.assertEquals(50, (Integer) state.get('progressPercent'));
            System.assertEquals(false, (Boolean) state.get('isFirstTimeUser'));
        }
    }

    @isTest
    static void testCompleteGuidance_NewAndUpdate() {
        System.runAs(adminUser) {
            Test.startTest();
            // Test New
            GuidanceController.completeGuidance('test_guidance_1');
            
            List<User_Guidance_Progress__c> results = [SELECT Id, Completed__c FROM User_Guidance_Progress__c WHERE Guidance_Name__c = 'test_guidance_1'];
            System.assertEquals(1, results.size());
            System.assertEquals(true, results[0].Completed__c);

            // Test Update
            GuidanceController.completeGuidance('test_guidance_1');
            results = [SELECT Id FROM User_Guidance_Progress__c WHERE Guidance_Name__c = 'test_guidance_1'];
            System.assertEquals(1, results.size(), 'Should not create a duplicate record');
            Test.stopTest();
        }
    }

    @isTest
    static void testGetHelpForContext() {
        System.runAs(adminUser) {
            GuidanceController.mockArticles = new List<Help_Content__mdt>{
                createMockArticle('Article_1', 'How to Create Room', 'Create a room from the button', 'Getting Started', 'roomList', 1, true),
                createMockArticle('Article_2', 'How to Vote', 'Select a card to vote', 'Voting', 'estimationSession', 2, true)
            };

            Test.startTest();
            List<Map<String, Object>> result = GuidanceController.getHelpForContext('roomList');
            Test.stopTest();

            System.assertEquals(2, result.size());
            System.assertEquals('How to Create Room', (String) result[0].get('Name'));
        }
    }

    @isTest
    static void testSearchHelp_Found() {
        System.runAs(adminUser) {
            GuidanceController.mockArticles = new List<Help_Content__mdt>{
                createMockArticle('Article_1', 'How to Create Room', 'Create a room from the button', 'Getting Started', 'roomList', 1, true),
                createMockArticle('Article_2', 'How Voting Works', 'Select a card to vote', 'Voting', 'estimationSession', 2, true)
            };

            Test.startTest();
            List<Map<String, Object>> result = GuidanceController.searchHelp('vote');
            Test.stopTest();

            System.assertEquals(1, result.size());
            System.assertEquals('How Voting Works', (String) result[0].get('Name'));
        }
    }

    @isTest
    static void testSearchHelp_BlankOrShort() {
        System.runAs(adminUser) {
            Test.startTest();
            List<Map<String, Object>> result1 = GuidanceController.searchHelp('');
            List<Map<String, Object>> result2 = GuidanceController.searchHelp('a');
            Test.stopTest();

            System.assertEquals(0, result1.size());
            System.assertEquals(0, result2.size());
        }
    }

    @isTest
    static void testSubmitFeedback() {
        System.runAs(adminUser) {
            Test.startTest();
            GuidanceController.submitFeedback('welcome_prompt', 5, 'Great tutorial!');
            Test.stopTest();

            List<Guidance_Feedback__c> feedback = [SELECT Id, Rating__c, Comments__c FROM Guidance_Feedback__c];
            System.assertEquals(1, feedback.size());
            System.assertEquals(5, feedback[0].Rating__c);
            System.assertEquals('Great tutorial!', feedback[0].Comments__c);
        }
    }

    @isTest
    static void testGetHelpArticlesByCategory() {
        System.runAs(adminUser) {
            GuidanceController.mockArticles = new List<Help_Content__mdt>{
                createMockArticle('Article_1', 'Create Room', 'Help content 1', 'Getting Started', 'roomList', 1, true),
                createMockArticle('Article_2', 'Join Room', 'Help content 2', 'Getting Started', 'roomList', 2, true),
                createMockArticle('Article_3', 'Vote Story', 'Help content 3', 'Voting', 'estimationSession', 1, true)
            };

            Test.startTest();
            Map<String, List<Map<String, Object>>> result = GuidanceController.getHelpArticlesByCategory();
            Test.stopTest();

            System.assertEquals(true, result.containsKey('Getting Started'));
            System.assertEquals(true, result.containsKey('Voting'));
            System.assertEquals(2, result.get('Getting Started').size());
            System.assertEquals(1, result.get('Voting').size());
        }
    }


    @isTest
    static void testGetTourSteps_ValidTour() {
        System.runAs(adminUser) {
            Test.startTest();
            List<Map<String, Object>> steps = GuidanceController.getTourSteps('gettingStarted');
            Test.stopTest();

            System.assertEquals(6, steps.size());
            System.assertEquals('Welcome to Planning Poker', (String) steps[0].get('title'));
        }
    }

    @isTest
    static void testGetTourSteps_InvalidTour() {
        System.runAs(adminUser) {
            Test.startTest();
            List<Map<String, Object>> steps = GuidanceController.getTourSteps('unknownTour');
            Test.stopTest();

            System.assertEquals(0, steps.size());
        }
    }

    @isTest
    static void testResetGuidanceProgress() {
        System.runAs(adminUser) {
            // Setup some progress
            GuidanceController.completeGuidance('test_1');
            GuidanceController.completeGuidance('test_2');
            
            System.assertEquals(2, [SELECT count() FROM User_Guidance_Progress__c]);

            Test.startTest();
            GuidanceController.resetGuidanceProgress();
            Test.stopTest();

            System.assertEquals(0, [SELECT count() FROM User_Guidance_Progress__c]);
        }
    }

    @isTest
    static void testErrorHandling() {
        System.runAs(adminUser) {
            Test.startTest();
            try {
                GuidanceController.submitFeedback(null, null, null);
            } catch (Exception e) {
                System.debug('Caught expected exception: ' + e.getMessage());
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testSearchHelp_InContent() {
        System.runAs(adminUser) {
            GuidanceController.mockArticles = new List<Help_Content__mdt>{
                createMockArticle('Article_1', 'Title', 'Find this keyword in body', 'General', 'context', 1, true)
            };

            Test.startTest();
            List<Map<String, Object>> result = GuidanceController.searchHelp('keyword');
            Test.stopTest();

            System.assertEquals(1, result.size());
            System.assertEquals('Title', (String) result[0].get('Name'));
        }
    }

    @isTest
    static void testSearchHelp_NoMatch() {
        System.runAs(adminUser) {
            GuidanceController.mockArticles = new List<Help_Content__mdt>{
                createMockArticle('Article_1', 'Title', 'Content', 'General', 'context', 1, true)
            };

            Test.startTest();
            List<Map<String, Object>> result = GuidanceController.searchHelp('nomatch');
            Test.stopTest();

            System.assertEquals(0, result.size());
        }
    }

    @isTest
    static void testGetHelpArticlesByCategory_Fallback() {
        System.runAs(adminUser) {
            GuidanceController.mockArticles = new List<Help_Content__mdt>{
                createMockArticle('Article_1', 'No Category', 'Content', null, 'context', 1, true)
            };

            Test.startTest();
            Map<String, List<Map<String, Object>>> result = GuidanceController.getHelpArticlesByCategory();
            Test.stopTest();

            System.assertEquals(true, result.containsKey('General'), 'Should fallback to General');
        }
    }

    @isTest
    static void testGetHelpForContext_Ordering() {
        System.runAs(adminUser) {
            GuidanceController.mockArticles = new List<Help_Content__mdt>{
                createMockArticle('Article_1', 'First', 'Content', 'General', 'roomList', 1, true),
                createMockArticle('Article_2', 'Second', 'Content', 'General', 'roomList', 2, true)
            };

            Test.startTest();
            List<Map<String, Object>> result = GuidanceController.getHelpForContext('roomList');
            Test.stopTest();

            System.assertEquals(2, result.size());
            System.assertEquals('First', (String) result[0].get('Name'));
        }
    }

    private static Help_Content__mdt createMockArticle(
        String developerName,
        String masterLabel,
        String content,
        String category,
        String context,
        Integer orderNum,
        Boolean isActive
    ) {
        Map<String, Object> fields = new Map<String, Object>{
            'DeveloperName' => developerName,
            'MasterLabel' => masterLabel,
            'Content__c' => content,
            'Category__c' => category,
            'Context__c' => context,
            'Order__c' => orderNum,
            'Active__c' => isActive
        };
        return (Help_Content__mdt) JSON.deserialize(JSON.serialize(fields), Help_Content__mdt.class);
    }
}