/**
 * @description Controller for In-App Guidance System
 */
public with sharing class GuidanceController {

    /**
     * @description Gets user's guidance progress state for a given context
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserGuidanceState(String context) {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Get all completed guidances for user
            List<User_Guidance_Progress__c> completedGuidances = [
                SELECT Id, Guidance_Name__c, Completed__c, Completed_Date__c, Context__c
                FROM User_Guidance_Progress__c
                WHERE User__c = :currentUserId
                AND Completed__c = true
            ];

            Set<String> completedNames = new Set<String>();
            for (User_Guidance_Progress__c progress : completedGuidances) {
                completedNames.add(progress.Guidance_Name__c);
            }

            // Define guidance items by context
            Map<String, List<Map<String, Object>>> guidanceByContext = getGuidanceDefinitions();

            List<Map<String, Object>> contextGuidance = guidanceByContext.containsKey(context)
                ? guidanceByContext.get(context)
                : new List<Map<String, Object>>();

            // Mark which ones are completed
            List<Map<String, Object>> guidanceItems = new List<Map<String, Object>>();
            for (Map<String, Object> item : contextGuidance) {
                Map<String, Object> enrichedItem = new Map<String, Object>(item);
                enrichedItem.put('completed', completedNames.contains((String) item.get('name')));
                guidanceItems.add(enrichedItem);
            }

            // Calculate progress
            Integer total = guidanceItems.size();
            Integer completed = 0;
            for (Map<String, Object> item : guidanceItems) {
                if ((Boolean) item.get('completed')) {
                    completed++;
                }
            }

            return new Map<String, Object>{
                'guidanceItems' => guidanceItems,
                'totalItems' => total,
                'completedItems' => completed,
                'progressPercent' => total > 0 ? (completed * 100 / total) : 100,
                'isFirstTimeUser' => completedGuidances.isEmpty()
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Marks a guidance item as completed
     */
    @AuraEnabled
    public static void completeGuidance(String guidanceName) {
        try {
            Id currentUserId = UserInfo.getUserId();

            // Check if already completed
            List<User_Guidance_Progress__c> existing = [
                SELECT Id FROM User_Guidance_Progress__c
                WHERE User__c = :currentUserId
                AND Guidance_Name__c = :guidanceName
                LIMIT 1
            ];

            if (existing.isEmpty()) {
                insert new User_Guidance_Progress__c(
                    User__c = currentUserId,
                    Guidance_Name__c = guidanceName,
                    Completed__c = true,
                    Completed_Date__c = Datetime.now()
                );
            } else {
                existing[0].Completed__c = true;
                existing[0].Completed_Date__c = Datetime.now();
                update existing;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets help content for a specific component using Custom Metadata
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getHelpForContext(String component) {
        try {
            List<Help_Content__mdt> articles = [
                SELECT DeveloperName, MasterLabel, Content__c, Category__c, Order__c
                FROM Help_Content__mdt
                WHERE Context__c = :component
                AND Active__c = true
                ORDER BY Order__c NULLS LAST, MasterLabel
            ];

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (Help_Content__mdt article : articles) {
                result.add(new Map<String, Object>{
                    'Id' => article.DeveloperName,
                    'Name' => article.MasterLabel,
                    'Content__c' => article.Content__c,
                    'Category__c' => article.Category__c,
                    'Order__c' => article.Order__c
                });
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Searches help articles in Custom Metadata
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> searchHelp(String searchTerm) {
        try {
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                return new List<Map<String, Object>>();
            }

            String searchPattern = '%' + searchTerm.toLowerCase() + '%';
            List<Help_Content__mdt> allArticles = [
                SELECT DeveloperName, MasterLabel, Content__c, Category__c, Context__c
                FROM Help_Content__mdt
                WHERE Active__c = true
                ORDER BY Category__c, MasterLabel
            ];

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (Help_Content__mdt article : allArticles) {
                // Manual search since CMDT doesn't support LIKE on custom fields
                if (article.MasterLabel.toLowerCase().contains(searchTerm.toLowerCase()) ||
                    (article.Content__c != null && article.Content__c.toLowerCase().contains(searchTerm.toLowerCase()))) {
                    result.add(new Map<String, Object>{
                        'Id' => article.DeveloperName,
                        'Name' => article.MasterLabel,
                        'Content__c' => article.Content__c,
                        'Category__c' => article.Category__c,
                        'Context__c' => article.Context__c
                    });
                }
                if (result.size() >= 20) break;
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Submits feedback for a guidance item
     */
    @AuraEnabled
    public static void submitFeedback(String guidanceName, Integer rating, String comments) {
        try {
            insert new Guidance_Feedback__c(
                User__c = UserInfo.getUserId(),
                Guidance_Name__c = guidanceName,
                Rating__c = rating,
                Comments__c = comments
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets all help articles by category from Custom Metadata
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, Object>>> getHelpArticlesByCategory() {
        try {
            List<Help_Content__mdt> articles = [
                SELECT DeveloperName, MasterLabel, Content__c, Category__c, Context__c, Order__c
                FROM Help_Content__mdt
                WHERE Active__c = true
                ORDER BY Category__c, Order__c NULLS LAST, MasterLabel
            ];

            Map<String, List<Map<String, Object>>> articlesByCategory =
                new Map<String, List<Map<String, Object>>>();

            for (Help_Content__mdt article : articles) {
                String category = String.isNotBlank(article.Category__c)
                    ? article.Category__c : 'General';

                if (!articlesByCategory.containsKey(category)) {
                    articlesByCategory.put(category, new List<Map<String, Object>>());
                }
                articlesByCategory.get(category).add(new Map<String, Object>{
                    'Id' => article.DeveloperName,
                    'Name' => article.MasterLabel,
                    'Content__c' => article.Content__c,
                    'Category__c' => article.Category__c,
                    'Context__c' => article.Context__c,
                    'Order__c' => article.Order__c
                });
            }

            return articlesByCategory;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets walkthrough tour steps for a given tour
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTourSteps(String tourName) {
        try {
            Map<String, List<Map<String, Object>>> tours = getTourDefinitions();

            if (tours.containsKey(tourName)) {
                return tours.get(tourName);
            }

            return new List<Map<String, Object>>();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Resets all guidance progress for current user (for testing)
     */
    @AuraEnabled
    public static void resetGuidanceProgress() {
        try {
            delete [
                SELECT Id FROM User_Guidance_Progress__c
                WHERE User__c = :UserInfo.getUserId()
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Returns guidance definitions organized by context
     */
    private static Map<String, List<Map<String, Object>>> getGuidanceDefinitions() {
        return new Map<String, List<Map<String, Object>>>{
            'roomList' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'name' => 'welcome_prompt',
                    'title' => 'Welcome to Planning Poker!',
                    'description' => 'Learn how to create and manage estimation sessions',
                    'type' => 'prompt'
                },
                new Map<String, Object>{
                    'name' => 'create_first_room',
                    'title' => 'Create Your First Room',
                    'description' => 'Click the New Room button to create your first estimation session',
                    'type' => 'tooltip',
                    'targetElement' => 'newRoomButton'
                }
            },
            'roomCreation' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'name' => 'room_name_tip',
                    'title' => 'Room Name',
                    'description' => 'Give your room a descriptive name like "Sprint 24 Planning"',
                    'type' => 'tooltip',
                    'targetElement' => 'roomNameInput'
                },
                new Map<String, Object>{
                    'name' => 'estimation_scale_tip',
                    'title' => 'Estimation Scale',
                    'description' => 'Fibonacci is the most popular choice for story points',
                    'type' => 'tooltip',
                    'targetElement' => 'scaleSelect'
                }
            },
            'estimationSession' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'name' => 'how_to_vote',
                    'title' => 'How to Vote',
                    'description' => 'Click on a card to cast your vote. You can change your vote until votes are revealed.',
                    'type' => 'prompt'
                },
                new Map<String, Object>{
                    'name' => 'reveal_votes_tip',
                    'title' => 'Reveal Votes',
                    'description' => 'As a facilitator, click Reveal Votes when everyone has voted',
                    'type' => 'tooltip',
                    'targetElement' => 'revealButton',
                    'facilitatorOnly' => true
                }
            },
            'voteResults' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'name' => 'understand_results',
                    'title' => 'Understanding Results',
                    'description' => 'The chart shows vote distribution. Discuss outliers before finalizing.',
                    'type' => 'prompt'
                },
                new Map<String, Object>{
                    'name' => 'finalize_estimate',
                    'title' => 'Finalize Estimate',
                    'description' => 'Select the final estimate or click the most common value',
                    'type' => 'tooltip',
                    'targetElement' => 'finalizeButton',
                    'facilitatorOnly' => true
                }
            }
        };
    }

    /**
     * @description Returns tour definitions
     */
    private static Map<String, List<Map<String, Object>>> getTourDefinitions() {
        return new Map<String, List<Map<String, Object>>>{
            'gettingStarted' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'step' => 1,
                    'title' => 'Welcome to Planning Poker',
                    'content' => 'Planning Poker is a consensus-based estimation technique for Agile teams.',
                    'target' => null
                },
                new Map<String, Object>{
                    'step' => 2,
                    'title' => 'Create a Room',
                    'content' => 'Start by creating a room for your estimation session.',
                    'target' => 'newRoomButton'
                },
                new Map<String, Object>{
                    'step' => 3,
                    'title' => 'Add Team Members',
                    'content' => 'Invite your team members to join the estimation session.',
                    'target' => 'addMembersButton'
                },
                new Map<String, Object>{
                    'step' => 4,
                    'title' => 'Add Stories',
                    'content' => 'Add the user stories you want to estimate.',
                    'target' => 'addStoryButton'
                },
                new Map<String, Object>{
                    'step' => 5,
                    'title' => 'Start Voting',
                    'content' => 'Everyone votes simultaneously by selecting a card.',
                    'target' => 'pokerCards'
                },
                new Map<String, Object>{
                    'step' => 6,
                    'title' => 'Reveal and Discuss',
                    'content' => 'Reveal votes, discuss differences, and reach consensus.',
                    'target' => 'revealButton'
                }
            },
            'facilitatorGuide' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'step' => 1,
                    'title' => 'Facilitator Role',
                    'content' => 'As a facilitator, you control the flow of the estimation session.',
                    'target' => null
                },
                new Map<String, Object>{
                    'step' => 2,
                    'title' => 'Managing Stories',
                    'content' => 'You can add, reorder, and skip stories during the session.',
                    'target' => 'storyManager'
                },
                new Map<String, Object>{
                    'step' => 3,
                    'title' => 'Starting Votes',
                    'content' => 'Select a story to begin voting. All participants will see the story.',
                    'target' => 'storyQueue'
                },
                new Map<String, Object>{
                    'step' => 4,
                    'title' => 'Revealing Votes',
                    'content' => 'Click Reveal when everyone has voted to show all votes.',
                    'target' => 'revealButton'
                },
                new Map<String, Object>{
                    'step' => 5,
                    'title' => 'Discussion Time',
                    'content' => 'Encourage discussion when there are large differences in votes.',
                    'target' => 'voteResults'
                },
                new Map<String, Object>{
                    'step' => 6,
                    'title' => 'Finalizing Estimates',
                    'content' => 'Set the final estimate based on team consensus.',
                    'target' => 'finalizeSection'
                }
            },
            'teamMemberGuide' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'step' => 1,
                    'title' => 'Team Member Role',
                    'content' => 'As a team member, you estimate stories by selecting cards.',
                    'target' => null
                },
                new Map<String, Object>{
                    'step' => 2,
                    'title' => 'Reading Stories',
                    'content' => 'Read the story description and acceptance criteria carefully.',
                    'target' => 'currentStory'
                },
                new Map<String, Object>{
                    'step' => 3,
                    'title' => 'Selecting a Card',
                    'content' => 'Click on a card that represents your estimate.',
                    'target' => 'pokerCards'
                },
                new Map<String, Object>{
                    'step' => 4,
                    'title' => 'Special Cards',
                    'content' => 'Use ? if you need more information, or coffee break if you need a pause.',
                    'target' => 'specialCards'
                },
                new Map<String, Object>{
                    'step' => 5,
                    'title' => 'Changing Your Vote',
                    'content' => 'You can change your vote any time before reveal.',
                    'target' => 'selectedCard'
                },
                new Map<String, Object>{
                    'step' => 6,
                    'title' => 'Discussing Results',
                    'content' => 'Explain your reasoning if your vote differs significantly.',
                    'target' => 'voteResults'
                }
            }
        };
    }
}