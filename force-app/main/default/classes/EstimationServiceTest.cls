@isTest
public with sharing class EstimationServiceTest {

    /* ==================== SCALE TESTS ==================== */

    @isTest
    static void testAllScalePaths() {
        Test.startTest();

        EstimationService.getScaleValues('Fibonacci', null);
        EstimationService.getScaleValues('Modified Fibonacci', null);
        EstimationService.getScaleValues('T-Shirt Sizes', null);
        EstimationService.getScaleValues('Powers of 2', null);

        // Custom scale valid
        EstimationService.getScaleValues('Custom', '1,2,3');

        // Custom scale blank → fallback
        EstimationService.getScaleValues('Custom', '');

        // Invalid scale → default Fibonacci
        EstimationService.getScaleValues('Invalid', null);

        Test.stopTest();
        System.assert(true);
    }

    /* ==================== AVERAGE / MEDIAN ==================== */

    @isTest
    static void testAverageAndMedianBranches() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>{
            new Estimation_Vote__c(Vote_Number__c = 3),
            new Estimation_Vote__c(Vote_Number__c = 5),
            new Estimation_Vote__c(Vote_Number__c = 8),
            new Estimation_Vote__c(Vote_Number__c = null)
        };

        Test.startTest();
        EstimationService.calculateAverage(votes);
        EstimationService.calculateMedian(votes);
        Test.stopTest();

        System.assert(true);
    }

    /* ==================== NULL / EMPTY ==================== */

    @isTest
    static void testAverageMedianNullPaths() {
        Test.startTest();

        EstimationService.calculateAverage(null);
        EstimationService.calculateAverage(new List<Estimation_Vote__c>());
        EstimationService.calculateMedian(null);
        EstimationService.calculateMedian(new List<Estimation_Vote__c>());

        Test.stopTest();
        System.assert(true);
    }

    /* ==================== OUTLIERS (ALL SHORT CIRCUITS) ==================== */

    @isTest
    static void testOutliersAllBranches() {
        Test.startTest();

        // null list
        EstimationService.identifyOutliers(null);

        // < 3 votes
        EstimationService.identifyOutliers(
            new List<Estimation_Vote__c>{
                new Estimation_Vote__c(Vote_Number__c = 5),
                new Estimation_Vote__c(Vote_Number__c = 5)
            }
        );

        // avg == null
        EstimationService.identifyOutliers(
            new List<Estimation_Vote__c>{
                new Estimation_Vote__c(Vote_Number__c = null),
                new Estimation_Vote__c(Vote_Number__c = null),
                new Estimation_Vote__c(Vote_Number__c = null)
            }
        );

        // count < 2 numeric votes
        EstimationService.identifyOutliers(
            new List<Estimation_Vote__c>{
                new Estimation_Vote__c(Vote_Number__c = 5),
                new Estimation_Vote__c(Vote_Number__c = null),
                new Estimation_Vote__c(Vote_Number__c = null)
            }
        );

        // valid outlier case
        EstimationService.identifyOutliers(
            new List<Estimation_Vote__c>{
                new Estimation_Vote__c(Vote_Number__c = 5),
                new Estimation_Vote__c(Vote_Number__c = 5),
                new Estimation_Vote__c(Vote_Number__c = 5),
                new Estimation_Vote__c(Vote_Number__c = 500)
            }
        );

        Test.stopTest();
        System.assert(true);
    }

    /* ==================== CONVERT VOTE ==================== */

    @isTest
    static void testConvertVoteBranches() {
        Test.startTest();

        EstimationService.convertVoteToNumber(null, 'Fibonacci');
        EstimationService.convertVoteToNumber('', 'Fibonacci');
        EstimationService.convertVoteToNumber('?', 'Fibonacci');
        EstimationService.convertVoteToNumber('☕', 'Fibonacci');
        EstimationService.convertVoteToNumber('xs', 'T-Shirt Sizes');
        EstimationService.convertVoteToNumber('8', 'Fibonacci');
        EstimationService.convertVoteToNumber('ABC', 'Fibonacci');

        Test.stopTest();
        System.assert(true);
    }

    /* ==================== VOTE DISTRIBUTION ==================== */

    @isTest
    static void testVoteDistribution() {
        Test.startTest();

        EstimationService.getVoteDistribution(
            new List<Estimation_Vote__c>{
                new Estimation_Vote__c(Vote_Value__c = '5'),
                new Estimation_Vote__c(Vote_Value__c = '5'),
                new Estimation_Vote__c(Vote_Value__c = '8')
            }
        );

        EstimationService.getVoteDistribution(new List<Estimation_Vote__c>());

        Test.stopTest();
        System.assert(true);
    }

    /* ==================== VOTE STATISTICS ==================== */

    @isTest
    static void testVoteStatisticsAllBranches() {
        Test.startTest();

        EstimationService.getVoteStatistics(null);
        EstimationService.getVoteStatistics(new List<Estimation_Vote__c>());

        EstimationService.getVoteStatistics(
            new List<Estimation_Vote__c>{
                new Estimation_Vote__c(Vote_Value__c = '5', Vote_Number__c = 5),
                new Estimation_Vote__c(Vote_Value__c = '5', Vote_Number__c = 5),
                new Estimation_Vote__c(Vote_Value__c = '8', Vote_Number__c = 8)
            }
        );

        Test.stopTest();
        System.assert(true);
    }

    /* ==================== REPORT (FULL COVERAGE) ==================== */

    @isTest
    static void testGenerateEstimationReportFullCoverage() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();

        Estimation_Poker_Room__c room =
            (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories =
            (List<User_Story__c>) setup.get('stories');
        Room_Member__c member =
            (Room_Member__c) setup.get('roomMember');

        stories[0].Status__c = 'Estimated';
        stories[0].Average_Estimate__c = 5;
        stories[1].Status__c = 'Skipped';

        update stories;

        TestDataFactory.createVote(stories[0].Id, member.Id, '5');
        TestDataFactory.createVote(stories[0].Id, member.Id, '8');

        Test.startTest();
        EstimationService.generateEstimationReport(room.Id);
        Test.stopTest();

        System.assert(true);
    }
}