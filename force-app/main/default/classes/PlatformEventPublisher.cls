/**
 * @description Centralized Platform Event Publisher for Planning Poker
 * Handles publishing of all real-time events for the application
 * Using 'with sharing' to enforce sharing rules
 */
@SuppressWarnings('PMD.ExcessiveParameterList, PMD.AvoidDebugStatements')
public with sharing class PlatformEventPublisher {
  private static List<SObject> queuedEvents = new List<SObject>();

  /**
   * @description Publishes a vote event
   * @param roomId The room ID
   * @param storyId The story ID
   * @param roomMemberId The room member ID
   * @param odataUserId The user ID
   * @param odataUserName The user display name
   * @param action The event action type
   * @param voteValue The vote value
   * @param revealed Whether votes are revealed
   * @param voteCount Current vote count
   * @param totalMembers Total voting members
   * @param duration Vote duration in seconds
   */
  public static void publishVoteEvent(
    String roomId,
    String storyId,
    String roomMemberId,
    String odataUserId,
    String odataUserName,
    String action,
    String voteValue,
    Boolean revealed,
    Integer voteCount,
    Integer totalMembers,
    Integer duration
  ) {
    Poker_Vote_Event__e event = new Poker_Vote_Event__e(
      Room_Id__c = roomId,
      Story_Id__c = storyId,
      Room_Member_Id__c = roomMemberId,
      User_Id__c = odataUserId,
      User_Name__c = odataUserName,
      Action__c = action,
      Vote_Value__c = voteValue,
      Revealed__c = revealed,
      Vote_Count__c = voteCount,
      Total_Members__c = totalMembers,
      Duration__c = duration,
      Timestamp__c = Datetime.now(),
      Event_Id__c = generateEventId()
    );

    Database.SaveResult sr = EventBus.publish(event);
    handlePublishResult(sr, 'Poker_Vote_Event__e');
  }

  /**
   * @description Publishes votes revealed event with all vote data
   * @param roomId The room ID
   * @param storyId The story ID
   * @param allVotesJson JSON string of all vote data
   */
  public static void publishVotesRevealedEvent(
    String roomId,
    String storyId,
    String allVotesJson
  ) {
    Poker_Vote_Event__e event = new Poker_Vote_Event__e(
      Room_Id__c = roomId,
      Story_Id__c = storyId,
      Action__c = 'votes_revealed',
      Revealed__c = true,
      All_Votes_Data__c = allVotesJson,
      Timestamp__c = Datetime.now(),
      Event_Id__c = generateEventId()
    );

    Database.SaveResult sr = EventBus.publish(event);
    handlePublishResult(sr, 'Poker_Vote_Event__e');
  }

  /**
   * @description Publishes estimate finalized event
   * @param roomId The room ID
   * @param storyId The story ID
   * @param finalEstimate The final estimate value
   * @param voteSummaryJson JSON string of vote summary data
   */
  public static void publishEstimateFinalizedEvent(
    String roomId,
    String storyId,
    String finalEstimate,
    String voteSummaryJson
  ) {
    Poker_Vote_Event__e event = new Poker_Vote_Event__e(
      Room_Id__c = roomId,
      Story_Id__c = storyId,
      Action__c = 'estimate_finalized',
      Final_Estimate__c = finalEstimate,
      All_Votes_Data__c = voteSummaryJson,
      Timestamp__c = Datetime.now(),
      Event_Id__c = generateEventId()
    );

    Database.SaveResult sr = EventBus.publish(event);
    handlePublishResult(sr, 'Poker_Vote_Event__e');
  }

  /**
   * @description Publishes a room event
   * @param roomId The room ID
   * @param action The event action type
   * @param odataUserId The user ID
   * @param odataUserName The user display name
   * @param currentStoryId Current story ID
   * @param currentStoryTitle Current story title
   * @param roomStatus Room status value
   * @param memberCount Number of members
   * @param additionalDataJson Additional JSON data
   */
  public static void publishRoomEvent(
    String roomId,
    String action,
    String odataUserId,
    String odataUserName,
    String currentStoryId,
    String currentStoryTitle,
    String roomStatus,
    Integer memberCount,
    String additionalDataJson
  ) {
    if (!shouldPublishRoomAction(action)) {
      return;
    }

    Poker_Room_Event__e event = new Poker_Room_Event__e(
      Room_Id__c = roomId,
      Action__c = action,
      User_Id__c = odataUserId,
      User_Name__c = odataUserName,
      Current_Story_Id__c = currentStoryId,
      Current_Story_Title__c = currentStoryTitle,
      Room_Status__c = roomStatus,
      Member_Count__c = memberCount,
      Data__c = additionalDataJson,
      Timestamp__c = Datetime.now(),
      Event_Id__c = generateEventId()
    );

    Database.SaveResult sr = EventBus.publish(event);
    handlePublishResult(sr, 'Poker_Room_Event__e');
  }

  /**
   * @description Publishes a story event
   * @param roomId The room ID
   * @param storyId The story ID
   * @param action The event action type
   * @param storyTitle The story title
   * @param storyStatus The story status
   * @param finalEstimate The final estimate value
   * @param storyOrder The story order number
   * @param updatedBy ID of the user who updated
   * @param storyDataJson Additional story JSON data
   */
  public static void publishStoryEvent(
    String roomId,
    String storyId,
    String action,
    String storyTitle,
    String storyStatus,
    String finalEstimate,
    Integer storyOrder,
    String updatedBy,
    String storyDataJson
  ) {
    Poker_Story_Event__e event = new Poker_Story_Event__e(
      Room_Id__c = roomId,
      Story_Id__c = storyId,
      Action__c = action,
      Story_Title__c = storyTitle,
      Story_Status__c = storyStatus,
      Final_Estimate__c = finalEstimate,
      Story_Order__c = storyOrder,
      Updated_By__c = updatedBy,
      Story_Data__c = storyDataJson,
      Timestamp__c = Datetime.now(),
      Event_Id__c = generateEventId()
    );

    Database.SaveResult sr = EventBus.publish(event);
    handlePublishResult(sr, 'Poker_Story_Event__e');
  }

  /**
   * @description Publishes a presence event
   * @param roomId The room ID
   * @param odataUserId The user ID
   * @param odataUserName The user display name
   * @param status The presence status
   * @param lastActivity Timestamp of last activity
   */
  public static void publishPresenceEvent(
    String roomId,
    String odataUserId,
    String odataUserName,
    String status,
    Datetime lastActivity
  ) {
    if (!hasEventBudget()) {
      return;
    }

    Poker_Presence_Event__e event = new Poker_Presence_Event__e(
      Room_Id__c = roomId,
      User_Id__c = odataUserId,
      User_Name__c = odataUserName,
      Status__c = status,
      Timestamp__c = Datetime.now(),
      Last_Activity__c = lastActivity
    );

    Database.SaveResult sr = EventBus.publish(event);
    handlePublishResult(sr, 'Poker_Presence_Event__e');
  }

  /**
   * @description Publishes a team event
   * @param teamId The team ID
   * @param action The event action type
   * @param odataUserId The user ID
   * @param odataUserName The user display name
   * @param additionalDataJson Additional JSON data
   */
  public static void publishTeamEvent(
    String teamId,
    String action,
    String odataUserId,
    String odataUserName,
    String additionalDataJson
  ) {
    if (!hasEventBudget()) {
      return;
    }

    Poker_Team_Event__e event = new Poker_Team_Event__e(
      Team_Id__c = teamId,
      Action__c = action,
      User_Id__c = odataUserId,
      User_Name__c = odataUserName,
      Data__c = additionalDataJson,
      Timestamp__c = Datetime.now()
    );

    Database.SaveResult sr = EventBus.publish(event);
    handlePublishResult(sr, 'Poker_Team_Event__e');
  }

  /**
   * @description Queues an event for batch publishing
   * @param event The platform event SObject to queue
   */
  public static void queueEvent(SObject event) {
    queuedEvents.add(event);
  }

  /**
   * @description Publishes all queued events
   */
  public static void publishQueuedEvents() {
    if (queuedEvents.isEmpty()) {
      return;
    }

    List<Database.SaveResult> results = EventBus.publish(queuedEvents);

    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        for (Database.Error err : results[i].getErrors()) {
          System.debug(
            LoggingLevel.ERROR,
            'Error publishing queued event: ' + err.getMessage()
          );
        }
      }
    }

    queuedEvents.clear();
  }

  /**
   * @description Generates a unique event ID
   * @return A UUID-formatted string
   */
  private static String generateEventId() {
    Blob b = Crypto.generateAesKey(128);
    String h = EncodingUtil.convertToHex(b);
    return h.substring(0, 8) +
      '-' +
      h.substring(8, 12) +
      '-' +
      h.substring(12, 16) +
      '-' +
      h.substring(16, 20) +
      '-' +
      h.substring(20);
  }

  // ---------------------------------------------------------------------------------------------
  // Event budget guard
  // Platform events are limited per org (events published per hour, events delivered per 24 hours; delivery
  // counts every subscriber). When the allowance runs low, nice-to-have events (likes, timers, presence,
  // team changes) are skipped so the essential ones (votes, reveal, finalize, story and member changes)
  // keep flowing. A failed or skipped publish never fails the user's action.
  // ---------------------------------------------------------------------------------------------

  private static final Set<String> OPTIONAL_ROOM_ACTIONS = new Set<String>{
    'member_like',
    'timer_started',
    'timer_paused',
    'timer_resumed',
    'timer_stopped'
  };
  private static final List<String> TRACKED_LIMITS = new List<String>{
    'HourlyPublishedPlatformEvents',
    'DailyDeliveredPlatformEvents'
  };
  // Optional events stop when less than this share of an allowance remains
  private static final Decimal MIN_REMAINING_SHARE = 0.15;

  private static Boolean budgetChecked = false;
  private static Boolean budgetAvailable = true;
  @TestVisible
  private static Boolean simulateLowBudget = false;

  /**
   * @description Whether the org still has enough event allowance left for optional events.
   * Evaluated once per transaction.
   * @return False when any tracked allowance is below the minimum remaining share
   */
  @TestVisible
  private static Boolean hasEventBudget() {
    if (simulateLowBudget) {
      return false;
    }
    if (!budgetChecked) {
      budgetChecked = true;
      Map<String, System.OrgLimit> orgLimits = OrgLimits.getMap();
      for (String limitName : TRACKED_LIMITS) {
        System.OrgLimit orgLimit = orgLimits.get(limitName);
        if (orgLimit != null && orgLimit.getLimit() > 0) {
          Decimal remaining = orgLimit.getLimit() - orgLimit.getValue();
          if (remaining / orgLimit.getLimit() < MIN_REMAINING_SHARE) {
            budgetAvailable = false;
          }
        }
      }
    }
    return budgetAvailable;
  }

  /**
   * @description Whether a room event should be published right now
   * @param action The room event action
   * @return True for essential actions, and for optional ones while the budget allows
   */
  @TestVisible
  private static Boolean shouldPublishRoomAction(String action) {
    return !OPTIONAL_ROOM_ACTIONS.contains(action) || hasEventBudget();
  }

  /**
   * @description Handles the result of publishing an event
   * @param sr The save result from EventBus.publish
   * @param eventType The type name of the event for logging
   */
  private static void handlePublishResult(
    Database.SaveResult sr,
    String eventType
  ) {
    if (!sr.isSuccess()) {
      for (Database.Error err : sr.getErrors()) {
        System.debug(
          LoggingLevel.ERROR,
          'Error publishing ' +
            eventType +
            ': ' +
            err.getStatusCode() +
            ' - ' +
            err.getMessage()
        );
      }
    }
  }
}
