/**
 * @description Controller for Estimation Poker Room operations
 * Using 'with sharing' to enforce sharing rules for room data access
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.CognitiveComplexity, PMD.ExcessiveParameterList, PMD.AvoidDeeplyNestedIfStmts')
public with sharing class RoomController {

    /**
     * @description Creates a new estimation poker room
     * @param roomData Map containing room configuration data
     * @param teamId Optional team ID to associate with the room
     * @param memberRoles JSON string of member roles to assign
     * @return The ID of the created room
     */
    @AuraEnabled
    public static Id createRoom(Map<String, Object> roomData, Id teamId, String memberRoles) {
        try {
            // Validate room data
            ValidationService.validateRoomData(roomData);

            // Create room record
            Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
                Name = (String) roomData.get('name'),
                Description__c = (String) roomData.get('description'),
                Estimation_Scale__c = (String) roomData.get('estimationScale'),
                Custom_Scale_Values__c = (String) roomData.get('customScaleValues'),
                Status__c = 'Draft',
                Facilitator__c = UserInfo.getUserId()
            );

            insert as user room;

            // Add room members
            List<Room_Member__c> members = new List<Room_Member__c>();

            // Add facilitator as a member first
            members.add(new Room_Member__c(
                Room__c = room.Id,
                User__c = UserInfo.getUserId(),
                Role_In_Room__c = 'Facilitator',
                Can_Vote__c = true,
                Status__c = 'Active',
                Joined_Date__c = Datetime.now()
            ));

            // Parse member roles JSON and add members
            if (String.isNotBlank(memberRoles)) {
                List<Object> memberList = (List<Object>) JSON.deserializeUntyped(memberRoles);

                for (Object memberObj : memberList) {
                    Map<String, Object> memberData = (Map<String, Object>) memberObj;
                    String odataUserId = (String) memberData.get('userId');
                    String role = (String) memberData.get('role');

                    // Skip if this is the current user (already added as facilitator)
                    if (odataUserId != UserInfo.getUserId()) {
                        Boolean canVote = role != 'Observer';
                        members.add(new Room_Member__c(
                            Room__c = room.Id,
                            User__c = odataUserId,
                            Role_In_Room__c = role != null ? role : 'Voter',
                            Can_Vote__c = canVote,
                            Status__c = 'Invited',
                            Joined_Date__c = Datetime.now()
                        ));
                    }
                }
            }

            insert as user members;

            // Collect user IDs and query all at once to avoid SOQL in loop
            Set<Id> userIds = new Set<Id>();
            for (Room_Member__c member : members) {
                userIds.add(member.User__c);
            }
            Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :userIds WITH USER_MODE]);

            // Publish events for each new member
            for (Room_Member__c member : members) {
                String userName = userMap.containsKey(member.User__c) ? userMap.get(member.User__c).Name : 'Unknown';
                PlatformEventPublisher.publishRoomEvent(
                    room.Id,
                    'member_joined',
                    member.User__c,
                    userName,
                    null,
                    null,
                    null,
                    null,
                    null
                );
            }

            return room.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets detailed room information
     * @param roomId The room to get details for
     * @return Map containing room, members, stories, and statistics
     */
    @AuraEnabled
    public static Map<String, Object> getRoomDetails(Id roomId) {
        try {
            Estimation_Poker_Room__c room = [
                SELECT Id, Name, Room_Code__c, Status__c, Description__c,
                       Estimation_Scale__c, Custom_Scale_Values__c,
                       Start_DateTime__c, End_DateTime__c,
                       Facilitator__c, Facilitator__r.Name,
                       Current_Story__c, Current_Story__r.Story_Title__c,
                       CreatedDate, LastModifiedDate
                FROM Estimation_Poker_Room__c
                WHERE Id = :roomId
                WITH USER_MODE
                LIMIT 1
            ];

            // Get members
            List<Room_Member__c> members = [
                SELECT Id, User__c, User__r.Name, User__r.SmallPhotoUrl,
                       Role_In_Room__c, Can_Vote__c, Status__c,
                       Is_Online__c, Last_Activity__c, Joined_Date__c
                FROM Room_Member__c
                WHERE Room__c = :roomId
                WITH USER_MODE
                ORDER BY Role_In_Room__c, User__r.Name
            ];

            // Get stories
            List<User_Story__c> stories = [
                SELECT Id, Name, Story_Title__c, Story_Description__c,
                       Status__c, Story_Order__c, Final_Estimate__c,
                       Average_Estimate__c, Votes_Revealed__c, Voting_Start_Time__c
                FROM User_Story__c
                WHERE Room__c = :roomId
                WITH USER_MODE
                ORDER BY Story_Order__c NULLS LAST, CreatedDate
            ];

            // Get scale values
            List<String> scaleValues = EstimationService.getScaleValues(
                room.Estimation_Scale__c,
                room.Custom_Scale_Values__c
            );

            // Count statistics
            Integer totalStories = stories.size();
            Integer estimatedStories = 0;
            Integer votingMembers = 0;

            for (User_Story__c story : stories) {
                if (story.Status__c == 'Estimated') {
                    estimatedStories++;
                }
            }

            Id currentUserId = UserInfo.getUserId();
            List<Map<String, Object>> memberMaps = new List<Map<String, Object>>();
            for (Room_Member__c member : members) {
                Map<String, Object> memberMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(member));
                memberMap.put('Is_Current_User__c', member.User__c == currentUserId);

                memberMap.put('User__r', new Map<String, Object>{
                    'Name' => member.User__r.Name,
                    'SmallPhotoUrl' => member.User__r.SmallPhotoUrl
                });

                memberMaps.add(memberMap);

                if (member.Can_Vote__c && (member.Status__c == 'Active' || member.Status__c == 'Invited')) {
                    votingMembers++;
                }
            }

            // Check if current user has voted in this room
            Boolean currentUserHasVoted = [
                SELECT COUNT() FROM Estimation_Vote__c
                WHERE Room_Member__r.Room__c = :roomId
                AND Room_Member__r.User__c = :UserInfo.getUserId()
                WITH USER_MODE
            ] > 0;

            return new Map<String, Object>{
                'room' => room,
                'members' => memberMaps,
                'stories' => stories,
                'scaleValues' => scaleValues,
                'totalStories' => totalStories,
                'estimatedStories' => estimatedStories,
                'votingMembers' => votingMembers,
                'isFacilitator' => room.Facilitator__c == UserInfo.getUserId() ||
                    hasRoleInRoom(roomId, 'Facilitator'),
                'currentUserHasVoted' => currentUserHasVoted
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets rooms for the current user
     * @return List of room data maps for the current user
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMyRooms() {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Get rooms where user is a member
            List<Room_Member__c> memberships = [
                SELECT Room__c, Room__r.Id, Room__r.Name, Room__r.Room_Code__c,
                       Room__r.Status__c, Room__r.Description__c,
                       Room__r.Estimation_Scale__c, Room__r.Facilitator__r.Name,
                       Room__r.Start_DateTime__c, Room__r.CreatedDate,
                       Role_In_Room__c
                FROM Room_Member__c
                WHERE User__c = :currentUserId
                AND Room__r.Status__c != 'Archived'
                WITH USER_MODE
                ORDER BY Room__r.CreatedDate DESC
                LIMIT 100
            ];

            List<Map<String, Object>> rooms = new List<Map<String, Object>>();
            Set<Id> roomIds = new Set<Id>();

            for (Room_Member__c membership : memberships) {
                roomIds.add(membership.Room__c);
            }

            // Get member counts and story counts
            Map<Id, Integer> memberCounts = new Map<Id, Integer>();
            Map<Id, Integer> storyCounts = new Map<Id, Integer>();
            Map<Id, Integer> estimatedStoryCounts = new Map<Id, Integer>();

            // Query member counts
            for (AggregateResult ar : [
                SELECT Room__c, COUNT(Id) cnt
                FROM Room_Member__c
                WHERE Room__c IN :roomIds
                WITH USER_MODE
                GROUP BY Room__c
            ]) {
                memberCounts.put((Id) ar.get('Room__c'), Integer.valueOf(ar.get('cnt')));
            }

            // Query story counts (total and estimated)
            for (AggregateResult ar : [
                SELECT Room__c, Status__c, COUNT(Id) cnt
                FROM User_Story__c
                WHERE Room__c IN :roomIds
                WITH USER_MODE
                GROUP BY Room__c, Status__c
            ]) {
                Id rId = (Id) ar.get('Room__c');
                String status = (String) ar.get('Status__c');
                Integer cnt = Integer.valueOf(ar.get('cnt'));

                Integer currentTotal = storyCounts.containsKey(rId) ? storyCounts.get(rId) : 0;
                storyCounts.put(rId, currentTotal + cnt);

                if (status == 'Estimated') {
                    estimatedStoryCounts.put(rId, cnt);
                }
            }

            for (Room_Member__c membership : memberships) {
                rooms.add(new Map<String, Object>{
                    'id' => membership.Room__r.Id,
                    'name' => membership.Room__r.Name,
                    'roomCode' => membership.Room__r.Room_Code__c,
                    'status' => membership.Room__r.Status__c,
                    'description' => membership.Room__r.Description__c,
                    'estimationScale' => membership.Room__r.Estimation_Scale__c,
                    'facilitator' => membership.Room__r.Facilitator__r.Name,
                    'myRole' => membership.Role_In_Room__c,
                    'memberCount' => memberCounts.containsKey(membership.Room__c) ? memberCounts.get(membership.Room__c) : 0,
                    'storyCount' => storyCounts.containsKey(membership.Room__c) ? storyCounts.get(membership.Room__c) : 0,
                    'estimatedStoryCount' => estimatedStoryCounts.containsKey(membership.Room__c) ? estimatedStoryCounts.get(membership.Room__c) : 0,
                    'createdDate' => membership.Room__r.CreatedDate
                });
            }

            return rooms;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Updates room status
     * @param roomId The room to update
     * @param status The new status value
     */
    @AuraEnabled
    public static void updateRoomStatus(Id roomId, String status) {
        try {
            Estimation_Poker_Room__c room = [
                SELECT Id, Status__c, Start_DateTime__c, End_DateTime__c, Current_Story__c
                FROM Estimation_Poker_Room__c
                WHERE Id = :roomId
                WITH USER_MODE
                LIMIT 1
            ];

            room.Status__c = status;
            String additionalData = null;

            if (status == 'Active' && room.Start_DateTime__c == null) {
                room.Start_DateTime__c = Datetime.now();

                // Automatically select first story if none selected
                if (room.Current_Story__c == null) {
                    List<User_Story__c> firstStory = [
                        SELECT Id, Story_Title__c FROM User_Story__c
                        WHERE Room__c = :roomId
                        WITH USER_MODE
                        ORDER BY Story_Order__c NULLS LAST, CreatedDate
                        LIMIT 1
                    ];
                    if (!firstStory.isEmpty()) {
                        room.Current_Story__c = firstStory[0].Id;

                        // Update the story's voting start time
                        update as user new User_Story__c(
                            Id = firstStory[0].Id,
                            Status__c = 'Voting',
                            Voting_Start_Time__c = Datetime.now()
                        );

                        Map<String, Object> data = new Map<String, Object>{
                            'votingStartTime' => Datetime.now()
                        };
                        additionalData = JSON.serialize(data);
                    }
                }
            } else if (status == 'Completed') {
                room.End_DateTime__c = Datetime.now();
            }

            update as user room;

            // Publish room event based on status
            String eventAction;
            if (status == 'Active') {
                eventAction = (additionalData != null) ? 'session_started' : 'session_resumed';
            } else if (status == 'Paused') {
                eventAction = 'session_paused';
            } else if (status == 'Completed') {
                eventAction = 'session_ended';
            } else {
                eventAction = 'status_updated';
            }

            PlatformEventPublisher.publishRoomEvent(
                roomId,
                eventAction,
                UserInfo.getUserId(),
                UserInfo.getName(),
                room.Current_Story__c,
                null,
                status,
                null,
                additionalData
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Adds members to a room
     * @param roomId The room to add members to
     * @param memberDataList List of member data maps with userId and role
     * @return List of created Room_Member__c records
     */
    @AuraEnabled
    public static List<Room_Member__c> addRoomMembers(Id roomId, List<Map<String, Object>> memberDataList) {
        try {
            // Validate room status
            Estimation_Poker_Room__c room = [
                SELECT Id, Status__c
                FROM Estimation_Poker_Room__c
                WHERE Id = :roomId
                WITH USER_MODE
                LIMIT 1
            ];

            if (room.Status__c == 'Completed') {
                throw new AuraHandledException('Cannot add members to a completed room.');
            }

            List<Room_Member__c> newMembers = new List<Room_Member__c>();

            for (Map<String, Object> memberData : memberDataList) {
                Id odataUserId = (Id) memberData.get('userId');
                String role = (String) memberData.get('role');
                Boolean canVote = memberData.get('canVote') != null ?
                    (Boolean) memberData.get('canVote') : true;

                // Validate uniqueness
                ValidationService.validateUniqueRoomMember(roomId, odataUserId, null);

                newMembers.add(new Room_Member__c(
                    Room__c = roomId,
                    User__c = odataUserId,
                    Role_In_Room__c = role != null ? role : 'Voter',
                    Can_Vote__c = canVote,
                    Status__c = 'Invited',
                    Joined_Date__c = Datetime.now()
                ));
            }

            insert as user newMembers;

            // Collect user IDs and query all at once to avoid SOQL in loop
            Set<Id> userIds = new Set<Id>();
            for (Room_Member__c member : newMembers) {
                userIds.add(member.User__c);
            }
            Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :userIds WITH USER_MODE]);

            // Publish events for each new member
            for (Room_Member__c member : newMembers) {
                String userName = userMap.containsKey(member.User__c) ? userMap.get(member.User__c).Name : 'Unknown';
                PlatformEventPublisher.publishRoomEvent(
                    roomId,
                    'member_joined',
                    member.User__c,
                    userName,
                    null,
                    null,
                    null,
                    null,
                    null
                );
            }

            return newMembers;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Removes a member from a room
     * @param roomMemberId The room member record to remove
     */
    @AuraEnabled
    public static void removeRoomMember(Id roomMemberId) {
        try {
            Room_Member__c member = [
                SELECT Id, Room__c, User__c, User__r.Name
                FROM Room_Member__c
                WHERE Id = :roomMemberId
                WITH USER_MODE
                LIMIT 1
            ];

            Id roomId = member.Room__c;
            String userName = member.User__r.Name;
            Id odataUserId = member.User__c;

            delete as user member;

            // Publish event
            PlatformEventPublisher.publishRoomEvent(
                roomId,
                'member_left',
                odataUserId,
                userName,
                null,
                null,
                null,
                null,
                null
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Deletes a room and all related records
     * @param roomId The room to delete
     */
    @AuraEnabled
    public static void deleteRoom(Id roomId) {
        try {
            // Verify user can manage room
            if (!ValidationService.canManageRoom(roomId, UserInfo.getUserId())) {
                throw new AuraHandledException('You do not have permission to delete this room');
            }

            delete as user [SELECT Id FROM Estimation_Poker_Room__c WHERE Id = :roomId WITH USER_MODE];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Sets the current story for a room
     * @param roomId The room to update
     * @param storyId The story to set as current
     */
    @AuraEnabled
    public static void setCurrentStory(Id roomId, Id storyId) {
        try {
            User_Story__c story = [
                SELECT Id, Story_Title__c, Status__c, Voting_Start_Time__c
                FROM User_Story__c
                WHERE Id = :storyId
                WITH USER_MODE
                LIMIT 1
            ];

            // Update the story status and reset voting start time
            if (story.Status__c != 'Skipped' && story.Status__c != 'Estimated') {
                // Reset any currently 'Voting' stories to 'Pending' or 'Estimated'
                List<User_Story__c> activeStories = [
                    SELECT Id, Status__c, Final_Estimate__c
                    FROM User_Story__c
                    WHERE Room__c = :roomId
                    AND Status__c = 'Voting'
                    AND Id != :storyId
                    WITH USER_MODE
                ];

                for (User_Story__c s : activeStories) {
                    if (String.isNotBlank(s.Final_Estimate__c)) {
                        s.Status__c = 'Estimated';
                    } else {
                        s.Status__c = 'Pending';
                    }
                }

                if (!activeStories.isEmpty()) {
                    update as user activeStories;
                }

                story.Status__c = 'Voting';
                story.Voting_Start_Time__c = Datetime.now();
                update as user story;
            }

            // Update room's current story
            update as user new Estimation_Poker_Room__c(
                Id = roomId,
                Current_Story__c = storyId
            );

            // Publish event with voting start time in additional data
            Map<String, Object> data = new Map<String, Object>{
                'votingStartTime' => story.Voting_Start_Time__c
            };

            PlatformEventPublisher.publishRoomEvent(
                roomId,
                'story_selected',
                UserInfo.getUserId(),
                UserInfo.getName(),
                storyId,
                story.Story_Title__c,
                null,
                null,
                JSON.serialize(data)
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets the current user's room member record
     * @param roomId The room to check membership for
     * @return The Room_Member__c record or null
     */
    @AuraEnabled
    public static Room_Member__c getCurrentUserMember(Id roomId) {
        try {
            List<Room_Member__c> members = [
                SELECT Id, User__c, User__r.Name, Role_In_Room__c,
                       Can_Vote__c, Status__c
                FROM Room_Member__c
                WHERE Room__c = :roomId
                AND User__c = :UserInfo.getUserId()
                WITH USER_MODE
                LIMIT 1
            ];

            return members.isEmpty() ? null : members[0];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Updates member's online status
     * @param roomMemberId The room member to update
     * @param isOnline Whether the member is online
     */
    @AuraEnabled
    public static void updateMemberPresence(Id roomMemberId, Boolean isOnline) {
        try {
            Room_Member__c member = [
                SELECT Id, Room__c, User__c, User__r.Name, Is_Online__c
                FROM Room_Member__c
                WHERE Id = :roomMemberId
                WITH USER_MODE
                LIMIT 1
            ];

            member.Is_Online__c = isOnline;
            member.Last_Activity__c = Datetime.now();
            member.Status__c = isOnline ? 'Active' : member.Status__c;

            update as user member;

            // Publish presence event
            PlatformEventPublisher.publishPresenceEvent(
                member.Room__c,
                member.User__c,
                member.User__r.Name,
                isOnline ? 'online' : 'offline',
                Datetime.now()
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Checks if the current user has a specific role in a room
     * @param roomId The room to check
     * @param role The role to look for
     * @return True if user has the specified role
     */
    private static Boolean hasRoleInRoom(Id roomId, String role) {
        List<Room_Member__c> members = [
            SELECT Id FROM Room_Member__c
            WHERE Room__c = :roomId
            AND User__c = :UserInfo.getUserId()
            AND Role_In_Room__c = :role
            AND Status__c = 'Active'
            WITH USER_MODE
            LIMIT 1
        ];
        return !members.isEmpty();
    }

    /**
     * @description Sends a like reaction to a room member
     * @param roomId The room context
     * @param targetUserId The user to send the like to
     */
    @AuraEnabled
    public static void sendMemberLike(Id roomId, Id targetUserId) {
        try {
            // Validate sender is a member of the room
            if (getCurrentUserMember(roomId) == null) {
                throw new AuraHandledException('You must be a member of the room to send likes.');
            }

            // Publish like event
            Map<String, Object> data = new Map<String, Object>{
                'targetUserId' => targetUserId,
                'senderName' => UserInfo.getName()
            };

            PlatformEventPublisher.publishRoomEvent(
                roomId,
                'member_like',
                UserInfo.getUserId(),
                UserInfo.getName(),
                null,
                null,
                null,
                null,
                JSON.serialize(data)
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}