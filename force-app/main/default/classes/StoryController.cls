/**
 * @description Controller for User Story operations
 * Using 'with sharing' to enforce sharing rules for story data access.
 * CRUD/FLS enforcement is handled via WITH USER_MODE on SOQL and
 * AccessLevel.USER_MODE on DML throughout this class.
 */
/* sfge-disable ApexFlsViolation */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.ApexCRUDViolation')
public with sharing class StoryController {

    /**
     * @description Creates a new user story
     * @param storyData Map containing story details (title, description, etc.)
     * @param roomId The room to create the story in
     * @return The created User_Story__c record
     */
    @AuraEnabled
    public static User_Story__c createStory(Map<String, Object> storyData, Id roomId) {
        try {
            // Validate story data
            storyData.put('roomId', roomId);
            ValidationService.validateStoryData(storyData);

            // Get max order for room
            Integer maxOrder = 0;
            List<AggregateResult> results = [
                SELECT MAX(Story_Order__c) maxOrder
                FROM User_Story__c
                WHERE Room__c = :roomId
                WITH USER_MODE
            ];
            if (results[0].get('maxOrder') != null) {
                maxOrder = ((Decimal) results[0].get('maxOrder')).intValue();
            }

            User_Story__c story = new User_Story__c(
                Room__c = roomId,
                Story_Title__c = (String) storyData.get('title'),
                Story_Description__c = (String) storyData.get('description'),
                Acceptance_Criteria__c = (String) storyData.get('acceptanceCriteria'),
                Status__c = 'Pending',
                Story_Order__c = maxOrder + 1,
                External_Story_Id__c = (String) storyData.get('externalId'),
                Notes__c = (String) storyData.get('notes')
            );

            Database.insert(story, AccessLevel.USER_MODE);

            // Publish event
            PlatformEventPublisher.publishStoryEvent(
                roomId,
                story.Id,
                'created',
                story.Story_Title__c,
                story.Status__c,
                null,
                (Integer) story.Story_Order__c,
                UserInfo.getUserId(),
                null
            );

            return story;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Creates multiple stories at once
     * @param storyDataList List of story data maps
     * @param roomId The room to create stories in
     * @return List of created User_Story__c records
     */
    @AuraEnabled
    public static List<User_Story__c> bulkCreateStories(List<Map<String, Object>> storyDataList, Id roomId) {
        try {
            // Get max order for room
            Integer maxOrder = 0;
            List<AggregateResult> results = [
                SELECT MAX(Story_Order__c) maxOrder
                FROM User_Story__c
                WHERE Room__c = :roomId
                WITH USER_MODE
            ];
            if (results[0].get('maxOrder') != null) {
                maxOrder = ((Decimal) results[0].get('maxOrder')).intValue();
            }

            List<User_Story__c> stories = new List<User_Story__c>();
            Integer orderCounter = maxOrder;

            for (Map<String, Object> storyData : storyDataList) {
                orderCounter++;

                stories.add(new User_Story__c(
                    Room__c = roomId,
                    Story_Title__c = (String) storyData.get('title'),
                    Story_Description__c = (String) storyData.get('description'),
                    Acceptance_Criteria__c = (String) storyData.get('acceptanceCriteria'),
                    Status__c = 'Pending',
                    Story_Order__c = orderCounter,
                    External_Story_Id__c = (String) storyData.get('externalId')
                ));
            }

            Database.insert(stories, AccessLevel.USER_MODE);

            // Publish events for each story
            for (User_Story__c story : stories) {
                PlatformEventPublisher.queueEvent(new Poker_Story_Event__e(
                    Room_Id__c = roomId,
                    Story_Id__c = story.Id,
                    Action__c = 'created',
                    Story_Title__c = story.Story_Title__c,
                    Story_Status__c = story.Status__c,
                    Story_Order__c = (Integer) story.Story_Order__c,
                    Updated_By__c = UserInfo.getUserId(),
                    Timestamp__c = Datetime.now()
                ));
            }
            PlatformEventPublisher.publishQueuedEvents();

            return stories;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Updates a user story
     * @param storyId The story to update
     * @param storyData Map containing fields to update
     * @return The updated User_Story__c record
     */
    /* sfge-disable-stack ApexFlsViolation */
    @AuraEnabled
    public static User_Story__c updateStory(Id storyId, Map<String, Object> storyData) {
        try {
            User_Story__c story = [
                SELECT Id, Room__c, Story_Title__c, Story_Description__c,
                       Acceptance_Criteria__c, Status__c, Story_Order__c,
                       External_Story_Id__c, Notes__c, Final_Estimate__c
                FROM User_Story__c
                WHERE Id = :storyId
                WITH USER_MODE
                LIMIT 1
            ];

            // Security check: Only facilitators can update stories
            if (!ValidationService.canManageRoom(story.Room__c, UserInfo.getUserId())) {
                throw new AuraHandledException('Only facilitators can update stories');
            }

            if (storyData.containsKey('title')) {
                story.Story_Title__c = (String) storyData.get('title');
            }
            if (storyData.containsKey('description')) {
                story.Story_Description__c = (String) storyData.get('description');
            }
            if (storyData.containsKey('acceptanceCriteria')) {
                story.Acceptance_Criteria__c = (String) storyData.get('acceptanceCriteria');
            }
            if (storyData.containsKey('status')) {
                story.Status__c = (String) storyData.get('status');
            }
            if (storyData.containsKey('externalId')) {
                story.External_Story_Id__c = (String) storyData.get('externalId');
            }
            if (storyData.containsKey('notes')) {
                story.Notes__c = (String) storyData.get('notes');
            }

            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<User_Story__c>{ story }
            );
            Database.update(decision.getRecords(), AccessLevel.USER_MODE);

            // Publish event
            PlatformEventPublisher.publishStoryEvent(
                story.Room__c,
                story.Id,
                'updated',
                story.Story_Title__c,
                story.Status__c,
                story.Final_Estimate__c,
                story.Story_Order__c != null ? (Integer) story.Story_Order__c : null,
                UserInfo.getUserId(),
                null
            );

            return story;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Deletes a user story
     * @param storyId The story to delete
     */
    /* sfge-disable-stack ApexFlsViolation */
    @AuraEnabled
    public static void deleteStory(Id storyId) {
        try {
            User_Story__c story = [
                SELECT Id, Room__c, Story_Title__c
                FROM User_Story__c
                WHERE Id = :storyId
                WITH USER_MODE
                LIMIT 1
            ];

            // Security check: Only facilitators can delete stories
            if (!ValidationService.canManageRoom(story.Room__c, UserInfo.getUserId())) {
                throw new AuraHandledException('Only facilitators can delete stories');
            }

            Id roomId = story.Room__c;
            String title = story.Story_Title__c;

            if (!Schema.sObjectType.User_Story__c.isDeletable()) {
                throw new AuraHandledException('Insufficient access to delete User Story');
            }
            Database.delete(story, AccessLevel.USER_MODE);

            // Publish event
            PlatformEventPublisher.publishStoryEvent(
                roomId,
                storyId,
                'deleted',
                title,
                null,
                null,
                null,
                UserInfo.getUserId(),
                null
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Deletes all stories for a room
     * @param roomId The room to delete stories from
     */
    /* sfge-disable-stack ApexFlsViolation */
    @AuraEnabled
    public static void deleteAllStoriesByRoom(Id roomId) {
        try {
            // Security check
            if (!ValidationService.canManageRoom(roomId, UserInfo.getUserId())) {
                throw new AuraHandledException('Only facilitators can delete all stories');
            }

            List<User_Story__c> stories = [
                SELECT Id FROM User_Story__c WHERE Room__c = :roomId
                WITH USER_MODE
            ];

            if (!stories.isEmpty()) {
                if (!Schema.sObjectType.User_Story__c.isDeletable()) {
                    throw new AuraHandledException('Insufficient access to delete User Story');
                }
                Database.delete(stories, AccessLevel.USER_MODE);

                // Publish bulk delete event
                PlatformEventPublisher.publishStoryEvent(
                    roomId,
                    null,
                    'bulk_deleted',
                    'All Stories',
                    null,
                    null,
                    null,
                    UserInfo.getUserId(),
                    null
                );
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Reorders stories in a room
     * @param roomId The room containing the stories
     * @param storyOrders List of maps with storyId and order values
     */
    @AuraEnabled
    public static void reorderStories(Id roomId, List<Map<String, Object>> storyOrders) {
        try {
            // Security check
            if (!ValidationService.canManageRoom(roomId, UserInfo.getUserId())) {
                throw new AuraHandledException('Only facilitators can reorder stories');
            }

            List<User_Story__c> storiesToUpdate = new List<User_Story__c>();

            for (Map<String, Object> orderData : storyOrders) {
                storiesToUpdate.add(new User_Story__c(
                    Id = (Id) orderData.get('storyId'),
                    Story_Order__c = Integer.valueOf(String.valueOf(orderData.get('order')))
                ));
            }

            Database.update(storiesToUpdate, AccessLevel.USER_MODE);

            // Publish reorder event
            PlatformEventPublisher.publishStoryEvent(
                roomId,
                null,
                'reordered',
                null,
                null,
                null,
                null,
                UserInfo.getUserId(),
                JSON.serialize(storyOrders)
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets all stories for a room
     * @param roomId The room to get stories for
     * @return List of User_Story__c records
     */
    @AuraEnabled
    public static List<User_Story__c> getStoriesByRoom(Id roomId) {
        try {
            return [
                SELECT Id, Name, Story_Title__c, Story_Description__c,
                       Acceptance_Criteria__c, Status__c, Story_Order__c,
                       Final_Estimate__c, Average_Estimate__c, Notes__c,
                       External_Story_Id__c, Estimated_Date__c, Votes_Revealed__c,
                       Voting_Start_Time__c, Estimated_By__r.Name, CreatedDate
                FROM User_Story__c
                WHERE Room__c = :roomId
                WITH USER_MODE
                ORDER BY Story_Order__c NULLS LAST, CreatedDate
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets a single story with details including votes and statistics
     * @param storyId The story to get details for
     * @return Map containing story, votes, statistics, and scale values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getStoryDetails(Id storyId) {
        try {
            User_Story__c story = [
                SELECT Id, Name, Story_Title__c, Story_Description__c,
                       Acceptance_Criteria__c, Status__c, Story_Order__c,
                       Final_Estimate__c, Average_Estimate__c, Notes__c,
                       External_Story_Id__c, Estimated_Date__c, Votes_Revealed__c,
                       Voting_Start_Time__c, Estimated_By__r.Name, Room__c, Room__r.Estimation_Scale__c,
                       Room__r.Custom_Scale_Values__c
                FROM User_Story__c
                WHERE Id = :storyId
                WITH USER_MODE
                LIMIT 1
            ];

            // Get votes if revealed
            List<Map<String, Object>> votes = new List<Map<String, Object>>();
            Map<String, Object> stats = new Map<String, Object>();

            if (story.Votes_Revealed__c) {
                List<Estimation_Vote__c> voteRecords = [
                    SELECT Id, Vote_Value__c, Vote_Number__c, Comment__c,
                           Room_Member__r.User__r.Name, Room_Member__r.User__r.SmallPhotoUrl,
                           Voted_DateTime__c
                    FROM Estimation_Vote__c
                    WHERE User_Story__c = :storyId
                    WITH USER_MODE
                    ORDER BY Voted_DateTime__c
                ];

                for (Estimation_Vote__c vote : voteRecords) {
                    votes.add(new Map<String, Object>{
                        'id' => vote.Id,
                        'value' => vote.Vote_Value__c,
                        'numericValue' => vote.Vote_Number__c,
                        'comment' => vote.Comment__c,
                        'voterName' => vote.Room_Member__r.User__r.Name,
                        'voterPhoto' => vote.Room_Member__r.User__r.SmallPhotoUrl,
                        'votedAt' => vote.Voted_DateTime__c
                    });
                }

                stats = EstimationService.getVoteStatistics(voteRecords);
            }

            return new Map<String, Object>{
                'story' => story,
                'votes' => votes,
                'statistics' => stats,
                'scaleValues' => EstimationService.getScaleValues(
                    story.Room__r.Estimation_Scale__c,
                    story.Room__r.Custom_Scale_Values__c
                )
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Sets story status and handles related logic
     * @param storyId The story to update
     * @param status The new status value
     */
    /* sfge-disable-stack ApexFlsViolation */
    @AuraEnabled
    public static void setStoryStatus(Id storyId, String status) {
        try {
            User_Story__c story = [
                SELECT Id, Room__c, Story_Title__c
                FROM User_Story__c
                WHERE Id = :storyId
                WITH USER_MODE
                LIMIT 1
            ];

            // Security check: Only facilitators can manage stories
            if (!ValidationService.canManageRoom(story.Room__c, UserInfo.getUserId())) {
                AuraHandledException ex = new AuraHandledException('Only facilitators can skip or activate stories');
                ex.setMessage('Only facilitators can skip or activate stories');
                throw ex;
            }

            story.Status__c = status;
            if (status == 'Voting') {
                story.Voting_Start_Time__c = Datetime.now();
            }
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<User_Story__c>{ story }
            );
            Database.update(decision.getRecords(), AccessLevel.USER_MODE);

            String action = status == 'Voting' ? 'activated' :
                           status == 'Skipped' ? 'skipped' : 'updated';

            Map<String, Object> storyData = new Map<String, Object>();
            if (status == 'Voting' && story.Voting_Start_Time__c != null) {
                storyData.put('votingStartTime', story.Voting_Start_Time__c);
            }

            PlatformEventPublisher.publishStoryEvent(
                story.Room__c,
                storyId,
                action,
                story.Story_Title__c,
                status,
                null,
                null,
                UserInfo.getUserId(),
                storyData.isEmpty() ? null : JSON.serialize(storyData)
            );

            // Auto-advance logic for skipped stories
            if (status == 'Skipped') {
                User_Story__c nextStory = getNextPendingStory(story.Room__c, storyId);
                if (nextStory != null) {
                    RoomController.setCurrentStory(story.Room__c, nextStory.Id);
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets next pending story in the room after the current one
     * @param roomId The room to search in
     * @param currentStoryId The current story ID to search after
     * @return The next pending User_Story__c or null
     */
    @AuraEnabled
    public static User_Story__c getNextPendingStory(Id roomId, Id currentStoryId) {
        try {
            Integer currentOrder = 0;
            if (currentStoryId != null) {
                User_Story__c current = [
                    SELECT Story_Order__c FROM User_Story__c WHERE Id = :currentStoryId
                    WITH USER_MODE
                    LIMIT 1
                ];
                currentOrder = current.Story_Order__c != null ?
                    (Integer) current.Story_Order__c : 0;
            }

            List<User_Story__c> nextStories = [
                SELECT Id, Name, Story_Title__c, Status__c, Story_Order__c
                FROM User_Story__c
                WHERE Room__c = :roomId
                AND Status__c = 'Pending'
                AND (Story_Order__c > :currentOrder OR Story_Order__c = null)
                WITH USER_MODE
                ORDER BY Story_Order__c NULLS LAST
                LIMIT 1
            ];

            return nextStories.isEmpty() ? null : nextStories[0];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}