/**
 * @description Test class for EstimationService
 */
@isTest
private class EstimationServiceTest {

    @isTest
    static void testGetScaleValuesFibonacci() {
        Test.startTest();
        List<String> values = EstimationService.getScaleValues('Fibonacci', null);
        Test.stopTest();

        System.assert(values.contains('1'), 'Should contain 1');
        System.assert(values.contains('5'), 'Should contain 5');
        System.assert(values.contains('13'), 'Should contain 13');
        System.assert(values.contains('?'), 'Should contain ?');
    }

    @isTest
    static void testGetScaleValuesModifiedFibonacci() {
        Test.startTest();
        List<String> values = EstimationService.getScaleValues('Modified Fibonacci', null);
        Test.stopTest();

        System.assert(values.contains('0.5'), 'Should contain 0.5');
        System.assert(values.contains('100'), 'Should contain 100');
    }

    @isTest
    static void testGetScaleValuesTShirt() {
        Test.startTest();
        List<String> values = EstimationService.getScaleValues('T-Shirt Sizes', null);
        Test.stopTest();

        System.assert(values.contains('XS'), 'Should contain XS');
        System.assert(values.contains('M'), 'Should contain M');
        System.assert(values.contains('XXL'), 'Should contain XXL');
    }

    @isTest
    static void testGetScaleValuesPowersOf2() {
        Test.startTest();
        List<String> values = EstimationService.getScaleValues('Powers of 2', null);
        Test.stopTest();

        System.assert(values.contains('1'), 'Should contain 1');
        System.assert(values.contains('4'), 'Should contain 4');
        System.assert(values.contains('64'), 'Should contain 64');
    }

    @isTest
    static void testGetScaleValuesCustom() {
        Test.startTest();
        List<String> values = EstimationService.getScaleValues('Custom', '1,2,3,5,8');
        Test.stopTest();

        System.assertEquals(5, values.size(), 'Should have 5 values');
        System.assert(values.contains('1'), 'Should contain 1');
        System.assert(values.contains('8'), 'Should contain 8');
    }

    @isTest
    static void testGetScaleValuesInvalid() {
        Test.startTest();
        List<String> values = EstimationService.getScaleValues('Invalid Scale', null);
        Test.stopTest();

        // Should default to Fibonacci
        System.assert(values.contains('13'), 'Should default to Fibonacci');
    }

    @isTest
    static void testCalculateAverage() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Number__c = 3));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 8));

        Test.startTest();
        Decimal avg = EstimationService.calculateAverage(votes);
        Test.stopTest();

        System.assertEquals(5.33, avg.setScale(2, RoundingMode.HALF_UP), 'Average should be approximately 5.33');
    }

    @isTest
    static void testCalculateAverageEmpty() {
        Test.startTest();
        Decimal avg = EstimationService.calculateAverage(new List<Estimation_Vote__c>());
        Test.stopTest();

        System.assertEquals(null, avg, 'Average of empty list should be null');
    }

    @isTest
    static void testCalculateAverageNull() {
        Test.startTest();
        Decimal avg = EstimationService.calculateAverage(null);
        Test.stopTest();

        System.assertEquals(null, avg, 'Average of null should be null');
    }

    @isTest
    static void testCalculateAverageNoNumericValues() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Number__c = null));
        votes.add(new Estimation_Vote__c(Vote_Number__c = null));

        Test.startTest();
        Decimal avg = EstimationService.calculateAverage(votes);
        Test.stopTest();

        System.assertEquals(null, avg, 'Average with no numeric values should be null');
    }

    @isTest
    static void testCalculateMedianOdd() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Number__c = 3));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 8));

        Test.startTest();
        Decimal median = EstimationService.calculateMedian(votes);
        Test.stopTest();

        System.assertEquals(5, median, 'Median of odd count should be middle value');
    }

    @isTest
    static void testCalculateMedianEven() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Number__c = 3));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 8));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 13));

        Test.startTest();
        Decimal median = EstimationService.calculateMedian(votes);
        Test.stopTest();

        System.assertEquals(6.5, median, 'Median of even count should be average of two middle values');
    }

    @isTest
    static void testCalculateMedianEmpty() {
        Test.startTest();
        Decimal median = EstimationService.calculateMedian(new List<Estimation_Vote__c>());
        Test.stopTest();

        System.assertEquals(null, median, 'Median of empty list should be null');
    }

    @isTest
    static void testIdentifyOutliers() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 100)); // Outlier

        Test.startTest();
        List<Estimation_Vote__c> outliers = EstimationService.identifyOutliers(votes);
        Test.stopTest();

        System.assertEquals(1, outliers.size(), 'Should identify one outlier');
        System.assertEquals(100, outliers[0].Vote_Number__c, 'Outlier should be 100');
    }

    @isTest
    static void testIdentifyOutliersNotEnoughVotes() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Number__c = 100));

        Test.startTest();
        List<Estimation_Vote__c> outliers = EstimationService.identifyOutliers(votes);
        Test.stopTest();

        System.assertEquals(0, outliers.size(), 'Should not identify outliers with less than 3 votes');
    }

    @isTest
    static void testConvertVoteToNumberNumeric() {
        Test.startTest();
        Decimal value = EstimationService.convertVoteToNumber('8', 'Fibonacci');
        Test.stopTest();

        System.assertEquals(8, value, 'Should convert numeric string to decimal');
    }

    @isTest
    static void testConvertVoteToNumberTShirt() {
        Test.startTest();
        Decimal xs = EstimationService.convertVoteToNumber('XS', 'T-Shirt Sizes');
        Decimal m = EstimationService.convertVoteToNumber('M', 'T-Shirt Sizes');
        Decimal xl = EstimationService.convertVoteToNumber('XL', 'T-Shirt Sizes');
        Test.stopTest();

        System.assertEquals(1, xs, 'XS should be 1');
        System.assertEquals(3, m, 'M should be 3');
        System.assertEquals(8, xl, 'XL should be 8');
    }

    @isTest
    static void testConvertVoteToNumberSpecial() {
        Test.startTest();
        Decimal question = EstimationService.convertVoteToNumber('?', 'Fibonacci');
        Decimal coffee = EstimationService.convertVoteToNumber('☕', 'Fibonacci');
        Decimal blank = EstimationService.convertVoteToNumber('', 'Fibonacci');
        Test.stopTest();

        System.assertEquals(null, question, '? should be null');
        System.assertEquals(null, coffee, 'Coffee should be null');
        System.assertEquals(null, blank, 'Blank should be null');
    }

    @isTest
    static void testConvertVoteToNumberDecimal() {
        Test.startTest();
        Decimal value = EstimationService.convertVoteToNumber('0.5', 'Modified Fibonacci');
        Test.stopTest();

        System.assertEquals(0.5, value, 'Should convert decimal string');
    }

    @isTest
    static void testGetVoteDistribution() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Value__c = '5'));
        votes.add(new Estimation_Vote__c(Vote_Value__c = '5'));
        votes.add(new Estimation_Vote__c(Vote_Value__c = '8'));

        Test.startTest();
        Map<String, Integer> distribution = EstimationService.getVoteDistribution(votes);
        Test.stopTest();

        System.assertEquals(2, distribution.get('5'), 'Should have 2 votes for 5');
        System.assertEquals(1, distribution.get('8'), 'Should have 1 vote for 8');
    }

    @isTest
    static void testGetVoteStatistics() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Value__c = '5', Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Value__c = '5', Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Value__c = '8', Vote_Number__c = 8));

        Test.startTest();
        Map<String, Object> stats = EstimationService.getVoteStatistics(votes);
        Test.stopTest();

        System.assertNotEquals(null, stats.get('average'), 'Should have average');
        System.assertNotEquals(null, stats.get('median'), 'Should have median');
        System.assertEquals(5, stats.get('min'), 'Min should be 5');
        System.assertEquals(8, stats.get('max'), 'Max should be 8');
        System.assertEquals(3, stats.get('totalVotes'), 'Total should be 3');
        System.assertEquals(false, stats.get('hasConsensus'), 'Should not have consensus');
    }

    @isTest
    static void testGetVoteStatisticsConsensus() {
        List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
        votes.add(new Estimation_Vote__c(Vote_Value__c = '5', Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Value__c = '5', Vote_Number__c = 5));
        votes.add(new Estimation_Vote__c(Vote_Value__c = '5', Vote_Number__c = 5));

        Test.startTest();
        Map<String, Object> stats = EstimationService.getVoteStatistics(votes);
        Test.stopTest();

        System.assertEquals(true, stats.get('hasConsensus'), 'Should have consensus when all votes are same');
    }

    @isTest
    static void testGetVoteStatisticsEmpty() {
        Test.startTest();
        Map<String, Object> stats = EstimationService.getVoteStatistics(new List<Estimation_Vote__c>());
        Test.stopTest();

        System.assertEquals(0, stats.size(), 'Empty stats for empty votes');
    }

    @isTest
    static void testGenerateEstimationReport() {
        Map<String, Object> setup = TestDataFactory.createFullTestSetup();
        Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get('room');
        List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
        Room_Member__c member = (Room_Member__c) setup.get('roomMember');

        // Mark a story as estimated
        stories[0].Status__c = 'Estimated';
        stories[0].Final_Estimate__c = '5';
        stories[0].Average_Estimate__c = 5;
        update stories[0];

        // Create a vote
        TestDataFactory.createVote(stories[0].Id, member.Id, '5');

        Test.startTest();
        Map<String, Object> report = EstimationService.generateEstimationReport(room.Id);
        Test.stopTest();

        System.assertNotEquals(null, report.get('room'), 'Should have room data');
        System.assertNotEquals(null, report.get('stories'), 'Should have stories data');
        System.assertNotEquals(null, report.get('summary'), 'Should have summary data');
        System.assertNotEquals(null, report.get('participation'), 'Should have participation data');

        Map<String, Object> summary = (Map<String, Object>) report.get('summary');
        System.assertEquals(5, summary.get('totalStories'), 'Should have 5 total stories');
        System.assertEquals(1, summary.get('estimatedStories'), 'Should have 1 estimated story');
    }
}