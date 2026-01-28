/**
 * @description Test class for VotingController
 */
@isTest
public with sharing class VotingControllerTest {

    @isTest
    static void testSubmitVote() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');

        // Set story to Voting status
        stories[0].Status__c = 'Voting';
        update stories[0];

        // Activate room
        room.Status__c = 'Active';
        update room;

        Test.startTest();
        Estimation_Vote__c vote = VotingController.submitVote(stories[0].Id, member.Id, '5', null, null, 0);
        Test.stopTest();

        System.assertNotEquals(null, vote, 'Vote should be created');
        System.assertEquals('5', vote.Vote_Value__c, 'Vote value should match');
        System.assertEquals(5, vote.Vote_Number__c, 'Numeric value should be 5');
    }

    @isTest
    static void testUpdateVote() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
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
        Estimation_Vote__c updatedVote = VotingController.submitVote(stories[0].Id, member.Id, '8', null, null, 0);
        Test.stopTest();

        System.assertEquals('8', updatedVote.Vote_Value__c, 'Vote should be updated to 8');

        // Should only have one vote
        Integer voteCount = [SELECT COUNT() FROM Estimation_Vote__c WHERE User_Story__c = :stories[0].Id];
        System.assertEquals(1, voteCount, 'Should only have one vote');
    }

    @isTest
    static void testGetVotesForStory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        Map<String, Object> result = VotingController.getVotesForStory(stories[0].Id, false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.get('voteCount'), 'Should have 1 vote');
    }

    @isTest
    static void testRevealVotes() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        Map<String, Object> stats = VotingController.revealVotes(stories[0].Id);
        Test.stopTest();

        User_Story__c updatedStory = [SELECT Votes_Revealed__c, Status__c FROM User_Story__c WHERE Id = :stories[0].Id];
        System.assertEquals(true, updatedStory.Votes_Revealed__c, 'Votes should be revealed');

        Estimation_Vote__c vote = [SELECT Revealed__c FROM Estimation_Vote__c WHERE User_Story__c = :stories[0].Id LIMIT 1];
        System.assertEquals(true, vote.Revealed__c, 'Vote should be revealed');
    }

    @isTest
    static void testResetVotes() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        VotingController.resetVotes(stories[0].Id);
        Test.stopTest();

        Integer voteCount = [SELECT COUNT() FROM Estimation_Vote__c WHERE User_Story__c = :stories[0].Id];
        System.assertEquals(0, voteCount, 'All votes should be deleted');

        User_Story__c updatedStory = [SELECT Votes_Revealed__c, Status__c FROM User_Story__c WHERE Id = :stories[0].Id];
        System.assertEquals(false, updatedStory.Votes_Revealed__c, 'Votes revealed should be false');
        System.assertEquals('Voting', updatedStory.Status__c, 'Status should be Voting');
    }

    @isTest
    static void testFinalizeEstimate() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        VotingController.finalizeEstimate(stories[0].Id, '5');
        Test.stopTest();

        User_Story__c updatedStory = [SELECT Final_Estimate__c, Status__c, Estimated_Date__c, Estimated_By__c FROM User_Story__c WHERE Id = :stories[0].Id];
        System.assertEquals('5', updatedStory.Final_Estimate__c, 'Final estimate should be 5');
        System.assertEquals('Estimated', updatedStory.Status__c, 'Status should be Estimated');
        System.assertNotEquals(null, updatedStory.Estimated_Date__c, 'Estimated date should be set');
        System.assertNotEquals(null, updatedStory.Estimated_By__c, 'Estimated by should be set');
    }

    @isTest
    static void testCalculateStatistics() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        Map<String, Object> stats = VotingController.calculateStatistics(stories[0].Id);
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats should not be null');
        System.assertEquals(5, stats.get('average'), 'Average should be 5');
    }

    @isTest
    static void testGetCurrentUserVote() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '8');

        Test.startTest();
        Estimation_Vote__c vote = VotingController.getCurrentUserVote(stories[0].Id, member.Id);
        Test.stopTest();

        System.assertNotEquals(null, vote, 'Vote should be found');
        System.assertEquals('8', vote.Vote_Value__c, 'Vote value should be 8');
    }

    @isTest
    static void testDeleteVote() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        VotingController.deleteVote(stories[0].Id, member.Id);
        Test.stopTest();

        Integer voteCount = [SELECT COUNT() FROM Estimation_Vote__c WHERE User_Story__c = :stories[0].Id AND Room_Member__c = :member.Id];
        System.assertEquals(0, voteCount, 'Vote should be deleted');
    }

    @isTest
    static void testGetVoteHistory() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        stories[0].Status__c = 'Estimated';
        stories[0].Final_Estimate__c = '5';
        update stories[0];

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        List<Map<String, Object>> history = VotingController.getVoteHistory(room.Id);
        Test.stopTest();

        System.assertNotEquals(0, history.size(), 'History should not be empty');
        System.assertEquals(stories[0].Id, history[0].get('storyId'), 'Story ID should match');
    }

    @isTest
    static void testBroadcastTimer() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        User testUser = (User) setup.get('user');

        Test.startTest();
        System.runAs(testUser) {
            VotingController.broadcastTimer(room.Id, 'timer_start', 60);
        }
        Test.stopTest();
        
        // Success if no exception thrown (facilitator check passes)
        System.assert(true);
    }
}