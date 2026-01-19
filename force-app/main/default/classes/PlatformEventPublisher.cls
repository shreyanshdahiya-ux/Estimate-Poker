/**
 * @description Centralized Platform Event Publisher for Planning Poker
 * Handles publishing of all real-time events for the application
 * Using 'without sharing' to allow all users to publish events
 */
public without sharing class PlatformEventPublisher {

    private static List<SObject> queuedEvents = new List<SObject>();

    /**
     * @description Publishes a vote event
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
     */
    public static void publishPresenceEvent(
        String roomId,
        String odataUserId,
        String odataUserName,
        String status,
        Datetime lastActivity
    ) {
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
     */
    public static void publishTeamEvent(
        String teamId,
        String action,
        String odataUserId,
        String odataUserName,
        String additionalDataJson
    ) {
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
                    System.debug(LoggingLevel.ERROR,
                        'Error publishing queued event: ' + err.getMessage());
                }
            }
        }

        queuedEvents.clear();
    }

    /**
     * @description Generates a unique event ID
     */
    private static String generateEventId() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0, 8) + '-' + h.substring(8, 12) + '-' +
               h.substring(12, 16) + '-' + h.substring(16, 20) + '-' +
               h.substring(20);
    }

    /**
     * @description Handles the result of publishing an event
     */
    private static void handlePublishResult(Database.SaveResult sr, String eventType) {
        if (!sr.isSuccess()) {
            for (Database.Error err : sr.getErrors()) {
                System.debug(LoggingLevel.ERROR,
                    'Error publishing ' + eventType + ': ' + err.getStatusCode() +
                    ' - ' + err.getMessage());
            }
        }
    }
}