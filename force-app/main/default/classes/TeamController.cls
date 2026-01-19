/**
 * @description Controller for Team management operations
 */
public without sharing class TeamController {

    /**
     * @description Creates a new team
     */
    @AuraEnabled
    public static Team__c createTeam(Map<String, Object> teamData) {
        try {
            Team__c team = new Team__c(
                Name = (String) teamData.get('name'),
                Description__c = (String) teamData.get('description'),
                Department__c = (String) teamData.get('department'),
                Team_Lead__c = UserInfo.getUserId(),
                Active__c = true
            );

            insert team;

            // Add creator as team member with Scrum Master role
            insert new Team_Member__c(
                Team__c = team.Id,
                User__c = UserInfo.getUserId(),
                Role__c = 'Scrum Master',
                Joined_Date__c = Date.today(),
                Active__c = true
            );

            // Publish Team Created Event
            PlatformEventPublisher.publishTeamEvent(
                team.Id,
                'team_created',
                UserInfo.getUserId(),
                UserInfo.getName(),
                JSON.serialize(new Map<String, Object>{
                    'name' => team.Name,
                    'department' => team.Department__c
                })
            );

            return team;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets all teams with member counts
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllTeams() {
        try {
            List<Team__c> teamList = [
                SELECT Id, Name, Description__c, Department__c,
                       Team_Lead__c, Team_Lead__r.Name, Active__c,
                       CreatedDate
                FROM Team__c
                WHERE Active__c = true
                ORDER BY Name
            ];

            Set<Id> teamIds = new Set<Id>();
            for (Team__c t : teamList) {
                teamIds.add(t.Id);
            }

            // Get member counts
            Map<Id, Integer> memberCounts = new Map<Id, Integer>();
            for (AggregateResult ar : [
                SELECT Team__c, COUNT(Id) cnt
                FROM Team_Member__c
                WHERE Team__c IN :teamIds AND Active__c = true
                GROUP BY Team__c
            ]) {
                memberCounts.put((Id) ar.get('Team__c'), ((Decimal) ar.get('cnt')).intValue());
            }

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (Team__c team : teamList) {
                result.add(new Map<String, Object>{
                    'id' => team.Id,
                    'name' => team.Name,
                    'description' => team.Description__c,
                    'department' => team.Department__c,
                    'teamLead' => team.Team_Lead__r?.Name,
                    'memberCount' => memberCounts.get(team.Id) != null ? memberCounts.get(team.Id) : 0
                });
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets teams for the current user
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTeamsForUser(Id odataUserId) {
        try {
            Id targetUserId = odataUserId != null ? odataUserId : UserInfo.getUserId();

            List<Team_Member__c> memberships = [
                SELECT Id, Team__c, Team__r.Id, Team__r.Name, Team__r.Description__c,
                       Team__r.Department__c, Team__r.Team_Lead__r.Name,
                       Team__r.Active__c, Role__c
                FROM Team_Member__c
                WHERE User__c = :targetUserId
                AND Active__c = true
                AND Team__r.Active__c = true
                ORDER BY Team__r.Name
            ];

            List<Map<String, Object>> teams = new List<Map<String, Object>>();
            Set<Id> teamIds = new Set<Id>();

            for (Team_Member__c membership : memberships) {
                teamIds.add(membership.Team__c);
            }

            // Get member counts
            Map<Id, Integer> memberCounts = new Map<Id, Integer>();
            for (AggregateResult ar : [
                SELECT Team__c, COUNT(Id) cnt
                FROM Team_Member__c
                WHERE Team__c IN :teamIds AND Active__c = true
                GROUP BY Team__c
            ]) {
                memberCounts.put((Id) ar.get('Team__c'), ((Decimal) ar.get('cnt')).intValue());
            }

            for (Team_Member__c membership : memberships) {
                teams.add(new Map<String, Object>{
                    'id' => membership.Team__r.Id,
                    'name' => membership.Team__r.Name,
                    'description' => membership.Team__r.Description__c,
                    'department' => membership.Team__r.Department__c,
                    'teamLead' => membership.Team__r.Team_Lead__r.Name,
                    'myRole' => membership.Role__c,
                    'memberCount' => memberCounts.get(membership.Team__c)
                });
            }

            return teams;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets team members
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getTeamMembers(Id teamId) {
        try {
            List<Team_Member__c> members = [
                SELECT Id, User__c, User__r.Name, User__r.Email,
                       User__r.SmallPhotoUrl, User__r.Title,
                       Role__c, Joined_Date__c, Active__c
                FROM Team_Member__c
                WHERE Team__c = :teamId
                AND Active__c = true
                ORDER BY User__r.Name
            ];

            List<Map<String, Object>> memberList = new List<Map<String, Object>>();
            for (Team_Member__c member : members) {
                memberList.add(new Map<String, Object>{
                    'id' => member.Id,
                    'odataUserId' => member.User__c,
                    'name' => member.User__r.Name,
                    'email' => member.User__r.Email,
                    'photoUrl' => member.User__r.SmallPhotoUrl,
                    'title' => member.User__r.Title,
                    'role' => member.Role__c,
                    'joinedDate' => member.Joined_Date__c
                });
            }

            return memberList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Adds a team member
     */
    @AuraEnabled
    public static Team_Member__c addTeamMember(Id teamId, Id odataUserId, String role) {
        try {
            // Check for existing records (active or inactive)
            List<Team_Member__c> existing = [
                SELECT Id, Active__c FROM Team_Member__c 
                WHERE Team__c = :teamId AND User__c = :odataUserId 
                LIMIT 1
            ];

            Team_Member__c member;
            if (!existing.isEmpty()) {
                member = existing[0];
                if (member.Active__c) {
                    throw new ValidationService.ValidationException('User is already an active member of this team');
                }
                // Reactivate
                member.Active__c = true;
                member.Role__c = String.isNotBlank(role) ? role : 'Developer';
                member.Joined_Date__c = Date.today();
                update member;
            } else {
                // New member
                member = new Team_Member__c(
                    Team__c = teamId,
                    User__c = odataUserId,
                    Role__c = String.isNotBlank(role) ? role : 'Developer',
                    Joined_Date__c = Date.today(),
                    Active__c = true
                );
                insert member;
            }

            // Publish Member Added Event
            User u = [SELECT Name FROM User WHERE Id = :odataUserId LIMIT 1];
            PlatformEventPublisher.publishTeamEvent(
                teamId,
                'member_added',
                odataUserId,
                u.Name,
                JSON.serialize(new Map<String, Object>{
                    'role' => role,
                    'memberId' => member.Id
                })
            );

            return member;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Removes a team member
     */
    @AuraEnabled
    public static void removeTeamMember(Id teamMemberId) {
        try {
            Team_Member__c member = [
                SELECT Id, User__c, Team__c, Active__c
                FROM Team_Member__c
                WHERE Id = :teamMemberId
                LIMIT 1
            ];

            member.Active__c = false;
            update member;

            // Publish Member Removed Event
            User u = [SELECT Name FROM User WHERE Id = :member.User__c LIMIT 1];
            PlatformEventPublisher.publishTeamEvent(
                member.Team__c,
                'member_removed',
                member.User__c,
                u.Name,
                JSON.serialize(new Map<String, Object>{
                    'memberId' => member.Id
                })
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Updates team member role
     */
    @AuraEnabled
    public static void updateTeamMemberRole(Id teamMemberId, String role) {
        try {
            update new Team_Member__c(
                Id = teamMemberId,
                Role__c = role
            );

            // Publish Role Updated Event
            Team_Member__c member = [SELECT Team__c, User__c, User__r.Name FROM Team_Member__c WHERE Id = :teamMemberId LIMIT 1];
            PlatformEventPublisher.publishTeamEvent(
                member.Team__c,
                'role_updated',
                member.User__c,
                member.User__r.Name,
                JSON.serialize(new Map<String, Object>{
                    'newRole' => role,
                    'memberId' => teamMemberId
                })
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Updates team details
     */
    @AuraEnabled
    public static Team__c updateTeam(Id teamId, Map<String, Object> teamData) {
        try {
            Team__c team = [
                SELECT Id, Name, Description__c, Department__c, Team_Lead__c
                FROM Team__c
                WHERE Id = :teamId
                LIMIT 1
            ];

            if (teamData.containsKey('name')) {
                team.Name = (String) teamData.get('name');
            }
            if (teamData.containsKey('description')) {
                team.Description__c = (String) teamData.get('description');
            }
            if (teamData.containsKey('department')) {
                team.Department__c = (String) teamData.get('department');
            }
            if (teamData.containsKey('teamLeadId')) {
                team.Team_Lead__c = (Id) teamData.get('teamLeadId');
            }

            update team;
            return team;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Deactivates a team
     */
    @AuraEnabled
    public static void deactivateTeam(Id teamId) {
        try {
            update new Team__c(
                Id = teamId,
                Active__c = false
            );

            // Publish Team Deactivated Event
            PlatformEventPublisher.publishTeamEvent(
                teamId,
                'team_deactivated',
                UserInfo.getUserId(),
                UserInfo.getName(),
                null
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Searches for users to add to team
     */
    @AuraEnabled(cacheable=true)
    public static List<User> searchUsers(String searchTerm) {
        try {
            String searchPattern = '%' + searchTerm + '%';
            return [
                SELECT Id, Name, Email, SmallPhotoUrl, Title
                FROM User
                WHERE IsActive = true
                AND (Name LIKE :searchPattern OR Email LIKE :searchPattern)
                ORDER BY Name
                LIMIT 20
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets team details
     */
    @AuraEnabled(cacheable=true)
    public static Team__c getTeamDetails(Id teamId) {
        try {
            return [
                SELECT Id, Name, Description__c, Department__c,
                       Team_Lead__c, Team_Lead__r.Name, Active__c,
                       CreatedDate, LastModifiedDate
                FROM Team__c
                WHERE Id = :teamId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}