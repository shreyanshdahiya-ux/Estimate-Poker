/**
 * @description Controller for Estimation Reports and Analytics
 */
public with sharing class ReportController {

    /**
     * @description Gets dashboard summary statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardSummary() {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Get user's rooms
            List<Room_Member__c> memberships = [
                SELECT Room__c
                FROM Room_Member__c
                WHERE User__c = :currentUserId
            ];

            Set<Id> roomIds = new Set<Id>();
            for (Room_Member__c m : memberships) {
                roomIds.add(m.Room__c);
            }

            // Room statistics
            Integer totalRooms = roomIds.size();
            Integer activeRooms = [
                SELECT COUNT() FROM Estimation_Poker_Room__c
                WHERE Id IN :roomIds AND Status__c = 'Active'
            ];
            Integer completedRooms = [
                SELECT COUNT() FROM Estimation_Poker_Room__c
                WHERE Id IN :roomIds AND Status__c = 'Completed'
            ];

            // Story statistics
            Integer totalStories = [
                SELECT COUNT() FROM User_Story__c WHERE Room__c IN :roomIds
            ];
            Integer estimatedStories = [
                SELECT COUNT() FROM User_Story__c
                WHERE Room__c IN :roomIds AND Status__c = 'Estimated'
            ];

            // Vote statistics
            List<Room_Member__c> userMemberships = [
                SELECT Id FROM Room_Member__c WHERE User__c = :currentUserId
            ];
            Set<Id> memberIds = new Set<Id>();
            for (Room_Member__c m : userMemberships) {
                memberIds.add(m.Id);
            }

            Integer totalVotes = [
                SELECT COUNT() FROM Estimation_Vote__c WHERE Room_Member__c IN :memberIds
            ];

            return new Map<String, Object>{
                'totalRooms' => totalRooms,
                'activeRooms' => activeRooms,
                'completedRooms' => completedRooms,
                'totalStories' => totalStories,
                'estimatedStories' => estimatedStories,
                'pendingStories' => totalStories - estimatedStories,
                'totalVotes' => totalVotes
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets list of rooms for report selection
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRoomsForReport() {
        try {
            Id currentUserId = UserInfo.getUserId();

            List<Room_Member__c> memberships = [
                SELECT Room__c, Room__r.Id, Room__r.Name, Room__r.Room_Code__c,
                       Room__r.Status__c, Room__r.CreatedDate
                FROM Room_Member__c
                WHERE User__c = :currentUserId
                ORDER BY Room__r.CreatedDate DESC
            ];

            List<Map<String, Object>> rooms = new List<Map<String, Object>>();
            for (Room_Member__c m : memberships) {
                rooms.add(new Map<String, Object>{
                    'id' => m.Room__r.Id,
                    'name' => m.Room__r.Name,
                    'roomCode' => m.Room__r.Room_Code__c,
                    'status' => m.Room__r.Status__c,
                    'createdDate' => m.Room__r.CreatedDate
                });
            }

            return rooms;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Generates a detailed report for a specific room
     */
    @AuraEnabled
    public static Map<String, Object> generateRoomReport(Id roomId) {
        try {
            // Get room details
            Estimation_Poker_Room__c room = [
                SELECT Id, Name, Room_Code__c, Status__c, Description__c,
                       Estimation_Scale__c, Start_DateTime__c, End_DateTime__c,
                       Facilitator__r.Name, CreatedDate
                FROM Estimation_Poker_Room__c
                WHERE Id = :roomId
                LIMIT 1
            ];

            // Get all stories with votes
            List<User_Story__c> stories = [
                SELECT Id, Name, Story_Title__c, Status__c, Final_Estimate__c,
                       Average_Estimate__c, Story_Order__c, Estimated_Date__c,
                       Estimated_By__r.Name, Votes_Revealed__c
                FROM User_Story__c
                WHERE Room__c = :roomId
                ORDER BY Story_Order__c NULLS LAST
            ];

            Set<Id> storyIds = new Set<Id>();
            for (User_Story__c s : stories) {
                storyIds.add(s.Id);
            }

            // Get all votes
            List<Estimation_Vote__c> allVotes = [
                SELECT Id, Vote_Value__c, Vote_Number__c, User_Story__c,
                       Room_Member__r.User__r.Name, Voted_DateTime__c
                FROM Estimation_Vote__c
                WHERE User_Story__c IN :storyIds
            ];

            // Group votes by story
            Map<Id, List<Estimation_Vote__c>> votesByStory = new Map<Id, List<Estimation_Vote__c>>();
            for (Estimation_Vote__c v : allVotes) {
                if (!votesByStory.containsKey(v.User_Story__c)) {
                    votesByStory.put(v.User_Story__c, new List<Estimation_Vote__c>());
                }
                votesByStory.get(v.User_Story__c).add(v);
            }

            // Get members
            List<Room_Member__c> members = [
                SELECT Id, User__r.Name, User__r.Email, Role_In_Room__c, Can_Vote__c
                FROM Room_Member__c
                WHERE Room__c = :roomId
            ];

            // Build story details with statistics
            List<Map<String, Object>> storyDetails = new List<Map<String, Object>>();
            Decimal totalEstimatePoints = 0;
            Integer storiesWithEstimates = 0;

            for (User_Story__c story : stories) {
                List<Estimation_Vote__c> storyVotes = votesByStory.get(story.Id);
                Map<String, Object> storyMap = new Map<String, Object>{
                    'id' => story.Id,
                    'name' => story.Name,
                    'title' => story.Story_Title__c,
                    'status' => story.Status__c,
                    'finalEstimate' => story.Final_Estimate__c,
                    'averageEstimate' => story.Average_Estimate__c,
                    'estimatedDate' => story.Estimated_Date__c,
                    'estimatedBy' => story.Estimated_By__r?.Name,
                    'voteCount' => storyVotes != null ? storyVotes.size() : 0
                };

                // Add vote statistics if available
                if (storyVotes != null && !storyVotes.isEmpty()) {
                    storyMap.put('statistics', EstimationService.getVoteStatistics(storyVotes));

                    // Build vote breakdown
                    Map<String, Integer> voteBreakdown = new Map<String, Integer>();
                    for (Estimation_Vote__c v : storyVotes) {
                        String val = v.Vote_Value__c;
                        if (!voteBreakdown.containsKey(val)) {
                            voteBreakdown.put(val, 0);
                        }
                        voteBreakdown.put(val, voteBreakdown.get(val) + 1);
                    }
                    storyMap.put('voteBreakdown', voteBreakdown);
                }

                // Track totals
                if (story.Final_Estimate__c != null && story.Status__c == 'Estimated') {
                    try {
                        Decimal estimate = Decimal.valueOf(story.Final_Estimate__c);
                        totalEstimatePoints += estimate;
                        storiesWithEstimates++;
                    } catch (Exception e) {
                        // Non-numeric estimate (like ?, coffee), skip
                    }
                }

                storyDetails.add(storyMap);
            }

            // Build member participation stats
            List<Map<String, Object>> memberStats = new List<Map<String, Object>>();
            Map<Id, Integer> votesPerMember = new Map<Id, Integer>();

            for (Estimation_Vote__c v : allVotes) {
                Id odataUserId = v.Room_Member__r.User__c;
                if (!votesPerMember.containsKey(v.Room_Member__c)) {
                    votesPerMember.put(v.Room_Member__c, 0);
                }
                votesPerMember.put(v.Room_Member__c, votesPerMember.get(v.Room_Member__c) + 1);
            }

            // Count total members who can vote
            Integer totalVotingMembers = 0;
            for (Room_Member__c member : members) {
                if (member.Can_Vote__c) {
                    totalVotingMembers++;
                }
            }

            for (Room_Member__c member : members) {
                Integer voteCount = votesPerMember.get(member.Id);
                Boolean hasVoted = voteCount != null && voteCount > 0;
                
                memberStats.add(new Map<String, Object>{
                    'name' => member.User__r.Name,
                    'email' => member.User__r.Email,
                    'role' => member.Role_In_Room__c,
                    'canVote' => member.Can_Vote__c,
                    'voteCount' => voteCount != null ? voteCount : 0,
                    'participationRate' => member.Can_Vote__c && hasVoted ? 100 : 0
                });
            }

            // Calculate session duration
            Long durationMinutes = null;
            if (room.Start_DateTime__c != null && room.End_DateTime__c != null) {
                durationMinutes = (room.End_DateTime__c.getTime() - room.Start_DateTime__c.getTime()) / 60000;
            }

            return new Map<String, Object>{
                'room' => new Map<String, Object>{
                    'id' => room.Id,
                    'name' => room.Name,
                    'roomCode' => room.Room_Code__c,
                    'status' => room.Status__c,
                    'description' => room.Description__c,
                    'estimationScale' => room.Estimation_Scale__c,
                    'facilitator' => room.Facilitator__r.Name,
                    'startDateTime' => room.Start_DateTime__c,
                    'endDateTime' => room.End_DateTime__c,
                    'durationMinutes' => durationMinutes,
                    'createdDate' => room.CreatedDate
                },
                'summary' => new Map<String, Object>{
                    'totalStories' => stories.size(),
                    'estimatedStories' => storiesWithEstimates,
                    'pendingStories' => stories.size() - storiesWithEstimates,
                    'totalEstimatePoints' => totalEstimatePoints,
                    'averagePointsPerStory' => storiesWithEstimates > 0 ?
                        (totalEstimatePoints / storiesWithEstimates).setScale(1) : 0,
                    'totalMembers' => members.size(),
                    'totalVotes' => allVotes.size()
                },
                'stories' => storyDetails,
                'members' => memberStats,
                'generatedAt' => Datetime.now()
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets velocity/trend data across rooms
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getVelocityTrend() {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Get user's completed rooms
            List<Room_Member__c> memberships = [
                SELECT Room__c, Room__r.Name, Room__r.End_DateTime__c
                FROM Room_Member__c
                WHERE User__c = :currentUserId
                AND Room__r.Status__c = 'Completed'
                AND Room__r.End_DateTime__c != null
                ORDER BY Room__r.End_DateTime__c DESC
                LIMIT 10
            ];

            List<Map<String, Object>> trend = new List<Map<String, Object>>();

            for (Room_Member__c m : memberships) {
                // Get total points for this room
                Decimal totalPoints = 0;
                Integer storyCount = 0;

                for (User_Story__c story : [
                    SELECT Final_Estimate__c
                    FROM User_Story__c
                    WHERE Room__c = :m.Room__c AND Status__c = 'Estimated'
                ]) {
                    try {
                        if (story.Final_Estimate__c != null) {
                            totalPoints += Decimal.valueOf(story.Final_Estimate__c);
                            storyCount++;
                        }
                    } catch (Exception e) {
                        // Skip non-numeric
                    }
                }

                trend.add(new Map<String, Object>{
                    'roomId' => m.Room__c,
                    'roomName' => m.Room__r.Name,
                    'completedDate' => m.Room__r.End_DateTime__c,
                    'totalPoints' => totalPoints,
                    'storyCount' => storyCount
                });
            }

            return trend;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets estimate distribution across all user's stories
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getEstimateDistribution() {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Get user's rooms
            List<Room_Member__c> memberships = [
                SELECT Room__c FROM Room_Member__c WHERE User__c = :currentUserId
            ];

            Set<Id> roomIds = new Set<Id>();
            for (Room_Member__c m : memberships) {
                roomIds.add(m.Room__c);
            }

            // Get all estimated stories
            List<User_Story__c> stories = [
                SELECT Final_Estimate__c
                FROM User_Story__c
                WHERE Room__c IN :roomIds AND Status__c = 'Estimated'
            ];

            Map<String, Integer> distribution = new Map<String, Integer>();

            for (User_Story__c story : stories) {
                String estimate = story.Final_Estimate__c;
                if (estimate != null) {
                    if (!distribution.containsKey(estimate)) {
                        distribution.put(estimate, 0);
                    }
                    distribution.put(estimate, distribution.get(estimate) + 1);
                }
            }

            return distribution;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets detailed data for a specific KPI when clicked
     */
    @AuraEnabled
    public static Object getKpiDetails(String kpiType) {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Get user's rooms
            List<Room_Member__c> memberships = [
                SELECT Room__c FROM Room_Member__c WHERE User__c = :currentUserId
            ];

            Set<Id> roomIds = new Set<Id>();
            for (Room_Member__c m : memberships) {
                roomIds.add(m.Room__c);
            }

            if (kpiType == 'totalRooms') {
                // Return all rooms
                List<Estimation_Poker_Room__c> rooms = [
                    SELECT Id, Name, Room_Code__c, Status__c, CreatedDate
                    FROM Estimation_Poker_Room__c
                    WHERE Id IN :roomIds
                    ORDER BY CreatedDate DESC
                ];

                List<Map<String, Object>> result = new List<Map<String, Object>>();
                for (Estimation_Poker_Room__c room : rooms) {
                    result.add(new Map<String, Object>{
                        'id' => room.Id,
                        'name' => room.Name,
                        'roomCode' => room.Room_Code__c,
                        'status' => room.Status__c,
                        'createdDate' => room.CreatedDate
                    });
                }
                return result;

            } else if (kpiType == 'activeRooms') {
                // Return active rooms only
                List<Estimation_Poker_Room__c> rooms = [
                    SELECT Id, Name, Room_Code__c, Status__c, CreatedDate
                    FROM Estimation_Poker_Room__c
                    WHERE Id IN :roomIds AND Status__c = 'Active'
                    ORDER BY CreatedDate DESC
                ];

                List<Map<String, Object>> result = new List<Map<String, Object>>();
                for (Estimation_Poker_Room__c room : rooms) {
                    result.add(new Map<String, Object>{
                        'id' => room.Id,
                        'name' => room.Name,
                        'roomCode' => room.Room_Code__c,
                        'status' => room.Status__c,
                        'createdDate' => room.CreatedDate
                    });
                }
                return result;

            } else if (kpiType == 'totalStories') {
                // Return all stories
                List<User_Story__c> stories = [
                    SELECT Id, Story_Title__c, Status__c, Final_Estimate__c, Room__r.Name
                    FROM User_Story__c
                    WHERE Room__c IN :roomIds
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];

                List<Map<String, Object>> result = new List<Map<String, Object>>();
                for (User_Story__c story : stories) {
                    result.add(new Map<String, Object>{
                        'id' => story.Id,
                        'title' => story.Story_Title__c,
                        'status' => story.Status__c,
                        'finalEstimate' => story.Final_Estimate__c,
                        'roomName' => story.Room__r.Name
                    });
                }
                return result;

            } else if (kpiType == 'estimatedStories') {
                // Return estimated stories only
                List<User_Story__c> stories = [
                    SELECT Id, Story_Title__c, Status__c, Final_Estimate__c, Room__r.Name
                    FROM User_Story__c
                    WHERE Room__c IN :roomIds AND Status__c = 'Estimated'
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];

                List<Map<String, Object>> result = new List<Map<String, Object>>();
                for (User_Story__c story : stories) {
                    result.add(new Map<String, Object>{
                        'id' => story.Id,
                        'title' => story.Story_Title__c,
                        'status' => story.Status__c,
                        'finalEstimate' => story.Final_Estimate__c,
                        'roomName' => story.Room__r.Name
                    });
                }
                return result;

            } else if (kpiType == 'totalVotes') {
                // Return vote summary
                List<Room_Member__c> userMemberships = [
                    SELECT Id FROM Room_Member__c WHERE User__c = :currentUserId
                ];
                Set<Id> memberIds = new Set<Id>();
                for (Room_Member__c m : userMemberships) {
                    memberIds.add(m.Id);
                }

                Integer totalVotes = [
                    SELECT COUNT() FROM Estimation_Vote__c WHERE Room_Member__c IN :memberIds
                ];

                // Get unique stories voted on
                List<AggregateResult> storyAgg = [
                    SELECT COUNT_DISTINCT(User_Story__c) cnt
                    FROM Estimation_Vote__c
                    WHERE Room_Member__c IN :memberIds
                ];
                Integer uniqueStories = storyAgg.isEmpty() ? 0 : (Integer) storyAgg[0].get('cnt');

                // Get recent votes
                List<Estimation_Vote__c> recentVotes = [
                    SELECT Id, Vote_Value__c, User_Story__r.Story_Title__c, User_Story__r.Room__r.Name,
                           Voted_DateTime__c
                    FROM Estimation_Vote__c
                    WHERE Room_Member__c IN :memberIds
                    ORDER BY Voted_DateTime__c DESC
                    LIMIT 10
                ];

                List<Map<String, Object>> recentVotesList = new List<Map<String, Object>>();
                for (Estimation_Vote__c v : recentVotes) {
                    recentVotesList.add(new Map<String, Object>{
                        'id' => v.Id,
                        'value' => v.Vote_Value__c,
                        'storyTitle' => v.User_Story__r.Story_Title__c,
                        'roomName' => v.User_Story__r.Room__r.Name,
                        'votedAt' => v.Voted_DateTime__c
                    });
                }

                return new Map<String, Object>{
                    'totalVotes' => totalVotes,
                    'uniqueStories' => uniqueStories,
                    'avgVotesPerStory' => uniqueStories > 0 ? (Decimal.valueOf(totalVotes) / uniqueStories).setScale(1) : 0,
                    'recentVotes' => recentVotesList
                };
            }

            return null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Generates a consolidated report for all user's rooms
     */
    @AuraEnabled
    public static Map<String, Object> generateAllRoomsReport() {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Get user's rooms
            List<Room_Member__c> memberships = [
                SELECT Room__c
                FROM Room_Member__c
                WHERE User__c = :currentUserId
            ];

            Set<Id> roomIds = new Set<Id>();
            for (Room_Member__c m : memberships) {
                roomIds.add(m.Room__c);
            }

            // Get all rooms with details
            List<Estimation_Poker_Room__c> rooms = [
                SELECT Id, Name, Room_Code__c, Status__c, Description__c,
                       Estimation_Scale__c, Start_DateTime__c, End_DateTime__c,
                       Facilitator__r.Name, CreatedDate
                FROM Estimation_Poker_Room__c
                WHERE Id IN :roomIds
                ORDER BY CreatedDate DESC
            ];

            // Get all stories for these rooms
            List<User_Story__c> allStories = [
                SELECT Id, Room__c, Status__c, Final_Estimate__c
                FROM User_Story__c
                WHERE Room__c IN :roomIds
            ];

            // Group stories by room and calculate stats
            Map<Id, List<User_Story__c>> storiesByRoom = new Map<Id, List<User_Story__c>>();
            for (User_Story__c story : allStories) {
                if (!storiesByRoom.containsKey(story.Room__c)) {
                    storiesByRoom.put(story.Room__c, new List<User_Story__c>());
                }
                storiesByRoom.get(story.Room__c).add(story);
            }

            // Build room details
            List<Map<String, Object>> roomDetails = new List<Map<String, Object>>();
            Decimal grandTotalPoints = 0;
            Integer grandTotalStories = 0;
            Integer grandEstimatedStories = 0;

            for (Estimation_Poker_Room__c room : rooms) {
                List<User_Story__c> roomStories = storiesByRoom.get(room.Id);
                Integer totalStories = roomStories != null ? roomStories.size() : 0;
                Integer estimatedStories = 0;
                Decimal totalPoints = 0;

                if (roomStories != null) {
                    for (User_Story__c story : roomStories) {
                        if (story.Status__c == 'Estimated') {
                            estimatedStories++;
                            if (story.Final_Estimate__c != null) {
                                try {
                                    totalPoints += Decimal.valueOf(story.Final_Estimate__c);
                                } catch (Exception e) {
                                    // Skip non-numeric estimates
                                }
                            }
                        }
                    }
                }

                grandTotalStories += totalStories;
                grandEstimatedStories += estimatedStories;
                grandTotalPoints += totalPoints;

                roomDetails.add(new Map<String, Object>{
                    'id' => room.Id,
                    'name' => room.Name,
                    'roomCode' => room.Room_Code__c,
                    'status' => room.Status__c,
                    'totalStories' => totalStories,
                    'estimatedStories' => estimatedStories,
                    'totalPoints' => totalPoints > 0 ? totalPoints : null
                });
            }

            return new Map<String, Object>{
                'summary' => new Map<String, Object>{
                    'totalRooms' => rooms.size(),
                    'totalStories' => grandTotalStories,
                    'estimatedStories' => grandEstimatedStories,
                    'totalPoints' => grandTotalPoints,
                    'avgPointsPerStory' => grandEstimatedStories > 0 ?
                        (grandTotalPoints / grandEstimatedStories).setScale(1) : 0
                },
                'rooms' => roomDetails,
                'generatedAt' => Datetime.now()
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}