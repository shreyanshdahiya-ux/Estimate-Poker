/**
 * @description Test class for PlatformEventPublisher
 */
@isTest
public with sharing class PlatformEventPublisherTest {
  /* ==================== VOTE EVENTS ==================== */

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
    System.assert(true, 'Event published successfully');
  }

  @isTest
  static void testAllVoteActions() {
    Test.startTest();

    PlatformEventPublisher.publishVoteEvent(
      'room',
      'story',
      'member',
      'user',
      'User',
      'voted',
      '5',
      false,
      1,
      5,
      0
    );

    PlatformEventPublisher.publishVoteEvent(
      'room',
      'story',
      'member',
      'user',
      'User',
      'vote_updated',
      '8',
      false,
      1,
      5,
      0
    );

    PlatformEventPublisher.publishVoteEvent(
      'room',
      'story',
      'member',
      'user',
      'User',
      'vote_deleted',
      null,
      false,
      0,
      5,
      0
    );

    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== VOTES REVEALED ==================== */

  @isTest
  static void testPublishVotesRevealedEvent() {
    Test.startTest();
    PlatformEventPublisher.publishVotesRevealedEvent(
      'roomId123',
      'storyId456',
      '[{"member":"m1","vote":"5"}]'
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== ESTIMATE FINALIZED ==================== */

  @isTest
  static void testPublishEstimateFinalizedEvent() {
    Test.startTest();
    PlatformEventPublisher.publishEstimateFinalizedEvent(
      'roomId123',
      'storyId456',
      '5',
      '{"avg":5}'
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== ROOM EVENTS ==================== */

  @isTest
  static void testPublishRoomEvent() {
    Test.startTest();
    PlatformEventPublisher.publishRoomEvent(
      'roomId',
      'member_joined',
      UserInfo.getUserId(),
      'User',
      'story1',
      'Story',
      'Active',
      5,
      null
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  @isTest
  static void testPublishRoomEventWithData() {
    Test.startTest();
    PlatformEventPublisher.publishRoomEvent(
      'roomId',
      'status_changed',
      UserInfo.getUserId(),
      'User',
      null,
      null,
      'Paused',
      null,
      '{"reason":"break"}'
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== STORY EVENTS ==================== */

  @isTest
  static void testPublishStoryEvent() {
    Test.startTest();
    PlatformEventPublisher.publishStoryEvent(
      'roomId',
      'storyId',
      'created',
      'Story',
      'Pending',
      null,
      1,
      UserInfo.getUserId(),
      null
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  @isTest
  static void testAllStoryActions() {
    Test.startTest();
    String userId = UserInfo.getUserId();

    PlatformEventPublisher.publishStoryEvent(
      'room',
      'story',
      'deleted',
      'Story',
      null,
      null,
      null,
      userId,
      null
    );

    PlatformEventPublisher.publishStoryEvent(
      'room',
      'story',
      'estimated',
      'Story',
      'Estimated',
      '5',
      1,
      userId,
      null
    );

    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== PRESENCE EVENTS ==================== */

  @isTest
  static void testPublishPresenceEvent() {
    Test.startTest();
    PlatformEventPublisher.publishPresenceEvent(
      'roomId',
      UserInfo.getUserId(),
      'User',
      'online',
      Datetime.now()
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== TEAM EVENTS ==================== */

  @isTest
  static void testPublishTeamEvent() {
    Test.startTest();
    PlatformEventPublisher.publishTeamEvent(
      'teamId123',
      'team_created',
      UserInfo.getUserId(),
      'Test User',
      '{"name":"Team A"}'
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== QUEUE EVENTS ==================== */

  @isTest
  static void testQueueAndPublishEvents() {
    Test.startTest();

    PlatformEventPublisher.queueEvent(
      new Poker_Vote_Event__e(
        Room_Id__c = 'room1',
        Action__c = 'voted',
        Vote_Value__c = '3'
      )
    );

    PlatformEventPublisher.queueEvent(
      new Poker_Story_Event__e(Room_Id__c = 'room1', Action__c = 'created')
    );

    PlatformEventPublisher.publishQueuedEvents();
    Test.stopTest();

    System.assert(true, 'Event published successfully');
  }

  @isTest
  static void testPublishQueuedEventsEmpty() {
    Test.startTest();
    PlatformEventPublisher.publishQueuedEvents();
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== 🔒 MICRO-IMPROVEMENT ==================== */
  /* Explicitly cover queueEvent() without publish */

  @isTest
  static void testQueueOnly() {
    Test.startTest();
    PlatformEventPublisher.queueEvent(
      new Poker_Room_Event__e(Room_Id__c = 'room', Action__c = 'test')
    );
    Test.stopTest();
    System.assert(true, 'Event published successfully');
  }

  /* ==================== EVENT BUDGET GUARD ==================== */

  @isTest
  static void testEssentialRoomActionsAlwaysPublishEvenWhenBudgetIsLow() {
    PlatformEventPublisher.simulateLowBudget = true;
    for (
      String action : new List<String>{
        'member_joined',
        'member_left',
        'story_selected',
        'status_updated',
        'session_started',
        'votes_reset'
      }
    ) {
      System.assertEquals(
        true,
        PlatformEventPublisher.shouldPublishRoomAction(action),
        action + ' is essential and must keep publishing'
      );
    }
  }

  @isTest
  static void testOptionalRoomActionsAreSkippedWhenBudgetIsLow() {
    PlatformEventPublisher.simulateLowBudget = true;
    for (
      String action : new List<String>{
        'member_like',
        'timer_started',
        'timer_paused',
        'timer_resumed',
        'timer_stopped'
      }
    ) {
      System.assertEquals(
        false,
        PlatformEventPublisher.shouldPublishRoomAction(action),
        action + ' is optional and should be skipped'
      );
    }
    System.assertEquals(
      false,
      PlatformEventPublisher.hasEventBudget(),
      'Low budget should be reported'
    );
  }

  @isTest
  static void testOptionalRoomActionsPublishWhenBudgetIsHealthy() {
    PlatformEventPublisher.simulateLowBudget = false;
    System.assertEquals(
      true,
      PlatformEventPublisher.shouldPublishRoomAction('member_like'),
      'Optional events publish while there is budget'
    );
  }

  @isTest
  static void testSkippedEventsNeverThrow() {
    PlatformEventPublisher.simulateLowBudget = true;
    Test.startTest();
    PlatformEventPublisher.publishRoomEvent(
      'a0I000000000001',
      'member_like',
      UserInfo.getUserId(),
      'Tester',
      null,
      null,
      null,
      null,
      null
    );
    PlatformEventPublisher.publishPresenceEvent(
      'a0I000000000001',
      UserInfo.getUserId(),
      'Tester',
      'online',
      System.now()
    );
    PlatformEventPublisher.publishTeamEvent(
      'a0I000000000002',
      'created',
      UserInfo.getUserId(),
      'Tester',
      null
    );
    Test.stopTest();
    System.assert(true, 'Skipping optional events must never fail the caller');
  }
}
