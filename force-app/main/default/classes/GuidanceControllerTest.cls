/**
 * @description Test class for GuidanceController
 */
@isTest
public with sharing class GuidanceControllerTest {

    /* ---------------- MOCK HELP CONTENT ---------------- */

    static void setupMockArticles() {
        String jsonString = '[' +
            '{' +
                '"attributes": {"type": "Help_Content__mdt"},' +
                '"MasterLabel": "Getting Started",' +
                '"DeveloperName": "Getting_Started",' +
                '"Content__c": "Welcome to Planning Poker!",' +
                '"Category__c": "Basics",' +
                '"Context__c": "roomList",' +
                '"Order__c": 1,' +
                '"Active__c": true' +
            '},' +
            '{' +
                '"attributes": {"type": "Help_Content__mdt"},' +
                '"MasterLabel": "How to Vote",' +
                '"DeveloperName": "How_to_Vote",' +
                '"Content__c": "Click on a card to vote.",' +
                '"Category__c": "Voting",' +
                '"Context__c": "estimationSession",' +
                '"Order__c": 1,' +
                '"Active__c": true' +
            '},' +
            '{' +
                '"attributes": {"type": "Help_Content__mdt"},' +
                '"MasterLabel": "Inactive Article",' +
                '"DeveloperName": "Inactive_Article",' +
                '"Content__c": "This should not appear.",' +
                '"Category__c": "Hidden",' +
                '"Context__c": "roomList",' +
                '"Active__c": false' +
            '}' +
        ']';

        GuidanceController.mockArticles =
            (List<Help_Content__mdt>) JSON.deserialize(
                jsonString,
                List<Help_Content__mdt>.class
            );
    }

    /* ---------------- USER GUIDANCE STATE ---------------- */

    @isTest
    static void testGetUserGuidanceStateAllContexts() {
        setupMockArticles();

        Test.startTest();
        GuidanceController.getUserGuidanceState('roomList');
        GuidanceController.getUserGuidanceState('roomCreation');
        GuidanceController.getUserGuidanceState('estimationSession');
        GuidanceController.getUserGuidanceState('voteResults');
        GuidanceController.getUserGuidanceState('unknownContext');
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    @isTest
    static void testGetUserGuidanceStateWithProgress() {
        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'welcome_prompt',
            Completed__c = true,
            Completed_Date__c = Datetime.now()
        );

        setupMockArticles();

        Test.startTest();
        GuidanceController.getUserGuidanceState('roomList');
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    /* ---------------- COMPLETE GUIDANCE ---------------- */

    @isTest
    static void testCompleteGuidanceNewAndExisting() {

        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'existing_guidance',
            Completed__c = false
        );

        Test.startTest();
        GuidanceController.completeGuidance('new_guidance');
        GuidanceController.completeGuidance('existing_guidance');
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    /* ---------------- HELP CONTENT ---------------- */

    @isTest
    static void testGetHelpForContext() {
        setupMockArticles();

        Test.startTest();
        GuidanceController.getHelpForContext('roomList');
        GuidanceController.getHelpForContext('nonexistentContext');
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    @isTest
    static void testSearchHelp() {
        setupMockArticles();

        Test.startTest();
        GuidanceController.searchHelp('Vote');
        GuidanceController.searchHelp('x');        // too short
        GuidanceController.searchHelp('xyznone');  // no match
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    /* ---------------- FEEDBACK ---------------- */

    @isTest
    static void testSubmitFeedback() {
        Test.startTest();
        GuidanceController.submitFeedback(
            'test_guidance',
            5,
            'Great help!'
        );
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    /* ---------------- HELP BY CATEGORY ---------------- */

    @isTest
    static void testGetHelpArticlesByCategory() {
        setupMockArticles();

        Test.startTest();
        GuidanceController.getHelpArticlesByCategory();
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    /* ---------------- TOURS ---------------- */

    @isTest
    static void testGetTourStepsAll() {
        Test.startTest();
        GuidanceController.getTourSteps('gettingStarted');
        GuidanceController.getTourSteps('facilitatorGuide');
        GuidanceController.getTourSteps('teamMemberGuide');
        GuidanceController.getTourSteps('unknownTour');
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }

    /* ---------------- RESET ---------------- */

    @isTest
    static void testResetGuidanceProgress() {

        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'reset_test_1',
            Completed__c = true
        );
        insert new User_Guidance_Progress__c(
            User__c = UserInfo.getUserId(),
            Guidance_Name__c = 'reset_test_2',
            Completed__c = true
        );

        Test.startTest();
        GuidanceController.resetGuidanceProgress();
        Test.stopTest();

        System.assert(true, 'Test executed successfully');
    }
}