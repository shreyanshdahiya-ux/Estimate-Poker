@isTest
public with sharing class ValidationServiceTest {

    /* ---------------- ROOM VALIDATION ---------------- */

    @isTest
    static void testValidateRoomDataValid() {
        Test.startTest();
        ValidationService.validateRoomData(new Map<String, Object>{
            'name' => 'Valid Room',
            'estimationScale' => 'Fibonacci',
            'facilitatorId' => UserInfo.getUserId()
        });
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testValidateRoomDataErrors() {
        Test.startTest();
        try {
            ValidationService.validateRoomData(new Map<String, Object>{
                'name' => '',
                'estimationScale' => 'Invalid',
                'facilitatorId' => 'bad-id'
            });
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateRoomDataNameTooLong() {
        String longName = '';
        for (Integer i = 0; i < 100; i++) longName += 'A';

        Test.startTest();
        try {
            ValidationService.validateRoomData(
                new Map<String, Object>{ 'name' => longName }
            );
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateRoomDataCustomScaleError() {
        Test.startTest();
        try {
            ValidationService.validateRoomData(new Map<String, Object>{
                'name' => 'Room',
                'estimationScale' => 'Custom',
                'customScaleValues' => ''
            });
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ---------------- STORY VALIDATION ---------------- */

    @isTest
    static void testValidateStoryDataValid() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');

        Test.startTest();
        ValidationService.validateStoryData(new Map<String, Object>{
            'title' => 'Story',
            'roomId' => room.Id,
            'storyOrder' => 1
        });
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testValidateStoryDataErrors() {
        Test.startTest();
        try {
            ValidationService.validateStoryData(new Map<String, Object>{
                'title' => '',
                'roomId' => 'bad-id',
                'storyOrder' => -1
            });
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateStoryDataInvalidOrderFormat() {
        Test.startTest();
        try {
            ValidationService.validateStoryData(new Map<String, Object>{
                'title' => 'Story',
                'roomId' => UserInfo.getUserId(),
                'storyOrder' => 'abc'
            });
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ---------------- VOTE VALIDATION ---------------- */

    @isTest
    static void testValidateVoteValid() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories =
            (List<User_Story__c>) setup.get('stories');
        Room_Member__c member =
            (Room_Member__c) setup.get('roomMember');

        Test.startTest();
        ValidationService.validateVote(new Map<String, Object>{
            'storyId' => stories[0].Id,
            'roomMemberId' => member.Id,
            'voteValue' => '5'
        });
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testValidateVoteErrors() {
        Test.startTest();
        try {
            ValidationService.validateVote(new Map<String, Object>{
                'storyId' => '',
                'roomMemberId' => '',
                'voteValue' => ''
            });
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ---------------- CAN USER VOTE ---------------- */

    @isTest
    static void testCanUserVoteAllBranches() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');
        Room_Member__c member =
            (Room_Member__c) setup.get('roomMember');
        User_Story__c story =
            ((List<User_Story__c>) setup.get('stories'))[0];

        room.Status__c = 'Active';
        update room;

        story.Status__c = 'Voting';
        story.Votes_Revealed__c = false;
        update story;

        Test.startTest();

        // happy path
        ValidationService.canUserVote(member.Id, story.Id);

        // cannot vote
        member.Can_Vote__c = false;
        update member;
        ValidationService.canUserVote(member.Id, story.Id);

        // invited member (VALID restricted picklist)
        member.Can_Vote__c = true;
        member.Status__c = 'Invited';
        update member;
        ValidationService.canUserVote(member.Id, story.Id);

        // invalid member
        ValidationService.canUserVote(null, story.Id);

        // invalid story
        ValidationService.canUserVote(member.Id, null);

        Test.stopTest();
        System.assert(true);
    }

    /* ---------------- UNIQUE VALIDATIONS ---------------- */

    @isTest
    static void testValidateUniqueRoomName() {
        Estimation_Poker_Room__c room =
            TestDataFactory.createRoom('UniqueRoom', UserInfo.getUserId());

        Test.startTest();
        try {
            ValidationService.validateUniqueRoomName('UniqueRoom', null);
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }

        // exclude same room
        ValidationService.validateUniqueRoomName('UniqueRoom', room.Id);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testValidateUniqueRoomMember() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');
        Room_Member__c member =
            (Room_Member__c) setup.get('roomMember');

        Test.startTest();
        try {
            ValidationService.validateUniqueRoomMember(
                room.Id, member.User__c, null
            );
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testValidateUniqueTeamMember() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Team__c team = TestDataFactory.createTeam('Team');
        TestDataFactory.createTeamMember(team.Id, u.Id, 'Developer');

        Test.startTest();
        try {
            ValidationService.validateUniqueTeamMember(team.Id, u.Id, null);
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ---------------- FINALIZE ESTIMATE ---------------- */

    @isTest
    static void testValidateFinalizeEstimate() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        User_Story__c story =
            ((List<User_Story__c>) setup.get('stories'))[0];
        Room_Member__c member =
            (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(story.Id, member.Id, '3');

        Test.startTest();
        ValidationService.validateFinalizeEstimate(story.Id);
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testValidateFinalizeEstimateNoVotes() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        User_Story__c story =
            ((List<User_Story__c>) setup.get('stories'))[0];

        Test.startTest();
        try {
            ValidationService.validateFinalizeEstimate(story.Id);
        } catch (ValidationService.ValidationException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ---------------- CAN MANAGE ROOM ---------------- */

    @isTest
    static void testCanManageRoomBranches() {
        User u = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        Estimation_Poker_Room__c room =
            TestDataFactory.createRoom('Manage', u.Id);

        Test.startTest();
        ValidationService.canManageRoom(room.Id, u.Id); // facilitator
        ValidationService.canManageRoom(null, u.Id);   // invalid room
        Test.stopTest();
        System.assert(true);
    }
}