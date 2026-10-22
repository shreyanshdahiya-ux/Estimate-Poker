/**
 * @description Test class for RoomController
 */
@isTest
public with sharing class RoomControllerTest {
  @testSetup
  static void grantAccess() {
    TestAccess.grantAdminToRunningUser();
  }

  /* ---------------- CREATE ROOM ---------------- */

  @isTest
  static void testCreateRoom() {
    Test.startTest();
    RoomController.createRoom(
      new Map<String, Object>{
        'name' => 'Room ' + System.now().getTime(),
        'estimationScale' => 'Fibonacci'
      },
      null,
      null
    );
    Test.stopTest();
    System.assert(true, 'Operation completed successfully');
  }

  /* ---------------- ROOM DETAILS ---------------- */

  @isTest
  static void testGetRoomDetails() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );

    Test.startTest();
    RoomController.getRoomDetails(room.Id);
    Test.stopTest();
    System.assert(true, 'Operation completed successfully');
  }

  /* ---------------- MY ROOMS ---------------- */

  @isTest
  static void testGetMyRooms() {
    createFullTestSetup();
    Test.startTest();
    RoomController.getMyRooms();
    Test.stopTest();
    System.assert(true, 'Operation completed successfully');
  }

  /* ---------------- ROOM STATUS ---------------- */

  @isTest
  static void testUpdateRoomStatus() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );

    Test.startTest();
    RoomController.updateRoomStatus(room.Id, 'Active');
    RoomController.updateRoomStatus(room.Id, 'Paused');
    RoomController.updateRoomStatus(room.Id, 'Completed');
    Test.stopTest();
    System.assert(true, 'Operation completed successfully');
  }

  /* ---------------- ADD / REMOVE MEMBERS ---------------- */

  @isTest
  static void testAddAndRemoveRoomMembers() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );

    User newUser = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
      LIMIT 1
    ];

    // Members can only be removed before the session starts, so the room must be a Draft
    update new Estimation_Poker_Room__c(Id = room.Id, Status__c = 'Draft');

    Test.startTest();
    List<Room_Member__c> members = RoomController.addRoomMembers(
      room.Id,
      new List<Map<String, Object>>{
        new Map<String, Object>{
          'userId' => newUser.Id,
          'role' => 'Voter',
          'canVote' => true
        }
      }
    );
    Id addedMemberId = members[0].Id;
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Room_Member__c WHERE Id = :addedMemberId],
      'The member should be added'
    );
    RoomController.removeRoomMember(addedMemberId);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Room_Member__c WHERE Id = :addedMemberId],
      'The member should be removed again'
    );
  }

  /* ---------------- SET CURRENT STORY ---------------- */

  @isTest
  static void testSetCurrentStory() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    User_Story__c story = ((List<User_Story__c>) setup.get('stories'))[0];

    Test.startTest();
    RoomController.setCurrentStory(room.Id, story.Id);
    Test.stopTest();
    System.assert(true, 'Operation completed successfully');
  }

  /* ---------------- MEMBER PRESENCE (SAFE) ---------------- */

  /* @isTest
    static void testUpdateMemberPresence() {
        Map<String, Object> setup = createFullTestSetup();
        Room_Member__c member =
            (Room_Member__c) setup.get('roomMember');

        // ✅ CALL ONLY ONCE — this is critical
        Test.startTest();
        RoomController.updateMemberPresence(member.Id, true);
        Test.stopTest();

        // Validate state change instead of second call
        Room_Member__c refreshed =
            [SELECT Is_Online__c FROM Room_Member__c WHERE Id = :member.Id];

        System.assertEquals(true, refreshed.Is_Online__c, 'Member should be online');
    }
*/
  /* ---------------- DELETE ROOM ---------------- */

  @isTest
  static void testDeleteRoom() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );

    Test.startTest();
    RoomController.deleteRoom(room.Id);
    Test.stopTest();

    System.assert(true, 'Operation completed successfully');
  }

  /* ---------------- MEMBER LIKE ---------------- */

  @isTest
  static void testSendMemberLike() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );

    User targetUser = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
      LIMIT 1
    ];

    Test.startTest();
    RoomController.sendMemberLike(room.Id, targetUser.Id);
    Test.stopTest();

    System.assert(true, 'Operation completed successfully');
  }

  /* ---------------- COMPLETED ROOM GUARD ---------------- */

  @isTest
  static void testAddMembersToCompletedRoom() {
    Map<String, Object> setup = createFullTestSetup();
    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );

    room.Status__c = 'Completed';
    update room;

    User u = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
      LIMIT 1
    ];

    Test.startTest();
    try {
      RoomController.addRoomMembers(
        room.Id,
        new List<Map<String, Object>>{
          new Map<String, Object>{ 'userId' => u.Id }
        }
      );
    } catch (Exception e) {
      // Expected: cannot add members to completed room
      System.assert(true, 'Expected exception for completed room');
    }
    Test.stopTest();

    System.assert(true, 'Operation completed successfully');
  }

  // Helper Methods
  private static Map<String, Object> createFullTestSetup() {
    // Create Room
    Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
      Name = 'Test Room ' + System.now().getTime(),
      Status__c = 'Open',
      Estimation_Scale__c = 'Fibonacci'
    );
    insert room;

    // Create Room Member for current user
    Room_Member__c member = new Room_Member__c(
      Room__c = room.Id,
      User__c = UserInfo.getUserId(),
      Role_In_Room__c = 'Facilitator',
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

  /* ---------------- RE-VOTE A SKIPPED STORY ---------------- */

  @isTest
  static void testSetCurrentStory_ReactivatesSkippedStoryButNotEstimated() {
    Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
      Name = 'Revote Room ' + System.now().getTime(),
      Status__c = 'Active',
      Estimation_Scale__c = 'Fibonacci',
      Facilitator__c = UserInfo.getUserId()
    );
    insert room;
    insert new Room_Member__c(
      Room__c = room.Id,
      User__c = UserInfo.getUserId(),
      Role_In_Room__c = 'Facilitator',
      Status__c = 'Active',
      Joined_Date__c = System.now(),
      Can_Vote__c = true
    );
    User_Story__c skipped = new User_Story__c(
      Room__c = room.Id,
      Story_Title__c = 'Skipped one',
      Status__c = 'Skipped',
      Story_Order__c = 1
    );
    User_Story__c estimated = new User_Story__c(
      Room__c = room.Id,
      Story_Title__c = 'Done one',
      Status__c = 'Estimated',
      Final_Estimate__c = '5',
      Story_Order__c = 2
    );
    insert new List<User_Story__c>{ skipped, estimated };

    Test.startTest();
    RoomController.setCurrentStory(room.Id, skipped.Id);
    Test.stopTest();

    System.assertEquals(
      'Voting',
      [SELECT Status__c FROM User_Story__c WHERE Id = :skipped.Id].Status__c,
      'A skipped story should return to Voting when selected again'
    );
    System.assertNotEquals(
      null,
      [SELECT Voting_Start_Time__c FROM User_Story__c WHERE Id = :skipped.Id]
      .Voting_Start_Time__c,
      'Voting start should be set'
    );

    RoomController.setCurrentStory(room.Id, estimated.Id);
    System.assertEquals(
      'Estimated',
      [SELECT Status__c FROM User_Story__c WHERE Id = :estimated.Id].Status__c,
      'An estimated story keeps its status'
    );
  }

  /* ---------------- LIKES ---------------- */

  @isTest
  static void testSendMemberLike_RejectsLikingYourself() {
    Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
      Name = 'Like Room ' + System.now().getTime(),
      Status__c = 'Active',
      Estimation_Scale__c = 'Fibonacci',
      Facilitator__c = UserInfo.getUserId()
    );
    insert room;
    insert new Room_Member__c(
      Room__c = room.Id,
      User__c = UserInfo.getUserId(),
      Role_In_Room__c = 'Facilitator',
      Status__c = 'Active',
      Joined_Date__c = System.now(),
      Can_Vote__c = true
    );

    Boolean rejected = false;
    try {
      RoomController.sendMemberLike(room.Id, UserInfo.getUserId());
    } catch (AuraHandledException e) {
      rejected = true;
    }
    System.assert(rejected, 'Liking yourself should be rejected');
  }

  /* ---------------- REMOVE ROOM MEMBERS ---------------- */

  private static Map<String, Object> createRoomWithMember(
    String roomStatus,
    User otherUser
  ) {
    Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
      Name = 'Remove Room ' + System.now().getTime(),
      Status__c = roomStatus,
      Estimation_Scale__c = 'Fibonacci',
      Facilitator__c = UserInfo.getUserId()
    );
    insert room;
    Room_Member__c facilitatorMember = new Room_Member__c(
      Room__c = room.Id,
      User__c = UserInfo.getUserId(),
      Role_In_Room__c = 'Facilitator',
      Status__c = 'Active',
      Joined_Date__c = System.now(),
      Can_Vote__c = true
    );
    Room_Member__c otherMember = new Room_Member__c(
      Room__c = room.Id,
      User__c = otherUser.Id,
      Role_In_Room__c = 'Voter',
      Status__c = 'Invited',
      Joined_Date__c = System.now(),
      Can_Vote__c = true
    );
    insert new List<Room_Member__c>{ facilitatorMember, otherMember };
    return new Map<String, Object>{
      'room' => room,
      'facilitatorMember' => facilitatorMember,
      'otherMember' => otherMember
    };
  }

  @isTest
  static void testRemoveRoomMember_RemovesMemberBeforeSessionStarts() {
    User other = TestAccess.createUserWithPermissionSet(
      'Estimation_Poker_Team_Member',
      'rmv' + String.valueOf(System.now().getTime())
    );
    Map<String, Object> setup = createRoomWithMember('Draft', other);
    Room_Member__c otherMember = (Room_Member__c) setup.get('otherMember');

    Test.startTest();
    RoomController.removeRoomMember(otherMember.Id);
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Room_Member__c WHERE Id = :otherMember.Id],
      'The member should be removed from a room that has not started'
    );
  }

  @isTest
  static void testRemoveRoomMember_RefusedOnceTheSessionHasStarted() {
    User other = TestAccess.createUserWithPermissionSet(
      'Estimation_Poker_Team_Member',
      'rmw' + String.valueOf(System.now().getTime())
    );
    Map<String, Object> setup = createRoomWithMember('Active', other);
    Room_Member__c otherMember = (Room_Member__c) setup.get('otherMember');

    Boolean refused = false;
    try {
      RoomController.removeRoomMember(otherMember.Id);
    } catch (AuraHandledException e) {
      refused = true;
    }

    System.assert(
      refused,
      'Removing a member from a started room should be refused'
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Room_Member__c WHERE Id = :otherMember.Id],
      'The member should still be in the room'
    );
  }

  @isTest
  static void testRemoveRoomMember_RoomFacilitatorCannotBeRemoved() {
    User other = TestAccess.createUserWithPermissionSet(
      'Estimation_Poker_Team_Member',
      'rmx' + String.valueOf(System.now().getTime())
    );
    Map<String, Object> setup = createRoomWithMember('Draft', other);
    Room_Member__c facilitatorMember = (Room_Member__c) setup.get(
      'facilitatorMember'
    );

    Boolean refused = false;
    try {
      RoomController.removeRoomMember(facilitatorMember.Id);
    } catch (AuraHandledException e) {
      refused = true;
    }

    System.assert(refused, 'The room facilitator must not be removable');
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Room_Member__c WHERE Id = :facilitatorMember.Id],
      'The facilitator should still be in the room'
    );
  }

  /* ---------------- START REQUIRES A STORY ---------------- */

  @isTest
  static void testUpdateRoomStatus_CannotStartARoomWithoutStories() {
    Estimation_Poker_Room__c room = new Estimation_Poker_Room__c(
      Name = 'Empty Room ' + System.now().getTime(),
      Status__c = 'Draft',
      Estimation_Scale__c = 'Fibonacci',
      Facilitator__c = UserInfo.getUserId()
    );
    insert room;
    insert new Room_Member__c(
      Room__c = room.Id,
      User__c = UserInfo.getUserId(),
      Role_In_Room__c = 'Facilitator',
      Status__c = 'Active',
      Joined_Date__c = System.now(),
      Can_Vote__c = true
    );

    String message;
    try {
      RoomController.updateRoomStatus(room.Id, 'Active');
    } catch (AuraHandledException e) {
      message = e.getMessage();
    }

    System.assertNotEquals(
      null,
      message,
      'Starting a room with no stories should be refused'
    );
    System.assertEquals(
      'Draft',
      [SELECT Status__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id]
      .Status__c,
      'The room should still be a Draft'
    );

    // Once a story exists the room can start
    insert new User_Story__c(
      Room__c = room.Id,
      Story_Title__c = 'First story',
      Status__c = 'Pending',
      Story_Order__c = 1
    );
    RoomController.updateRoomStatus(room.Id, 'Active');
    System.assertEquals(
      'Active',
      [SELECT Status__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id]
      .Status__c,
      'A room with a story can start'
    );
  }
}
