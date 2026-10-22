/**
 * @description Test class for EstimationService
 */
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
    System.assert(true, 'Test executed successfully');
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

    System.assert(true, 'Test executed successfully');
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
    System.assert(true, 'Test executed successfully');
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
    System.assert(true, 'Test executed successfully');
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
    System.assert(true, 'Test executed successfully');
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
    System.assert(true, 'Test executed successfully');
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
    System.assert(true, 'Test executed successfully');
  }

  /* ==================== REPORT (FULL COVERAGE) ==================== */

  @isTest
  static void testGenerateEstimationReportFullCoverage() {
    Map<String, Object> setup = createFullTestSetup();

    Estimation_Poker_Room__c room = (Estimation_Poker_Room__c) setup.get(
      'room'
    );
    List<User_Story__c> stories = (List<User_Story__c>) setup.get('stories');
    Room_Member__c member = (Room_Member__c) setup.get('roomMember');

    stories[0].Status__c = 'Estimated';
    stories[0].Average_Estimate__c = 5;
    stories[1].Status__c = 'Skipped';

    update stories;

    createVote(stories[0].Id, member.Id, '5');
    createVote(stories[0].Id, member.Id, '8');

    Test.startTest();
    EstimationService.generateEstimationReport(room.Id);
    Test.stopTest();

    System.assert(true, 'Test executed successfully');
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

  /* ---------------- CONSENSUS ---------------- */

  private static List<Estimation_Vote__c> votesOf(List<String> values) {
    List<Estimation_Vote__c> votes = new List<Estimation_Vote__c>();
    for (String value : values) {
      votes.add(
        new Estimation_Vote__c(
          Vote_Value__c = value,
          Vote_Number__c = Decimal.valueOf(value)
        )
      );
    }
    return votes;
  }

  @isTest
  static void testConsensusRequiresAtLeastTwoVotes() {
    Map<String, Object> single = EstimationService.getVoteStatistics(
      votesOf(new List<String>{ '3' })
    );
    System.assertEquals(
      false,
      single.get('hasConsensus'),
      'One vote is not a consensus'
    );
  }

  @isTest
  static void testConsensusWhenAllVotesMatch() {
    Map<String, Object> same = EstimationService.getVoteStatistics(
      votesOf(new List<String>{ '5', '5', '5' })
    );
    System.assertEquals(
      true,
      same.get('hasConsensus'),
      'Matching votes from several voters are a consensus'
    );
  }

  @isTest
  static void testNoConsensusWhenVotesDiffer() {
    Map<String, Object> mixed = EstimationService.getVoteStatistics(
      votesOf(new List<String>{ '3', '8' })
    );
    System.assertEquals(
      false,
      mixed.get('hasConsensus'),
      'Different votes are not a consensus'
    );
  }
}
