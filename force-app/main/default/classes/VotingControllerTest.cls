/**
 * @description Test class for VotingController
 */
@isTest
public with sharing class VotingControllerTest {
  @testSetup
  static void setupPermissions() {
    List<PermissionSet> sets = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Estimation_Poker_Admin'
      LIMIT 1
    ];
    if (sets.isEmpty()) {
      return;
    }
    Id psId = sets[0].Id;
    Id userId = UserInfo.getUserId();
    List<PermissionSetAssignment> existing = [
      SELECT Id
      FROM PermissionSetAssignment
      WHERE AssigneeId = :userId AND PermissionSetId = :psId
      LIMIT 1
    ];
    if (existing.isEmpty()) {
      insert new PermissionSetAssignment(
        AssigneeId = userId,
        PermissionSetId = psId
      );
    }
  }

  @isTest
  static void testSubmitVote() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

    // Set story to Voting status
    stories[0].Status__c = 'Voting';
    update stories[0];

    // Activate room
    room.Status__c = 'Active';
    update room;

    Test.startTest();
    Estimation_Vote__c vote = VotingController.submitVote(
      stories[0].Id,
      member.Id,
      '5',
      null,
      null,
      0
    );
    Test.stopTest();

    System.assertNotEquals(null, vote, 'Vote should be created');
    System.assertEquals('5', vote.Vote_Value__c, 'Vote value should match');
    System.assertEquals(5, vote.Vote_Number__c, 'Numeric value should be 5');
  }

  @isTest
  static void testSubmitVote_DerivesDurationWhenClientSendsNone() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

    stories[0].Status__c = 'Voting';
    stories[0].Voting_Start_Time__c = Datetime.now().addSeconds(-45);
    update stories[0];
    room.Status__c = 'Active';
    update room;

    Test.startTest();
    // The browser sent 0 because it never saw the voting start
    VotingController.submitVote(stories[0].Id, member.Id, '5', null, null, 0);
    Map<String, Object> result = VotingController.getVotesForStory(
      stories[0].Id,
      false
    );
    Test.stopTest();

    Estimation_Vote__c saved = [
      SELECT Duration__c
      FROM Estimation_Vote__c
      WHERE User_Story__c = :stories[0].Id
    ];
    System.assert(
      saved.Duration__c >= 45,
      'Duration should be derived from the voting start, was ' +
      saved.Duration__c
    );

    List<Object> votes = (List<Object>) result.get('votes');
    Map<String, Object> first = (Map<String, Object>) votes[0];
    System.assert(
      (Integer) first.get('duration') >= 45,
      'Returned vote should carry the derived duration'
    );
  }

  @isTest
  static void testSubmitVote_TeamMemberOnlyPersistsTimingAndNumericValue() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    PermissionSet memberSet = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Estimation_Poker_Team_Member'
      LIMIT 1
    ];
    String uniqueKey = String.valueOf(System.now().getTime());
    User voter = new User(
      Alias = 'voter',
      Email = 'voter' + uniqueKey + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Voter',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'voter' + uniqueKey + '@example.com'
    );
    // Setup objects (user, permission set assignment) are created first to avoid mixed DML
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert voter;
      insert new PermissionSetAssignment(
        AssigneeId = voter.Id,
        PermissionSetId = memberSet.Id
      );
    }

    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

    Room_Member__c voterMember = new Room_Member__c(
      Room__c = room.Id,
      User__c = voter.Id,
      Role_In_Room__c = 'Voter',
      Status__c = 'Active',
      Joined_Date__c = System.now(),
      Can_Vote__c = true
    );
    insert voterMember;

    room.Status__c = 'Active';
    update room;
    update new User_Story__c(
      Id = stories[0].Id,
      Status__c = 'Voting',
      Voting_Start_Time__c = Datetime.now().addSeconds(-20)
    );

    Test.startTest();
    System.runAs(voter) {
      VotingController.submitVote(
        stories[0].Id,
        voterMember.Id,
        '8',
        null,
        null,
        12
      );
    }
    Test.stopTest();

    Estimation_Vote__c saved = [
      SELECT Vote_Number__c, Duration__c, Voted_DateTime__c
      FROM Estimation_Vote__c
      WHERE Room_Member__c = :voterMember.Id
    ];
    System.assertEquals(
      8,
      saved.Vote_Number__c,
      'Numeric value must be saved for a Team Member voter'
    );
    System.assertEquals(
      12,
      saved.Duration__c,
      'Duration must be saved for a Team Member voter'
    );
    System.assertNotEquals(
      null,
      saved.Voted_DateTime__c,
      'Vote time must be saved for a Team Member voter'
    );
  }

  @isTest
  static void testRoomFacilitatorWithFacilitatorPermissionSetCanRunTheRoom() {
    User facilitator = TestAccess.createUserWithPermissionSet(
      'Estimation_Poker_Facilitator',
      'rfac' + String.valueOf(System.now().getTime())
    );
    Map<String, Object> setup = createRoomWithFacilitator(facilitator);
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    Room_Member__c facilitatorMember = (Room_Member__c) setup.get('member');

    Test.startTest();
    System.runAs(facilitator) {
      User_Story__c story = StoryController.createStory(
        new Map<String, Object>{ 'title' => 'Facilitated story' },
        room.Id
      );
      RoomController.setCurrentStory(room.Id, story.Id);
      VotingController.submitVote(
        story.Id,
        facilitatorMember.Id,
        '5',
        null,
        null,
        3
      );
      VotingController.revealVotes(story.Id);
      System.assertEquals(
        'Discussing',
        [SELECT Status__c FROM User_Story__c WHERE Id = :story.Id].Status__c,
        'Reveal should work for a room Facilitator with the Facilitator permission set'
      );
      VotingController.resetVotes(story.Id);
      VotingController.submitVote(
        story.Id,
        facilitatorMember.Id,
        '8',
        null,
        null,
        3
      );
      VotingController.revealVotes(story.Id);
      VotingController.finalizeEstimate(story.Id, '8');
      RoomController.updateRoomStatus(room.Id, 'Paused');
    }
    Test.stopTest();

    User_Story__c finalStory = [
      SELECT Status__c, Final_Estimate__c
      FROM User_Story__c
      WHERE Room__c = :room.Id
    ];
    System.assertEquals(
      'Estimated',
      finalStory.Status__c,
      'Story should be Estimated'
    );
    System.assertEquals(
      '8',
      finalStory.Final_Estimate__c,
      'Final estimate should be saved'
    );
    System.assertEquals(
      'Paused',
      [SELECT Status__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id]
      .Status__c,
      'Room status should update'
    );
  }

  @isTest
  static void testTeamMemberPermissionSetCannotFacilitateEvenIfListedAsRoomFacilitator() {
    User member = TestAccess.createUserWithPermissionSet(
      'Estimation_Poker_Team_Member',
      'tmem' + String.valueOf(System.now().getTime())
    );
    // The room data says this user is the Facilitator, but the permission set does not grant facilitation
    Map<String, Object> setup = createRoomWithFacilitator(member);
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    User_Story__c story = new User_Story__c(
      Room__c = room.Id,
      Story_Title__c = 'Existing',
      Status__c = 'Voting',
      Story_Order__c = 1
    );
    insert story;

    Test.startTest();
    System.runAs(member) {
      System.assertEquals(
        false,
        ValidationService.canManageRoom(room.Id, member.Id),
        'Room data alone must not grant facilitation'
      );
      Boolean createDenied = false;
      try {
        StoryController.createStory(
          new Map<String, Object>{ 'title' => 'Nope' },
          room.Id
        );
      } catch (AuraHandledException e) {
        createDenied = true;
      }
      System.assert(
        createDenied,
        'A Team Member must not be able to create a story'
      );

      Boolean revealDenied = false;
      try {
        VotingController.revealVotes(story.Id);
      } catch (AuraHandledException e) {
        revealDenied = true;
      }
      System.assert(
        revealDenied,
        'A Team Member must not be able to reveal votes'
      );

      Boolean statusDenied = false;
      try {
        RoomController.updateRoomStatus(room.Id, 'Paused');
      } catch (AuraHandledException e) {
        statusDenied = true;
      }
      System.assert(
        statusDenied,
        'A Team Member must not be able to change the room status'
      );
    }
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM User_Story__c WHERE Room__c = :room.Id],
      'No story should have been created'
    );
    System.assertEquals(
      'Active',
      [SELECT Status__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id]
      .Status__c,
      'Room status unchanged'
    );
  }

  @isTest
  static void testUpdateVote() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

    stories[0].Status__c = 'Voting';
    update stories[0];
    room.Status__c = 'Active';
    update room;

    // First vote
    VotingController.submitVote(stories[0].Id, member.Id, '5', null, null, 0);

    Test.startTest();
    // Update vote
    Estimation_Vote__c updatedVote = VotingController.submitVote(
      stories[0].Id,
      member.Id,
      '8',
      null,
      null,
      0
    );
    Test.stopTest();

    System.assertEquals(
      '8',
      updatedVote.Vote_Value__c,
      'Vote should be updated to 8'
    );

    // Should only have one vote
    Integer voteCount = [
      SELECT COUNT()
      FROM Estimation_Vote__c
      WHERE User_Story__c = :stories[0].Id
    ];
    System.assertEquals(1, voteCount, 'Should only have one vote');
  }

  @isTest
  static void testGetVotesForStory() {
    Map<String, Object> setup = createFullTestSetup();
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    createVote(stories[0].Id, member.Id, '5');

    Test.startTest();
    Map<String, Object> result = VotingController.getVotesForStory(
      stories[0].Id,
      false
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(1, result.get('voteCount'), 'Should have 1 vote');
    System.assertEquals(
      'Pending',
      result.get('storyStatus'),
      'The story status is returned so the screen knows if it is estimated'
    );
  }

  @isTest
  static void testRevealVotes() {
    Map<String, Object> setup = createFullTestSetup();
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    createVote(stories[0].Id, member.Id, '5');

    // In a live session the current story is in Voting before votes are revealed
    update new User_Story__c(Id = stories[0].Id, Status__c = 'Voting');

    Test.startTest();
    VotingController.revealVotes(stories[0].Id);
    Test.stopTest();

    User_Story__c revealed = [
      SELECT Status__c, Votes_Revealed__c
      FROM User_Story__c
      WHERE Id = :stories[0].Id
    ];
    System.assertEquals(
      true,
      revealed.Votes_Revealed__c,
      'Votes should be revealed'
    );
    System.assertEquals(
      'Discussing',
      revealed.Status__c,
      'Story should move to Discussing after reveal'
    );
    System.assertEquals(
      true,
      [
        SELECT Revealed__c
        FROM Estimation_Vote__c
        WHERE User_Story__c = :stories[0].Id
      ][0]
      .Revealed__c,
      'Vote should be marked revealed'
    );
  }

  @isTest
  static void testResetVotes() {
    Map<String, Object> setup = createFullTestSetup();
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    createVote(stories[0].Id, member.Id, '5');

    Test.startTest();
    VotingController.resetVotes(stories[0].Id);
    Test.stopTest();

    User_Story__c reset = [
      SELECT Status__c, Votes_Revealed__c
      FROM User_Story__c
      WHERE Id = :stories[0].Id
    ];
    System.assertEquals(
      false,
      reset.Votes_Revealed__c,
      'Votes should no longer be revealed'
    );
    System.assertEquals(
      'Voting',
      reset.Status__c,
      'Story should return to Voting'
    );
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Estimation_Vote__c
        WHERE User_Story__c = :stories[0].Id
      ],
      'Votes should be deleted'
    );
  }

  @isTest
  static void testFinalizeEstimate() {
    Map<String, Object> setup = createFullTestSetup();
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    createVote(stories[0].Id, member.Id, '5');

    Test.startTest();
    VotingController.finalizeEstimate(stories[0].Id, '5');
    Test.stopTest();

    User_Story__c finalized = [
      SELECT Status__c, Final_Estimate__c
      FROM User_Story__c
      WHERE Id = :stories[0].Id
    ];
    System.assertEquals(
      'Estimated',
      finalized.Status__c,
      'Story should be Estimated'
    );
    System.assertEquals(
      '5',
      finalized.Final_Estimate__c,
      'Final estimate should be saved'
    );
  }

  @isTest
  static void testCalculateStatistics() {
    Map<String, Object> setup = createFullTestSetup();
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    createVote(stories[0].Id, member.Id, '5');

    Test.startTest();
    Map<String, Object> stats = VotingController.calculateStatistics(
      stories[0].Id
    );
    Test.stopTest();

    System.assertNotEquals(null, stats, 'Stats should not be null');
    System.assertEquals(5, stats.get('average'), 'Average should be 5');
  }

  @isTest
  static void testGetCurrentUserVote() {
    Map<String, Object> setup = createFullTestSetup();
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    createVote(stories[0].Id, member.Id, '8');

    Test.startTest();
    Estimation_Vote__c vote = VotingController.getCurrentUserVote(
      stories[0].Id,
      member.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, vote, 'Vote should be found');
    System.assertEquals('8', vote.Vote_Value__c, 'Vote value should be 8');
  }

  @isTest
  static void testDeleteVote() {
    Map<String, Object> setup = createFullTestSetup();
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    createVote(stories[0].Id, member.Id, '5');

    Test.startTest();
    VotingController.deleteVote(stories[0].Id, member.Id);
    Test.stopTest();

    Integer voteCount = [
      SELECT COUNT()
      FROM Estimation_Vote__c
      WHERE User_Story__c = :stories[0].Id AND Room_Member__c = :member.Id
    ];
    System.assertEquals(0, voteCount, 'Vote should be deleted');
  }

  @isTest
  static void testGetVoteHistory() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    stories[0].Status__c = 'Estimated';
    stories[0].Final_Estimate__c = '5';
    update stories[0];

    createVote(stories[0].Id, member.Id, '5');

    Test.startTest();
    List<Map<String, Object>> history = VotingController.getVoteHistory(
      room.Id
    );
    Test.stopTest();

    System.assertNotEquals(0, history.size(), 'History should not be empty');
    System.assertEquals(
      stories[0].Id,
      history[0].get('storyId'),
      'Story ID should match'
    );
  }

  @isTest
  static void testBroadcastTimer() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    User testUser = (User) setup.get('user');

    Test.startTest();
    System.runAs(testUser) {
      VotingController.broadcastTimer(room.Id, 'timer_start', 60);
    }
    Test.stopTest();

    // Success if no exception thrown (facilitator check passes)
    System.assert(true, 'Broadcast timer executed successfully');
  }

  // Helper Methods
  private static Map<String, Object> createFullTestSetup() {
    // Create Room
    Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
      Name = 'Test Room ' + System.now().getTime(),
      Status__c = 'Open',
      Estimation_Scale__c = 'Fibonacci',
      Facilitator__c = UserInfo.getUserId()
    );
    insert room;

    // Create Room Member for current user
    Room_Member__c member = new Room_Member__c(
      Room__c = room.Id,
      User__c = UserInfo.getUserId(),
      Role_In_Room__c = 'Facilitator',
      Status__c = 'Active',
      Joined_Date__c = System.now(),
      Is_Online__c = true,
      Can_Vote__c = true
    );
    insert member;

    // Create User Stories
    List<User_Story__c> stories = new List<User_Story__c>();
    for (Integer i = 1; i <= 2; i++) {
      stories.add(
        new User_Story__c(
          Room__c = room.Id,
          Story_Title__c = 'Test Story ' + i,
          Status__c = 'Pending',
          Story_Order__c = i
        )
      );
    }
    insert stories;

    return new Map<String, Object>{
      'room' => room,
      'roomMember' => member,
      'stories' => stories,
      'user' => [
        SELECT Id, Name, SmallPhotoUrl
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ][0]
    };
  }

  private static Estimation_Vote__c createVote(
    Id storyId,
    Id memberId,
    String value
  ) {
    Estimation_Vote__c vote = new Estimation_Vote__c(
      User_Story__c = storyId,
      Room_Member__c = memberId,
      Vote_Value__c = value,
      Vote_Number__c = (value == '?' ||
        value == '☕')
        ? null
        : Decimal.valueOf(value)
    );
    insert vote;
    return vote;
  }

  private static Map<String, Object> createRoomWithFacilitator(
    User facilitator
  ) {
    Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
      Name = 'Facilitator Room ' + System.now().getTime(),
      Status__c = 'Active',
      Estimation_Scale__c = 'Fibonacci',
      Facilitator__c = facilitator.Id
    );
    insert room;
    Room_Member__c member = new Room_Member__c(
      Room__c = room.Id,
      User__c = facilitator.Id,
      Role_In_Room__c = 'Facilitator',
      Status__c = 'Active',
      Joined_Date__c = System.now(),
      Can_Vote__c = true
    );
    insert member;
    return new Map<String, Object>{ 'room' => room, 'member' => member };
  }
}
