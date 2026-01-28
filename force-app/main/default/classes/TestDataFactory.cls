/**
 * @description Test data factory for Planning Poker tests
 */
@isTest
public with sharing class TestDataFactory {

    public static Team__c createTeam(String name) {
        Team__c team = new Team__c(
            Name = name,
            Description__c = 'Test team description',
            Department__c = 'Engineering',
            Active__c = true
        );
        insert team;
        return team;
    }

    public static Team_Member__c createTeamMember(Id teamId, Id odataUserId, String role) {
        Team_Member__c member = new Team_Member__c(
            Team__c = teamId,
            User__c = odataUserId,
            Role__c = role,
            Joined_Date__c = Date.today(),
            Active__c = true
        );
        insert member;
        return member;
    }

    public static Estimation_Poker_Room__c createRoom(String name, Id facilitatorId) {
        Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
            Name = name,
            Description__c = 'Test room description',
            Estimation_Scale__c = 'Fibonacci',
            Status__c = 'Draft',
            Facilitator__c = facilitatorId
        );
        insert room;
        return room;
    }

    public static Room_Member__c createRoomMember(Id roomId, Id odataUserId, String role, Boolean canVote) {
        Room_Member__c member = new Room_Member__c(
            Room__c = roomId,
            User__c = odataUserId,
            Role_In_Room__c = role,
            Can_Vote__c = canVote,
            Status__c = 'Active',
            Joined_Date__c = Datetime.now()
        );
        insert member;
        return member;
    }

    public static User_Story__c createStory(Id roomId, String title, Integer order) {
        User_Story__c story = new User_Story__c(
            Room__c = roomId,
            Story_Title__c = title,
            Story_Description__c = 'Test description',
            Status__c = 'Pending',
            Story_Order__c = order
        );
        insert story;
        return story;
    }

    public static List<User_Story__c> createStories(Id roomId, Integer count) {
        List<User_Story__c> stories = new List<User_Story__c>();
        for (Integer i = 1; i <= count; i++) {
            stories.add(new User_Story__c(
                Room__c = roomId,
                Story_Title__c = 'Test Story ' + i,
                Story_Description__c = 'Description ' + i,
                Status__c = 'Pending',
                Story_Order__c = i
            ));
        }
        insert stories;
        return stories;
    }

    public static Estimation_Vote__c createVote(Id storyId, Id roomMemberId, String value) {
        Estimation_Vote__c vote = new Estimation_Vote__c(
            User_Story__c = storyId,
            Room_Member__c = roomMemberId,
            Vote_Value__c = value,
            Vote_Number__c = getNumericValue(value),
            Voted_DateTime__c = Datetime.now(),
            Revealed__c = false
        );
        insert vote;
        return vote;
    }

    public static List<Estimation_Vote__c> createVotes(Id storyId, List<Id> memberIds, List<String> values) {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        for (Integer i = 0; i < memberIds.size(); i++) {
            String value = values[Math.mod(i, values.size())];
            votes.add(new Estimation_Vote__c(
                User_Story__c = storyId,
                Room_Member__c = memberIds[i],
                Vote_Value__c = value,
                Vote_Number__c = getNumericValue(value),
                Voted_DateTime__c = Datetime.now(),
                Revealed__c = false
            ));
        }
        insert votes;
        return votes;
    }

    public static Help_Article__c createHelpArticle(String name, String content, String category) {
        Help_Article__c article = new Help_Article__c(
            Name = name,
            Content__c = content,
            Category__c = category,
            Active__c = true
        );
        insert article;
        return article;
    }

    private static Decimal getNumericValue(String value) {
        try {
            return Decimal.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    public static Map<String, Object> createFullTestSetup() {
        User testUser = [SELECT Id, Name FROM User WHERE IsActive = true LIMIT 1];

        Team__c team = createTeam('Test Team');
        Team_Member__c teamMember = createTeamMember(team.Id, testUser.Id, 'Developer');

        Estimation_Poker_Room__c room = createRoom('Test Room', testUser.Id);
        Room_Member__c roomMember = createRoomMember(room.Id, testUser.Id, 'Facilitator', true);

        List<User_Story__c> stories = createStories(room.Id, 5);

        return new Map<String, Object>{
            'user' => testUser,
            'team' => team,
            'teamMember' => teamMember,
            'room' => room,
            'roomMember' => roomMember,
            'stories' => stories
        };
    }
}