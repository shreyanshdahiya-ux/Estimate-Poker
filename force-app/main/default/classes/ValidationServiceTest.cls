/**
 * @description Test class for ValidationService
 */
@isTest
private class ValidationServiceTest {

    @isTest
    static void testValidateRoomDataValid() {
        Map<String, Object> roomData = new Map<String, Object>{
            'name' => 'Valid Room Name',
            'estimationScale' => 'Fibonacci',
            'facilitatorId' => UserInfo.getUserId()
        };

        Test.startTest();
        // Should not throw exception
        ValidationService.validateRoomData(roomData);
        Test.stopTest();

        System.assert(true, 'Validation should pass');
    }

    @isTest
    static void testValidateRoomDataMissingName() {
        Map<String, Object> roomData = new Map<String, Object>{
            'name' => '',
            'estimationScale' => 'Fibonacci'
        };

        Test.startTest();
        try {
            ValidationService.validateRoomData(roomData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('Room name'), 'Should mention room name');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateRoomDataNameTooLong() {
        String longName = '';
        for (Integer i = 0; i < 90; i++) {
            longName += 'a';
        }

        Map<String, Object> roomData = new Map<String, Object>{
            'name' => longName
        };

        Test.startTest();
        try {
            ValidationService.validateRoomData(roomData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('80 characters'), 'Should mention character limit');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateRoomDataInvalidScale() {
        Map<String, Object> roomData = new Map<String, Object>{
            'name' => 'Valid Name',
            'estimationScale' => 'Invalid Scale'
        };

        Test.startTest();
        try {
            ValidationService.validateRoomData(roomData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('Invalid estimation scale'), 'Should mention invalid scale');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateRoomDataCustomScaleMissingValues() {
        Map<String, Object> roomData = new Map<String, Object>{
            'name' => 'Valid Name',
            'estimationScale' => 'Custom',
            'customScaleValues' => ''
        };

        Test.startTest();
        try {
            ValidationService.validateRoomData(roomData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('Custom scale values'), 'Should mention custom values');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateRoomDataInvalidFacilitatorId() {
        Map<String, Object> roomData = new Map<String, Object>{
            'name' => 'Valid Name',
            'facilitatorId' => 'invalid-id'
        };

        Test.startTest();
        try {
            ValidationService.validateRoomData(roomData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('Invalid facilitator'), 'Should mention invalid facilitator');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateStoryDataValid() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Map<String, Object> storyData = new Map<String, Object>{
            'title' => 'Valid Story Title',
            'roomId' => room.Id,
            'storyOrder' => 1
        };

        Test.startTest();
        ValidationService.validateStoryData(storyData);
        Test.stopTest();

        System.assert(true, 'Validation should pass');
    }

    @isTest
    static void testValidateStoryDataMissingTitle() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Map<String, Object> storyData = new Map<String, Object>{
            'title' => '',
            'roomId' => room.Id
        };

        Test.startTest();
        try {
            ValidationService.validateStoryData(storyData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('Story title'), 'Should mention story title');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateStoryDataMissingRoomId() {
        Map<String, Object> storyData = new Map<String, Object>{
            'title' => 'Valid Title',
            'roomId' => ''
        };

        Test.startTest();
        try {
            ValidationService.validateStoryData(storyData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('Room ID'), 'Should mention room ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateStoryDataNegativeOrder() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');

        Map<String, Object> storyData = new Map<String, Object>{
            'title' => 'Valid Title',
            'roomId' => room.Id,
            'storyOrder' => -1
        };

        Test.startTest();
        try {
            ValidationService.validateStoryData(storyData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('negative'), 'Should mention negative order');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateVoteValid() {
        Map<String, Object> voteData = new Map<String, Object>{
            'storyId' => 'a00000000000001',
            'roomMemberId' => 'a00000000000002',
            'voteValue' => '5'
        };

        Test.startTest();
        ValidationService.validateVote(voteData);
        Test.stopTest();

        System.assert(true, 'Validation should pass');
    }

    @isTest
    static void testValidateVoteMissingStoryId() {
        Map<String, Object> voteData = new Map<String, Object>{
            'storyId' => '',
            'roomMemberId' => 'a00000000000002',
            'voteValue' => '5'
        };

        Test.startTest();
        try {
            ValidationService.validateVote(voteData);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('Story ID'), 'Should mention story ID');
        }
        Test.stopTest();
    }

    @isTest
    static void testCanUserVoteValid() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        // Set room to active and story to voting
        room.Status__c = 'Active';
        update room;

        stories[0].Status__c = 'Voting';
        stories[0].Votes_Revealed__c = false;
        update stories[0];

        Test.startTest();
        Boolean canVote = ValidationService.canUserVote(member.Id, stories[0].Id);
        Test.stopTest();

        System.assertEquals(true, canVote, 'User should be able to vote');
    }

    @isTest
    static void testCanUserVoteInactiveRoom() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        stories[0].Status__c = 'Voting';
        update stories[0];

        Test.startTest();
        Boolean canVote = ValidationService.canUserVote(member.Id, stories[0].Id);
        Test.stopTest();

        System.assertEquals(false, canVote, 'Should not vote in inactive room');
    }

    @isTest
    static void testCanUserVoteRevealedStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        room.Status__c = 'Active';
        update room;

        stories[0].Status__c = 'Voting';
        stories[0].Votes_Revealed__c = true;
        update stories[0];

        Test.startTest();
        Boolean canVote = ValidationService.canUserVote(member.Id, stories[0].Id);
        Test.stopTest();

        System.assertEquals(false, canVote, 'Should not vote after reveal');
    }

    @isTest
    static void testCanUserVoteInvalidMember() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        Boolean canVote = ValidationService.canUserVote(null, stories[0].Id);
        Test.stopTest();

        System.assertEquals(false, canVote, 'Invalid member should not vote');
    }

    @isTest
    static void testValidateUniqueRoomName() {
        TestDataFactory.createRoom('Unique Room Name', UserInfo.getUserId());

        Test.startTest();
        try {
            ValidationService.validateUniqueRoomName('Unique Room Name', null);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('already exists'), 'Should mention duplicate');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateUniqueRoomNameExclude() {
        Estimation_Poker_Room__c room = TestDataFactory.createRoom('Unique Room', UserInfo.getUserId());

        Test.startTest();
        // Should not throw when excluding the same room
        ValidationService.validateUniqueRoomName('Unique Room', room.Id);
        Test.stopTest();

        System.assert(true, 'Should pass when excluding same room');
    }

    @isTest
    static void testValidateUniqueRoomMember() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        User testUser = [SELECT Id FROM User WHERE Id = :member.User__c];

        Test.startTest();
        try {
            ValidationService.validateUniqueRoomMember(room.Id, testUser.Id, null);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('already a member'), 'Should mention duplicate');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateUniqueTeamMember() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Team__c team = TestDataFactory.createTeam('Test Team');
        TestDataFactory.createTeamMember(team.Id, testUser.Id, 'Developer');

        Test.startTest();
        try {
            ValidationService.validateUniqueTeamMember(team.Id, testUser.Id, null);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('already a member'), 'Should mention duplicate');
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateFinalizeEstimate() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        // Should not throw when votes exist
        ValidationService.validateFinalizeEstimate(stories[0].Id);
        Test.stopTest();

        System.assert(true, 'Should pass with votes');
    }

    @isTest
    static void testValidateFinalizeEstimateNoVotes() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        Test.startTest();
        try {
            ValidationService.validateFinalizeEstimate(stories[0].Id);
            System.assert(false, 'Should throw exception');
        } catch (ValidationService.ValidationException e) {
            System.assert(e.getMessage().contains('without any votes'), 'Should mention no votes');
        }
        Test.stopTest();
    }

    @isTest
    static void testCanManageRoomFacilitator() {
        User testUser = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Estimation_Poker_Room__c room = TestDataFactory.createRoom('Manage Room', testUser.Id);

        Test.startTest();
        Boolean canManage = ValidationService.canManageRoom(room.Id, testUser.Id);
        Test.stopTest();

        System.assertEquals(true, canManage, 'Facilitator should manage room');
    }

    @isTest
    static void testCanManageRoomMemberFacilitator() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        // The member was created as Facilitator in test setup
        Test.startTest();
        Boolean canManage = ValidationService.canManageRoom(room.Id, member.User__c);
        Test.stopTest();

        System.assertEquals(true, canManage, 'Member facilitator should manage room');
    }

    @isTest
    static void testCanManageRoomInvalidRoom() {
        Test.startTest();
        Boolean canManage = ValidationService.canManageRoom(null, UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(false, canManage, 'Should not manage invalid room');
    }
}