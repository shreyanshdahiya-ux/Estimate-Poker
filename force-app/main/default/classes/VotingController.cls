/**
 * @description Controller for voting and estimation operations
 * Using 'with sharing' to enforce sharing rules for vote operations
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.ExcessiveParameterList')
public with sharing class VotingController {

    /**
     * @description Submits or updates a vote
     * @param storyId The story being voted on
     * @param roomMemberId The room member casting the vote
     * @param voteValue The vote value string
     * @param voteComment Optional comment with the vote
     * @param confidenceLevel Optional confidence level
     * @param duration Time taken to vote in seconds
     * @return The created or updated vote record
     */
    @AuraEnabled
    public static Estimation_Vote__c submitVote(Id storyId, Id roomMemberId, String voteValue, String voteComment, String confidenceLevel, Integer duration) {
        try {
            // Validate vote data
            Map<String, Object> voteData = new Map<String, Object>{
                'storyId' => storyId,
                'roomMemberId' => roomMemberId,
                'voteValue' => voteValue
            };
            ValidationService.validateVote(voteData);

            // Check if user can vote
            if (!ValidationService.canUserVote(roomMemberId, storyId)) {
                // Get more details for error message
                User_Story__c storyCheck = [SELECT Status__c, Votes_Revealed__c FROM User_Story__c WHERE Id = :storyId LIMIT 1];
                String reason = 'You cannot vote on this story. ';
                if (storyCheck.Status__c != 'Voting' && storyCheck.Status__c != 'Discussing') {
                    reason += 'Story status must be "Voting" (current: ' + storyCheck.Status__c + ')';
                } else if (storyCheck.Votes_Revealed__c) {
                    reason += 'Votes have already been revealed.';
                } else {
                    reason += 'Please check your room membership status.';
                }
                AuraHandledException ex = new AuraHandledException(reason);
                ex.setMessage(reason);
                throw ex;
            }

            // Get room member details
            Room_Member__c member = [
                SELECT Id, User__c, User__r.Name, Room__c, Room__r.Estimation_Scale__c
                FROM Room_Member__c
                WHERE Id = :roomMemberId
                LIMIT 1
            ];

            // Check for existing vote
            List<Estimation_Vote__c> existingVotes = [
                SELECT Id, Vote_Value__c
                FROM Estimation_Vote__c
                WHERE User_Story__c = :storyId
                AND Room_Member__c = :roomMemberId
                LIMIT 1
            ];

            Estimation_Vote__c vote;
            String action;

            // Convert vote to numeric value
            Decimal numericValue = EstimationService.convertVoteToNumber(
                voteValue,
                member.Room__r.Estimation_Scale__c
            );

            if (!existingVotes.isEmpty()) {
                // Update existing vote
                vote = existingVotes[0];
                vote.Vote_Value__c = voteValue;
                vote.Vote_Number__c = numericValue;
                vote.Voted_DateTime__c = Datetime.now();
                vote.Comment__c = voteComment;
                vote.Confidence_Level__c = confidenceLevel;
                vote.Duration__c = duration;
                update vote;
                action = 'vote_updated';
            } else {
                // Create new vote
                vote = new Estimation_Vote__c(
                    User_Story__c = storyId,
                    Room_Member__c = roomMemberId,
                    Vote_Value__c = voteValue,
                    Vote_Number__c = numericValue,
                    Voted_DateTime__c = Datetime.now(),
                    Revealed__c = false,
                    Comment__c = voteComment,
                    Confidence_Level__c = confidenceLevel,
                    Duration__c = duration
                );
                insert vote;
                action = 'voted';
            }

            // Get vote count and total members (exclude automated process users)
            Integer voteCount = [
                SELECT COUNT() FROM Estimation_Vote__c WHERE User_Story__c = :storyId
            ];

            Integer totalMembers = [
                SELECT COUNT() FROM Room_Member__c
                WHERE Room__c = :member.Room__c
                AND Can_Vote__c = true
                AND (Status__c = 'Active' OR Status__c = 'Invited')
                AND User__r.UserType != 'AutomatedProcess'
            ];

            // Publish vote event
            PlatformEventPublisher.publishVoteEvent(
                member.Room__c,
                storyId,
                roomMemberId,
                member.User__c,
                member.User__r.Name,
                action,
                null, // Don't reveal vote value
                false,
                voteCount,
                totalMembers,
                duration
            );

            return vote;
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is to preserve the message
            throw e;
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Gets votes for a story
     * @param storyId The story to get votes for
     * @param revealed Whether votes should be shown as revealed
     * @return Map containing votes list, counts, and statistics
     */
    @AuraEnabled
    public static Map<String, Object> getVotesForStory(Id storyId, Boolean revealed) {
        try {
            User_Story__c story = [
                SELECT Id, Votes_Revealed__c, Room__c, Room__r.Estimation_Scale__c, Status__c
                FROM User_Story__c
                WHERE Id = :storyId
                LIMIT 1
            ];

            List<Estimation_Vote__c> votes = [
                SELECT Id, Vote_Value__c, Vote_Number__c, Comment__c, Revealed__c,
                       Room_Member__c, Room_Member__r.User__c,
                       Room_Member__r.User__r.Name, Room_Member__r.User__r.SmallPhotoUrl,
                       Voted_DateTime__c, Duration__c
                FROM Estimation_Vote__c
                WHERE User_Story__c = :storyId
                ORDER BY Voted_DateTime__c
            ];

            // Get all voting members to show who hasn't voted
            // Exclude system users like 'Automated Process'
            List<Room_Member__c> votingMembers = [
                SELECT Id, User__c, User__r.Name, User__r.SmallPhotoUrl
                FROM Room_Member__c
                WHERE Room__c = :story.Room__c
                AND Can_Vote__c = true
                AND (Status__c = 'Active' OR Status__c = 'Invited')
                AND User__r.UserType != 'AutomatedProcess'
            ];

            Set<Id> votedMemberIds = new Set<Id>();
            List<Map<String, Object>> votesList = new List<Map<String, Object>>();

            for (Estimation_Vote__c vote : votes) {
                votedMemberIds.add(vote.Room_Member__c);

                Map<String, Object> voteMap = new Map<String, Object>{
                    'id' => vote.Id,
                    'roomMemberId' => vote.Room_Member__c,
                    'odataUserId' => vote.Room_Member__r.User__c,
                    'voterName' => vote.Room_Member__r.User__r.Name,
                    'voterPhoto' => vote.Room_Member__r.User__r.SmallPhotoUrl,
                    'hasVoted' => true,
                    'votedAt' => vote.Voted_DateTime__c,
                    'duration' => vote.Duration__c
                };

                // Only include vote value if revealed OR story is Estimated
                if (revealed || story.Votes_Revealed__c || story.Status__c == 'Estimated') {
                    voteMap.put('value', vote.Vote_Value__c);
                    voteMap.put('numericValue', vote.Vote_Number__c);
                    voteMap.put('comment', vote.Comment__c);
                }

                votesList.add(voteMap);
            }

            // Add members who haven't voted
            for (Room_Member__c member : votingMembers) {
                if (!votedMemberIds.contains(member.Id)) {
                    votesList.add(new Map<String, Object>{
                        'roomMemberId' => member.Id,
                        'odataUserId' => member.User__c,
                        'voterName' => member.User__r.Name,
                        'voterPhoto' => member.User__r.SmallPhotoUrl,
                        'hasVoted' => false
                    });
                }
            }

            Map<String, Object> result = new Map<String, Object>{
                'votes' => votesList,
                'voteCount' => votes.size(),
                'totalMembers' => votingMembers.size(),
                'allVoted' => votes.size() == votingMembers.size(),
                'revealed' => story.Votes_Revealed__c
            };

            // Add statistics if revealed
            if (revealed || story.Votes_Revealed__c) {
                result.put('statistics', EstimationService.getVoteStatistics(votes));
            }

            return result;
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Reveals all votes for a story
     * @param storyId The story to reveal votes for
     * @return Map containing vote statistics
     */
    @AuraEnabled
    public static Map<String, Object> revealVotes(Id storyId) {
        try {
            User_Story__c story = [
                SELECT Id, Room__c, Status__c, Votes_Revealed__c
                FROM User_Story__c
                WHERE Id = :storyId
                LIMIT 1
            ];

            // Security check: Only facilitators can reveal votes
            if (!ValidationService.canManageRoom(story.Room__c, UserInfo.getUserId())) {
                AuraHandledException ex = new AuraHandledException('Only facilitators can reveal votes');
                ex.setMessage('Only facilitators can reveal votes');
                throw ex;
            }

            // Update votes to revealed
            List<Estimation_Vote__c> votes = [
                SELECT Id, Vote_Value__c, Vote_Number__c, Comment__c, Duration__c,
                       Voted_DateTime__c, Room_Member__c,
                       Room_Member__r.User__c, Room_Member__r.User__r.Name,
                       Room_Member__r.User__r.SmallPhotoUrl
                FROM Estimation_Vote__c
                WHERE User_Story__c = :storyId
            ];

            for (Estimation_Vote__c vote : votes) {
                vote.Revealed__c = true;
            }
            update votes;

            // Update story
            story.Votes_Revealed__c = true;
            if (story.Status__c == 'Voting') {
                story.Status__c = 'Discussing';
            }

            // Calculate and update average
            Decimal average = EstimationService.calculateAverage(votes);
            story.Average_Estimate__c = average;

            update story;

            // Build all votes JSON with full detail for the results component
            List<Map<String, Object>> allVotesDataList = new List<Map<String, Object>>();
            for (Estimation_Vote__c vote : votes) {
                allVotesDataList.add(new Map<String, Object>{
                    'odataUserId' => vote.Room_Member__r.User__c,
                    'voterName' => vote.Room_Member__r.User__r.Name,
                    'voterPhoto' => vote.Room_Member__r.User__r.SmallPhotoUrl,
                    'value' => vote.Vote_Value__c,
                    'numericValue' => vote.Vote_Number__c,
                    'comment' => vote.Comment__c,
                    'duration' => (Integer)vote.Duration__c,
                    'votedAt' => vote.Voted_DateTime__c,
                    'hasVoted' => true
                });
            }

            Map<String, Object> statistics = EstimationService.getVoteStatistics(votes);

            Map<String, Object> eventPayload = new Map<String, Object>{
                'votes' => allVotesDataList,
                'statistics' => statistics
            };

            String allVotesJson = JSON.serialize(eventPayload);

            // Publish votes revealed event
            PlatformEventPublisher.publishVotesRevealedEvent(
                story.Room__c,
                storyId,
                allVotesJson
            );

            // Return statistics
            return statistics;
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Resets votes for a story (for re-voting)
     * @param storyId The story to reset votes for
     */
    @AuraEnabled
    public static void resetVotes(Id storyId) {
        try {
            User_Story__c story = [
                SELECT Id, Room__c
                FROM User_Story__c
                WHERE Id = :storyId
                LIMIT 1
            ];

            // Security check: Only facilitators can reset votes
            if (!ValidationService.canManageRoom(story.Room__c, UserInfo.getUserId())) {
                AuraHandledException ex = new AuraHandledException('Only facilitators can reset votes');
                ex.setMessage('Only facilitators can reset votes');
                throw ex;
            }

            // Delete all votes
            List<Estimation_Vote__c> votesToDelete = [SELECT Id FROM Estimation_Vote__c WHERE User_Story__c = :storyId];
            delete votesToDelete;

            // Reset story
            Datetime now = Datetime.now();
            story.Votes_Revealed__c = false;
            story.Average_Estimate__c = null;
            story.Status__c = 'Voting';
            story.Voting_Start_Time__c = now;
            update story;

            // Build additional data for sync
            Map<String, Object> data = new Map<String, Object>{
                'votingStartTime' => now
            };

            // Publish reset event
            PlatformEventPublisher.publishVoteEvent(
                story.Room__c,
                storyId,
                null,
                UserInfo.getUserId(),
                UserInfo.getName(),
                'votes_reset',
                null,
                false,
                0,
                null,
                null
            );

            // Publish a follow-up room event
            PlatformEventPublisher.publishRoomEvent(
                story.Room__c,
                'votes_reset',
                UserInfo.getUserId(),
                UserInfo.getName(),
                storyId,
                null,
                null,
                null,
                JSON.serialize(data)
            );
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Finalizes the estimate for a story
     * @param storyId The story to finalize
     * @param finalValue The final estimate value
     */
    @AuraEnabled
    public static void finalizeEstimate(Id storyId, String finalValue) {
        try {
            // Get story and room details first for security check
            User_Story__c story = [
                SELECT Id, Room__c, Room__r.Estimation_Scale__c
                FROM User_Story__c
                WHERE Id = :storyId
                LIMIT 1
            ];

            // Security check: Only facilitators can finalize estimates
            if (!ValidationService.canManageRoom(story.Room__c, UserInfo.getUserId())) {
                AuraHandledException ex = new AuraHandledException('Only facilitators can finalize estimates');
                ex.setMessage('Only facilitators can finalize estimates');
                throw ex;
            }

            // Validate finalized estimate
            ValidationService.validateFinalizeEstimate(storyId);

            // Get vote summary for event
            List<Estimation_Vote__c> votes = [
                SELECT Vote_Value__c, Vote_Number__c, Duration__c,
                       Room_Member__r.User__r.Name
                FROM Estimation_Vote__c
                WHERE User_Story__c = :storyId
            ];

            Map<String, Object> summary = EstimationService.getVoteStatistics(votes);
            summary.put('finalEstimate', finalValue);
            summary.put('votesCount', votes.size());

            // Update story
            story.Final_Estimate__c = finalValue;
            story.Status__c = 'Estimated';
            story.Votes_Revealed__c = true;
            story.Estimated_Date__c = Datetime.now();
            story.Estimated_By__c = UserInfo.getUserId();
            update story;

            // Publish finalized event
            PlatformEventPublisher.publishEstimateFinalizedEvent(
                story.Room__c,
                storyId,
                finalValue,
                JSON.serialize(summary)
            );

            // Also publish story event
            PlatformEventPublisher.publishStoryEvent(
                story.Room__c,
                storyId,
                'estimated',
                null,
                'Estimated',
                finalValue,
                null,
                UserInfo.getUserId(),
                null
            );
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Gets voting statistics for a story
     * @param storyId The story to calculate statistics for
     * @return Map containing vote statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> calculateStatistics(Id storyId) {
        try {
            List<Estimation_Vote__c> votes = [
                SELECT Id, Vote_Value__c, Vote_Number__c, Duration__c
                FROM Estimation_Vote__c
                WHERE User_Story__c = :storyId
            ];

            return EstimationService.getVoteStatistics(votes);
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Gets the current user's vote for a story
     * @param storyId The story to check
     * @param roomMemberId The room member to check
     * @return The vote record or null
     */
    @AuraEnabled
    public static Estimation_Vote__c getCurrentUserVote(Id storyId, Id roomMemberId) {
        try {
            List<Estimation_Vote__c> votes = [
                SELECT Id, Vote_Value__c, Vote_Number__c, Comment__c, Voted_DateTime__c, Duration__c
                FROM Estimation_Vote__c
                WHERE User_Story__c = :storyId
                AND Room_Member__c = :roomMemberId
                LIMIT 1
            ];

            return votes.isEmpty() ? null : votes[0];
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Deletes the current user's vote
     * @param storyId The story to delete vote from
     * @param roomMemberId The room member whose vote to delete
     */
    @AuraEnabled
    public static void deleteVote(Id storyId, Id roomMemberId) {
        try {
            Room_Member__c member = [
                SELECT Id, User__c, User__r.Name, Room__c
                FROM Room_Member__c
                WHERE Id = :roomMemberId
                LIMIT 1
            ];

            delete [
                SELECT Id FROM Estimation_Vote__c
                WHERE User_Story__c = :storyId
                AND Room_Member__c = :roomMemberId
            ];

            // Get updated vote count (exclude automated process users)
            Integer voteCount = [
                SELECT COUNT() FROM Estimation_Vote__c WHERE User_Story__c = :storyId
            ];

            Integer totalMembers = [
                SELECT COUNT() FROM Room_Member__c
                WHERE Room__c = :member.Room__c
                AND Can_Vote__c = true
                AND (Status__c = 'Active' OR Status__c = 'Invited')
                AND User__r.UserType != 'AutomatedProcess'
            ];

            // Publish event
            PlatformEventPublisher.publishVoteEvent(
                member.Room__c,
                storyId,
                roomMemberId,
                member.User__c,
                member.User__r.Name,
                'vote_deleted',
                null,
                false,
                voteCount,
                totalMembers,
                null
            );
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Gets vote history for all stories in a room
     * @param roomId The room to get vote history for
     * @return List of maps containing story vote history data
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getVoteHistory(Id roomId) {
        try {
            List<Map<String, Object>> history = new List<Map<String, Object>>();

            // Get all stories with revealed votes
            List<User_Story__c> stories = [
                SELECT Id, Story_Title__c, Status__c, Final_Estimate__c,
                       Votes_Revealed__c, Average_Estimate__c, Estimated_Date__c
                FROM User_Story__c
                WHERE Room__c = :roomId
                AND (Votes_Revealed__c = true OR Status__c = 'Estimated')
                ORDER BY LastModifiedDate DESC NULLS LAST, CreatedDate DESC
            ];

            if (stories.isEmpty()) {
                return history;
            }

            Set<Id> storyIds = new Set<Id>();
            for (User_Story__c story : stories) {
                storyIds.add(story.Id);
            }

            // Get all votes for these stories
            List<Estimation_Vote__c> allVotes = [
                SELECT Id, Vote_Value__c, Vote_Number__c, Comment__c,
                       Confidence_Level__c, Voted_DateTime__c, Duration__c,
                       User_Story__c, User_Story__r.Story_Title__c,
                       Room_Member__c, Room_Member__r.User__c,
                       Room_Member__r.User__r.Name, Room_Member__r.User__r.SmallPhotoUrl
                FROM Estimation_Vote__c
                WHERE User_Story__c IN :storyIds
                ORDER BY Voted_DateTime__c ASC
            ];

            // Group votes by story
            Map<Id, List<Estimation_Vote__c>> votesByStory = new Map<Id, List<Estimation_Vote__c>>();
            for (Estimation_Vote__c vote : allVotes) {
                if (!votesByStory.containsKey(vote.User_Story__c)) {
                    votesByStory.put(vote.User_Story__c, new List<Estimation_Vote__c>());
                }
                votesByStory.get(vote.User_Story__c).add(vote);
            }

            // Build history response
            for (User_Story__c story : stories) {
                List<Map<String, Object>> storyVotes = new List<Map<String, Object>>();

                if (votesByStory.containsKey(story.Id)) {
                    for (Estimation_Vote__c vote : votesByStory.get(story.Id)) {
                        storyVotes.add(new Map<String, Object>{
                            'odataUserId' => vote.Room_Member__r.User__c,
                            'voterName' => vote.Room_Member__r.User__r.Name,
                            'voterPhoto' => vote.Room_Member__r.User__r.SmallPhotoUrl,
                            'voteValue' => vote.Vote_Value__c,
                            'numericValue' => vote.Vote_Number__c,
                            'comment' => vote.Comment__c,
                            'confidence' => vote.Confidence_Level__c,
                            'votedAt' => vote.Voted_DateTime__c,
                            'duration' => vote.Duration__c
                        });
                    }
                }

                history.add(new Map<String, Object>{
                    'storyId' => story.Id,
                    'storyTitle' => story.Story_Title__c,
                    'status' => story.Status__c,
                    'finalEstimate' => story.Final_Estimate__c,
                    'averageEstimate' => story.Average_Estimate__c,
                    'estimatedDate' => story.Estimated_Date__c,
                    'votes' => storyVotes,
                    'voteCount' => storyVotes.size()
                });
            }

            return history;
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }

    /**
     * @description Broadcasts a timer event to all room members
     * @param roomId The room to broadcast to
     * @param action The timer action (timer_start, timer_pause, etc.)
     * @param durationInSeconds Timer duration in seconds
     */
    @AuraEnabled
    public static void broadcastTimer(Id roomId, String action, Integer durationInSeconds) {
        try {
            // Verify user can manage room (facilitator only)
            if (!ValidationService.canManageRoom(roomId, UserInfo.getUserId())) {
                throw new AuraHandledException('Only facilitators can control the timer');
            }

            Map<String, Object> data = new Map<String, Object>();
            if (durationInSeconds != null) {
                data.put('duration', durationInSeconds);
            }

            // Publish room event
            PlatformEventPublisher.publishRoomEvent(
                roomId,
                action,
                UserInfo.getUserId(),
                UserInfo.getName(),
                null,
                null,
                null,
                null,
                JSON.serialize(data)
            );
        } catch (Exception e) {
            String msg = e.getMessage();
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }
}