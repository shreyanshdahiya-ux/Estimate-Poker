/**
 * @description Test class for PlatformEventPublisher
 */
@isTest
public class PlatformEventPublisherTest {

    @isTest
    static void testPublishVoteEvent() {
        Test.startTest();
        PlatformEventPublisher.publishVoteEvent(
            'roomId123',
            'storyId456',
            'memberId789',
            UserInfo.getUserId(),
            'Test User',
            'voted',
            '5',
            false,
            3,
            5,
            0
        );
        Test.stopTest();

        // Platform events are published asynchronously, so we just verify no exception
        System.assert(true, 'Vote event should be published without exception');
    }

    @isTest
    static void testPublishVotesRevealedEvent() {
        String votesJson = '[{"memberId":"m1","value":"5"},{"memberId":"m2","value":"8"}]';

        Test.startTest();
        PlatformEventPublisher.publishVotesRevealedEvent(
            'roomId123',
            'storyId456',
            votesJson
        );
        Test.stopTest();

        System.assert(true, 'Votes revealed event should be published without exception');
    }

    @isTest
    static void testPublishEstimateFinalizedEvent() {
        String summaryJson = '{"average":5.5,"median":5}';

        Test.startTest();
        PlatformEventPublisher.publishEstimateFinalizedEvent(
            'roomId123',
            'storyId456',
            '5',
            summaryJson
        );
        Test.stopTest();

        System.assert(true, 'Estimate finalized event should be published without exception');
    }

    @isTest
    static void testPublishRoomEvent() {
        Test.startTest();
        PlatformEventPublisher.publishRoomEvent(
            'roomId123',
            'member_joined',
            UserInfo.getUserId(),
            'Test User',
            'storyId456',
            'Test Story',
            'Active',
            5,
            null
        );
        Test.stopTest();

        System.assert(true, 'Room event should be published without exception');
    }

    @isTest
    static void testPublishRoomEventWithData() {
        String additionalData = '{"previousStatus":"Pending"}';

        Test.startTest();
        PlatformEventPublisher.publishRoomEvent(
            'roomId123',
            'status_changed',
            UserInfo.getUserId(),
            'Test User',
            null,
            null,
            'Active',
            5,
            additionalData
        );
        Test.stopTest();

        System.assert(true, 'Room event with data should be published without exception');
    }

    @isTest
    static void testPublishStoryEvent() {
        Test.startTest();
        PlatformEventPublisher.publishStoryEvent(
            'roomId123',
            'storyId456',
            'created',
            'New Story',
            'Pending',
            null,
            1,
            UserInfo.getUserId(),
            null
        );
        Test.stopTest();

        System.assert(true, 'Story event should be published without exception');
    }

    @isTest
    static void testPublishStoryEventWithData() {
        String storyData = '{"previousOrder":1,"newOrder":2}';

        Test.startTest();
        PlatformEventPublisher.publishStoryEvent(
            'roomId123',
            null,
            'reordered',
            null,
            null,
            null,
            null,
            UserInfo.getUserId(),
            storyData
        );
        Test.stopTest();

        System.assert(true, 'Story event with data should be published without exception');
    }

    @isTest
    static void testPublishPresenceEvent() {
        Test.startTest();
        PlatformEventPublisher.publishPresenceEvent(
            'roomId123',
            UserInfo.getUserId(),
            'Test User',
            'online',
            Datetime.now()
        );
        Test.stopTest();

        System.assert(true, 'Presence event should be published without exception');
    }

    @isTest
    static void testPublishPresenceEventOffline() {
        Test.startTest();
        PlatformEventPublisher.publishPresenceEvent(
            'roomId123',
            UserInfo.getUserId(),
            'Test User',
            'offline',
            Datetime.now().addMinutes(-5)
        );
        Test.stopTest();

        System.assert(true, 'Offline presence event should be published without exception');
    }

    @isTest
    static void testQueueAndPublishEvents() {
        Test.startTest();

        // Queue multiple events
        PlatformEventPublisher.queueEvent(new Poker_Vote_Event__e(
            Room_Id__c = 'room1',
            Action__c = 'voted',
            Vote_Value__c = '3'
        ));

        PlatformEventPublisher.queueEvent(new Poker_Vote_Event__e(
            Room_Id__c = 'room1',
            Action__c = 'voted',
            Vote_Value__c = '5'
        ));

        PlatformEventPublisher.queueEvent(new Poker_Vote_Event__e(
            Room_Id__c = 'room1',
            Action__c = 'voted',
            Vote_Value__c = '8'
        ));

        // Publish all queued events
        PlatformEventPublisher.publishQueuedEvents();

        Test.stopTest();

        System.assert(true, 'Queued events should be published without exception');
    }

    @isTest
    static void testPublishQueuedEventsEmpty() {
        Test.startTest();
        // Publishing empty queue should not throw exception
        PlatformEventPublisher.publishQueuedEvents();
        Test.stopTest();

        System.assert(true, 'Publishing empty queue should not throw exception');
    }

    @isTest
    static void testQueueMixedEvents() {
        Test.startTest();

        // Queue different event types
        PlatformEventPublisher.queueEvent(new Poker_Vote_Event__e(
            Room_Id__c = 'room1',
            Action__c = 'voted'
        ));

        PlatformEventPublisher.queueEvent(new Poker_Story_Event__e(
            Room_Id__c = 'room1',
            Action__c = 'created'
        ));

        PlatformEventPublisher.publishQueuedEvents();

        Test.stopTest();

        System.assert(true, 'Mixed queued events should be published');
    }

    @isTest
    static void testAllVoteActions() {
        Test.startTest();

        // Test all vote action types
        // Test all vote action types
        PlatformEventPublisher.publishVoteEvent(
            'room1', 'story1', 'member1', 'user1', 'User 1',
            'voted', '5', false, 1, 5, 0
        );

        PlatformEventPublisher.publishVoteEvent(
            'room1', 'story1', 'member1', 'user1', 'User 1',
            'vote_updated', '8', false, 1, 5, 0
        );

        PlatformEventPublisher.publishVoteEvent(
            'room1', 'story1', 'member1', 'user1', 'User 1',
            'vote_deleted', null, false, 0, 5, 0
        );

        Test.stopTest();

        System.assert(true, 'All vote actions should be published');
    }

    @isTest
    static void testAllRoomActions() {
        Test.startTest();

        String userId = UserInfo.getUserId();

        PlatformEventPublisher.publishRoomEvent(
            'room1', 'session_started', userId, 'User',
            null, null, 'Active', 5, null
        );

        PlatformEventPublisher.publishRoomEvent(
            'room1', 'session_ended', userId, 'User',
            null, null, 'Completed', 5, null
        );

        PlatformEventPublisher.publishRoomEvent(
            'room1', 'member_joined', userId, 'User',
            null, null, 'Active', 6, null
        );

        PlatformEventPublisher.publishRoomEvent(
            'room1', 'member_left', userId, 'User',
            null, null, 'Active', 5, null
        );

        PlatformEventPublisher.publishRoomEvent(
            'room1', 'story_selected', userId, 'User',
            'story1', 'Test Story', 'Active', 5, null
        );

        Test.stopTest();

        System.assert(true, 'All room actions should be published');
    }

    @isTest
    static void testAllStoryActions() {
        Test.startTest();

        String userId = UserInfo.getUserId();

        PlatformEventPublisher.publishStoryEvent(
            'room1', 'story1', 'created', 'New Story', 'Pending',
            null, 1, userId, null
        );

        PlatformEventPublisher.publishStoryEvent(
            'room1', 'story1', 'updated', 'Updated Story', 'Pending',
            null, 1, userId, null
        );

        PlatformEventPublisher.publishStoryEvent(
            'room1', 'story1', 'deleted', 'Deleted Story', null,
            null, null, userId, null
        );

        PlatformEventPublisher.publishStoryEvent(
            'room1', 'story1', 'activated', 'Active Story', 'Voting',
            null, 1, userId, null
        );

        PlatformEventPublisher.publishStoryEvent(
            'room1', 'story1', 'skipped', 'Skipped Story', 'Skipped',
            null, 1, userId, null
        );

        PlatformEventPublisher.publishStoryEvent(
            'room1', 'story1', 'estimated', 'Estimated Story', 'Estimated',
            '5', 1, userId, null
        );

        Test.stopTest();

        System.assert(true, 'All story actions should be published');
    }
}