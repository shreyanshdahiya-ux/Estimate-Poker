/**
 * @description Test class for StoryController
 */
@isTest
private class StoryControllerTest {

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

        System.assertNotEquals(null, story.Id, 'Story should be created');
        System.assertEquals('New Test Story', story.Story_Title__c, 'Title should match');
        System.assertEquals('Pending', story.Status__c, 'Status should be Pending');
    }

    @isTest
    static void testBulkCreateStories() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        List<Map<String, Object>> storyDataList = new List<Map<String, Object>>();
        for (Integer i = 0; i < 5; i++) {
            storyDataList.add(new Map<String, Object>{
                'title' => 'Bulk Story ' + i,
                'description' => 'Bulk description ' + i
            });
        }

        Test.startTest();
        List<User_Story__c> stories = StoryController.bulkCreateStories(storyDataList, room.Id);
        Test.stopTest();

        System.assertEquals(5, stories.size(), 'Should create 5 stories');

        // Verify ordering
        for (Integer i = 0; i < stories.size(); i++) {
            System.assertNotEquals(null, stories[i].Story_Order__c, 'Each story should have an order');
        }
    }

    @isTest
    static void testUpdateStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Map<String, Object> updateData = new Map<String, Object>{
            'title' => 'Updated Title',
            'description' => 'Updated Description',
            'status' => 'Voting'
        };

        Test.startTest();
        User_Story__c updatedStory = StoryController.updateStory(stories[0].Id, updateData);
        Test.stopTest();

        System.assertEquals('Updated Title', updatedStory.Story_Title__c, 'Title should be updated');
        System.assertEquals('Voting', updatedStory.Status__c, 'Status should be updated');
    }

    @isTest
    static void testDeleteStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Id storyId = stories[0].Id;

        Test.startTest();
        StoryController.deleteStory(storyId);
        Test.stopTest();

        List<User_Story__c> remaining = [SELECT Id FROM User_Story__c WHERE Id = :storyId];
        System.assertEquals(0, remaining.size(), 'Story should be deleted');
    }

    @isTest
    static void testReorderStories() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        List<Map<String, Object>> storyOrders = new List<Map<String, Object>>();
        for (Integer i = 0; i < stories.size(); i++) {
            storyOrders.add(new Map<String, Object>{
                'storyId' => stories[i].Id,
                'order' => stories.size() - i // Reverse order
            });
        }

        Test.startTest();
        StoryController.reorderStories(room.Id, storyOrders);
        Test.stopTest();

        User_Story__c reorderedStory = [SELECT Story_Order__c FROM User_Story__c WHERE Id = :stories[0].Id];
        System.assertEquals(stories.size(), reorderedStory.Story_Order__c, 'Order should be reversed');
    }

    @isTest
    static void testGetStoriesByRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        List<User_Story__c> stories = StoryController.getStoriesByRoom(room.Id);
        Test.stopTest();

        System.assertEquals(5, stories.size(), 'Should return 5 stories from setup');
    }

    @isTest
    static void testGetStoryDetails() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        // Add a vote and reveal it
        TestDataFactory.createVote(stories[0].Id, member.Id, '5');
        stories[0].Votes_Revealed__c = true;
        update stories[0];

        Test.startTest();
        Map<String, Object> details = StoryController.getStoryDetails(stories[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, details, 'Details should not be null');
        System.assertNotEquals(null, details.get('story'), 'Should contain story');
        System.assertNotEquals(null, details.get('votes'), 'Should contain votes');
        System.assertNotEquals(null, details.get('scaleValues'), 'Should contain scale values');
    }

    @isTest
    static void testSetStoryStatus() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        StoryController.setStoryStatus(stories[0].Id, 'Voting');
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c FROM User_Story__c WHERE Id = :stories[0].Id];
        System.assertEquals('Voting', updated.Status__c, 'Status should be Voting');
    }

    @isTest
    static void testSetStoryStatusSkipped() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        StoryController.setStoryStatus(stories[0].Id, 'Skipped');
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c FROM User_Story__c WHERE Id = :stories[0].Id];
        System.assertEquals('Skipped', updated.Status__c, 'Status should be Skipped');
    }

    @isTest
    static void testGetNextPendingStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        // Mark first story as Estimated
        stories[0].Status__c = 'Estimated';
        update stories[0];

        Test.startTest();
        User_Story__c nextStory = StoryController.getNextPendingStory(room.Id, stories[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, nextStory, 'Should return next pending story');
        System.assertEquals('Pending', nextStory.Status__c, 'Next story should be pending');
    }

    @isTest
    static void testGetNextPendingStoryNoCurrentStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        User_Story__c nextStory = StoryController.getNextPendingStory(room.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, nextStory, 'Should return first pending story');
    }

    @isTest
    static void testCreateStoryWithValidationError() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Map<String, Object> storyData = new Map<String, Object>{
            'title' => '' // Empty title should fail validation
        };

        Test.startTest();
        try {
            StoryController.createStory(storyData, room.Id);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('title'), 'Error should mention title');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteAllStoriesByRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        StoryController.deleteAllStoriesByRoom(room.Id);
        Test.stopTest();

        List<User_Story__c> remaining = [SELECT Id FROM User_Story__c WHERE Room__c = :room.Id];
        System.assertEquals(0, remaining.size(), 'All stories should be deleted');
    }
}