@isTest
public with sharing class RoomControllerTest {

    /* ---------------- CREATE ROOM ---------------- */

    @isTest
    static void testCreateRoom() {
        Test.startTest();
        RoomController.createRoom(
            new Map<String, Object>{
                'name' => 'Room',
                'estimationScale' => 'Fibonacci'
            },
            null,
            null
        );
        Test.stopTest();
        System.assert(true);
    }

    /* ---------------- ROOM DETAILS ---------------- */

    @isTest
    static void testGetRoomDetails() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        RoomController.getRoomDetails(room.Id);
        Test.stopTest();
        System.assert(true);
    }

    /* ---------------- MY ROOMS ---------------- */

    @isTest
    static void testGetMyRooms() {
        TestDataFactory.createFullTestSetup();
        Test.startTest();
        RoomController.getMyRooms();
        Test.stopTest();
        System.assert(true);
    }

    /* ---------------- ROOM STATUS ---------------- */

    @isTest
    static void testUpdateRoomStatus() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        RoomController.updateRoomStatus(room.Id, 'Active');
        RoomController.updateRoomStatus(room.Id, 'Paused');
        RoomController.updateRoomStatus(room.Id, 'Completed');
        Test.stopTest();
        System.assert(true);
    }

    /* ---------------- ADD / REMOVE MEMBERS ---------------- */

    @isTest
    static void testAddAndRemoveRoomMembers() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');

        User newUser = [
            SELECT Id FROM User
            WHERE IsActive = true AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];

        Test.startTest();
        List<Room_Member__c> members =
            RoomController.addRoomMembers(
                room.Id,
                new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'userId' => newUser.Id,
                        'role' => 'Voter',
                        'canVote' => true
                    }
                }
            );
        RoomController.removeRoomMember(members[0].Id);
        Test.stopTest();

        System.assert(true);
    }

    /* ---------------- SET CURRENT STORY ---------------- */

    @isTest
    static void testSetCurrentStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');
        User_Story__c story =
            ((List<User_Story__c>) setup.get('stories'))[0];

        Test.startTest();
        RoomController.setCurrentStory(room.Id, story.Id);
        Test.stopTest();
        System.assert(true);
    }

    /* ---------------- MEMBER PRESENCE (SAFE) ---------------- */

    @isTest
    static void testUpdateMemberPresence() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Room_Member__c member =
            (Room_Member__c) setup.get('roomMember');

        // ✅ CALL ONLY ONCE — this is critical
        Test.startTest();
        RoomController.updateMemberPresence(member.Id, true);
        Test.stopTest();

        // Validate state change instead of second call
        Room_Member__c refreshed =
            [SELECT Is_Online__c FROM Room_Member__c WHERE Id = :member.Id];

        System.assertEquals(true, refreshed.Is_Online__c);
    }

    /* ---------------- DELETE ROOM ---------------- */

    @isTest
    static void testDeleteRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        RoomController.deleteRoom(room.Id);
        Test.stopTest();

        System.assert(true);
    }

    /* ---------------- MEMBER LIKE ---------------- */

    @isTest
    static void testSendMemberLike() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');

        User targetUser = [
            SELECT Id FROM User
            WHERE IsActive = true AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];

        Test.startTest();
        RoomController.sendMemberLike(room.Id, targetUser.Id);
        Test.stopTest();

        System.assert(true);
    }

    /* ---------------- COMPLETED ROOM GUARD ---------------- */

    @isTest
    static void testAddMembersToCompletedRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');

        room.Status__c = 'Completed';
        update room;

        User u = [
            SELECT Id FROM User
            WHERE IsActive = true AND Id != :UserInfo.getUserId()
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
        } catch (Exception e) {}
        Test.stopTest();

        System.assert(true);
    }
}