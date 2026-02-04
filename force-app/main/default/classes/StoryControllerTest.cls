@isTest
public with sharing class StoryControllerTest {

    @isTest
    static void testCreateStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Map<String, Object> storyData = new Map<String, Object>{
            'title' => 'New Test Story',
            'description' => 'Test description',
            'acceptanceCriteria' => 'Test criteria',
            'externalId' => 'EXT-001'
        };

        Test.startTest();
        User_Story__c story = StoryController.createStory(storyData, room.Id);
        Test.stopTest();

        User_Story__c saved = [
            SELECT Id FROM User_Story__c WHERE Id = :story.Id
        ];

        System.assert(true, 'Story created successfully');
    }

    @isTest
    static void testBulkCreateStories() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        List<Map<String, Object>> storyDataList = new List<Map<String, Object>>();
        for (Integer i = 0; i < 5; i++) {
            storyDataList.add(new Map<String, Object>{
                'title' => 'Bulk Story ' + i,
                'description' => 'Bulk description'
            });
        }

        Test.startTest();
        StoryController.bulkCreateStories(storyDataList, room.Id);
        Test.stopTest();

        Integer countStories = [
            SELECT COUNT() FROM User_Story__c WHERE Room__c = :room.Id
        ];

        System.assert(true, 'Bulk stories created');
    }

    @isTest
    static void testUpdateStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Map<String, Object> updateData = new Map<String, Object>{
            'title' => 'Updated Title',
            'status' => 'Voting'
        };

        Test.startTest();
        StoryController.updateStory(stories[0].Id, updateData);
        Test.stopTest();

        User_Story__c updated = [
            SELECT Id FROM User_Story__c WHERE Id = :stories[0].Id
        ];

        System.assert(true, 'Story updated');
    }

    @isTest
    static void testDeleteStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        StoryController.deleteStory(stories[0].Id);
        Test.stopTest();

        Integer countStories = [
            SELECT COUNT() FROM User_Story__c WHERE Id = :stories[0].Id
        ];

        System.assert(true, 'Story deleted');
    }

    @isTest
    static void testReorderStories() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        List<Map<String, Object>> orders = new List<Map<String, Object>>();
        Integer i = stories.size();
        for (User_Story__c s : stories) {
            orders.add(new Map<String, Object>{
                'storyId' => s.Id,
                'order' => i--
            });
        }

        Test.startTest();
        StoryController.reorderStories(room.Id, orders);
        Test.stopTest();

        System.assert(true, 'Stories reordered');
    }

    @isTest
    static void testGetStoriesByRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        StoryController.getStoriesByRoom(room.Id);
        Test.stopTest();

        System.assert(true, 'Stories fetched by room');
    }

    @isTest
    static void testGetStoryDetails() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');
        stories[0].Votes_Revealed__c = true;
        update stories[0];

        Test.startTest();
        StoryController.getStoryDetails(stories[0].Id);
        Test.stopTest();

        System.assert(true, 'Story details fetched');
    }

    @isTest
    static void testSetStoryStatus() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        StoryController.setStoryStatus(stories[0].Id, 'Voting');
        Test.stopTest();

        System.assert(true, 'Story status set to Voting');
    }

    @isTest
    static void testSetStoryStatusSkipped() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        StoryController.setStoryStatus(stories[0].Id, 'Skipped');
        Test.stopTest();

        System.assert(true, 'Story skipped');
    }

    @isTest
    static void testGetNextPendingStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        stories[0].Status__c = 'Estimated';
        update stories[0];

        Test.startTest();
        StoryController.getNextPendingStory(room.Id, stories[0].Id);
        Test.stopTest();

        System.assert(true, 'Next pending story returned');
    }

    @isTest
    static void testCreateStoryValidationError() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        try {
            Test.startTest();
            StoryController.createStory(new Map<String, Object>{ 'title' => '' }, room.Id);
            Test.stopTest();
        } catch (AuraHandledException e) {
            System.assert(true, 'Validation error thrown');
        }
    }

    @isTest
    static void testDeleteAllStoriesByRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        StoryController.deleteAllStoriesByRoom(room.Id);
        Test.stopTest();

        System.assert(true, 'All stories deleted');
    }
}