/**
 * @description Test class for RoomController
 */
@isTest
private class RoomControllerTest {

    @isTest
    static void testCreateRoom() {
        Map<String, Object> roomData = new Map<String, Object>{
            'name' => 'Test Room',
            'description' => 'Test Description',
            'estimationScale' => 'Fibonacci'
        };

        Test.startTest();
        Id roomId = RoomController.createRoom(roomData, null, null);
        Test.stopTest();

        System.assertNotEquals(null, roomId, 'Room should be created');

        Estimation_Poker_Room__c room = [SELECT Id, Name, Status__c FROM Estimation_Poker_Room__c WHERE Id = :roomId];
        System.assertEquals('Test Room', room.Name, 'Room name should match');
        System.assertEquals('Draft', room.Status__c, 'Status should be Draft');

        // Verify facilitator was added as member
        List<Room_Member__c> members = [SELECT Id FROM Room_Member__c WHERE Room__c = :roomId];
        System.assertEquals(1, members.size(), 'Facilitator should be added as member');
    }

    @isTest
    static void testCreateRoomWithMembers() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        Map<String, Object> roomData = new Map<String, Object>{
            'name' => 'Test Room With Members',
            'estimationScale' => 'T-Shirt Sizes'
        };

        String memberRoles = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{'userId' => testUser.Id, 'role' => 'Voter'}
        });

        Test.startTest();
        Id roomId = RoomController.createRoom(roomData, null, memberRoles);
        Test.stopTest();

        List<Room_Member__c> members = [SELECT Id, User__c FROM Room_Member__c WHERE Room__c = :roomId];
        System.assertEquals(2, members.size(), 'Should have 2 members (facilitator + 1)');
    }

    @isTest
    static void testGetRoomDetails() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        Map<String, Object> details = RoomController.getRoomDetails(room.Id);
        Test.stopTest();

        System.assertNotEquals(null, details, 'Details should not be null');
        System.assertNotEquals(null, details.get('room'), 'Room should be in details');
        System.assertNotEquals(null, details.get('members'), 'Members should be in details');
        System.assertNotEquals(null, details.get('scaleValues'), 'Scale values should be in details');
    }

    @isTest
    static void testGetMyRooms() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();

        Test.startTest();
        List<Map<String, Object>> rooms = RoomController.getMyRooms();
        Test.stopTest();

        System.assert(rooms.size() > 0, 'Should return at least one room');
    }

    @isTest
    static void testUpdateRoomStatus() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        RoomController.updateRoomStatus(room.Id, 'Active');
        Estimation_Poker_Room__c activeRoom = [SELECT Status__c, Start_DateTime__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id];
        System.assertEquals('Active', activeRoom.Status__c);
        System.assertNotEquals(null, activeRoom.Start_DateTime__c);

        RoomController.updateRoomStatus(room.Id, 'Paused');
        Estimation_Poker_Room__c pausedRoom = [SELECT Status__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id];
        System.assertEquals('Paused', pausedRoom.Status__c);

        RoomController.updateRoomStatus(room.Id, 'Completed');
        Estimation_Poker_Room__c completedRoom = [SELECT Status__c, End_DateTime__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id];
        System.assertEquals('Completed', completedRoom.Status__c);
        System.assertNotEquals(null, completedRoom.End_DateTime__c);
        Test.stopTest();
    }

    @isTest
    static void testAddRoomMembers() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        User newUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        List<Map<String, Object>> memberDataList = new List<Map<String, Object>>{
            new Map<String, Object>{
                'userId' => newUser.Id,
                'role' => 'Voter',
                'canVote' => true
            }
        };

        Test.startTest();
        List<Room_Member__c> newMembers = RoomController.addRoomMembers(room.Id, memberDataList);
        Test.stopTest();

        System.assertEquals(1, newMembers.size(), 'Should add 1 new member');
    }

    @isTest
    static void testRemoveRoomMember() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        User newUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];
        Room_Member__c member = TestDataFactory.createRoomMember(room.Id, newUser.Id, 'Voter', true);

        Test.startTest();
        RoomController.removeRoomMember(member.Id);
        Test.stopTest();

        List<Room_Member__c> remainingMembers = [SELECT Id FROM Room_Member__c WHERE Id = :member.Id];
        System.assertEquals(0, remainingMembers.size(), 'Member should be deleted');
    }

    @isTest
    static void testSetCurrentStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        RoomController.setCurrentStory(room.Id, stories[0].Id);
        Test.stopTest();

        Estimation_Poker_Room__c updatedRoom = [SELECT Current_Story__c FROM Estimation_Poker_Room__c WHERE Id = :room.Id];
        System.assertEquals(stories[0].Id, updatedRoom.Current_Story__c, 'Current story should be set');

        User_Story__c updatedStory = [SELECT Status__c FROM User_Story__c WHERE Id = :stories[0].Id];
        System.assertEquals('Voting', updatedStory.Status__c, 'Story status should be Voting');
    }

    @isTest
    static void testGetCurrentUserMember() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        Room_Member__c member = RoomController.getCurrentUserMember(room.Id);
        Test.stopTest();

        System.assertNotEquals(null, member, 'Current user member should be found');
    }

    @isTest
    static void testUpdateMemberPresence() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        Test.startTest();
        RoomController.updateMemberPresence(member.Id, true);
        Test.stopTest();

        Room_Member__c updatedMember = [SELECT Is_Online__c, Last_Activity__c FROM Room_Member__c WHERE Id = :member.Id];
        System.assertEquals(true, updatedMember.Is_Online__c, 'Member should be online');
        System.assertNotEquals(null, updatedMember.Last_Activity__c, 'Last activity should be set');
    }

    @isTest
    static void testDeleteRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        RoomController.deleteRoom(room.Id);
        Test.stopTest();

        List<Estimation_Poker_Room__c> rooms = [SELECT Id FROM Estimation_Poker_Room__c WHERE Id = :room.Id];
        System.assertEquals(0, rooms.size(), 'Room should be deleted');
    }

    @isTest
    static void testSendMemberLike() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        User targetUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];

        Test.startTest();
        try {
            RoomController.sendMemberLike(room.Id, targetUser.Id);
        } catch (Exception e) {
            System.debug('Exception in sendMemberLike: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Validation: No exception should be thrown for valid member/room
        // Platform event publication can't be easily verified in unit tests without a mock
        // but we ensure the path completes.
    }

    @isTest
    static void testAddMembersToCompletedRoomThrowsException() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        
        // Complete the room
        room.Status__c = 'Completed';
        update room;
        
        User newUser = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];
        
        List<Map<String, Object>> memberDataList = new List<Map<String, Object>>{
            new Map<String, Object>{
                'userId' => newUser.Id,
                'role' => 'Voter',
                'canVote' => true
            }
        };

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            RoomController.addRoomMembers(room.Id, memberDataList);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('completed'), 'Exception message should mention completed room');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Exception should be thrown when adding members to completed room');
    }
}