/**
 * @description Business logic service for estimation calculations
 * Using 'without sharing' to allow all room members to access estimation data
 */
@SuppressWarnings(
  'PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssMethodCount'
)
public with sharing class EstimationService {
  // Estimation scale definitions
  public static final Map<String, List<String>> ESTIMATION_SCALES = new Map<String, List<String>>{
    'Fibonacci' => new List<String>{
      '0',
      '1',
      '2',
      '3',
      '5',
      '8',
      '13',
      '21',
      '34',
      '55',
      '89',
      '?',
      '☕'
    },
    'Modified Fibonacci' => new List<String>{
      '0',
      '0.5',
      '1',
      '2',
      '3',
      '5',
      '8',
      '13',
      '20',
      '40',
      '100',
      '?',
      '☕'
    },
    'T-Shirt Sizes' => new List<String>{
      'XS',
      'S',
      'M',
      'L',
      'XL',
      'XXL',
      '?',
      '☕'
    },
    'Powers of 2' => new List<String>{
      '0',
      '1',
      '2',
      '4',
      '8',
      '16',
      '32',
      '64',
      '?',
      '☕'
    }
  };

  // Numeric values for T-Shirt sizes
  private static final Map<String, Decimal> TSHIRT_VALUES = new Map<String, Decimal>{
    'XS' => 1,
    'S' => 2,
    'M' => 3,
    'L' => 5,
    'XL' => 8,
    'XXL' => 13
  };

  /**
   * @description Gets the scale values for a given estimation scale
   * @param scaleName The name of the estimation scale
   * @param customValues Custom comma-separated values for Custom scale
   * @return List of scale value strings
   */
  public static List<String> getScaleValues(
    String scaleName,
    String customValues
  ) {
    if (scaleName == 'Custom' && String.isNotBlank(customValues)) {
      return customValues.split(',');
    }

    if (ESTIMATION_SCALES.containsKey(scaleName)) {
      return ESTIMATION_SCALES.get(scaleName);
    }

    return ESTIMATION_SCALES.get('Fibonacci');
  }

  /**
   * @description Calculates the average of numeric votes
   * @param votes List of vote records to average
   * @return The average numeric vote value or null
   */
  public static Decimal calculateAverage(List<Estimation_Vote__c> votes) {
    if (votes == null || votes.isEmpty()) {
      return null;
    }

    Decimal total = 0;
    Integer count = 0;

    for (Estimation_Vote__c vote : votes) {
      if (vote.Vote_Number__c != null) {
        total += vote.Vote_Number__c;
        count++;
      }
    }

    return count > 0 ? total / count : null;
  }

  /**
   * @description Calculates the median of numeric votes
   * @param votes List of vote records to calculate median for
   * @return The median numeric vote value or null
   */
  public static Decimal calculateMedian(List<Estimation_Vote__c> votes) {
    if (votes == null || votes.isEmpty()) {
      return null;
    }

    List<Decimal> numericVotes = new List<Decimal>();
    for (Estimation_Vote__c vote : votes) {
      if (vote.Vote_Number__c != null) {
        numericVotes.add(vote.Vote_Number__c);
      }
    }

    if (numericVotes.isEmpty()) {
      return null;
    }

    numericVotes.sort();
    Integer size = numericVotes.size();
    Integer midIndex = size / 2;

    if (Math.mod(size, 2) == 0) {
      return (numericVotes[midIndex - 1] + numericVotes[midIndex]) / 2;
    } else {
      return numericVotes[midIndex];
    }
  }

  /**
   * @description Identifies outlier votes (more than 2 std deviations from mean)
   * @param votes List of vote records to check for outliers
   * @return List of votes that are statistical outliers
   */
  public static List<Estimation_Vote__c> identifyOutliers(
    List<Estimation_Vote__c> votes
  ) {
    List<Estimation_Vote__c> outliers = new List<Estimation_Vote__c>();

    if (votes == null || votes.size() < 3) {
      return outliers;
    }

    Decimal avg = calculateAverage(votes);
    if (avg == null) {
      return outliers;
    }

    // Calculate standard deviation
    Decimal sumSquaredDiff = 0;
    Integer count = 0;
    for (Estimation_Vote__c vote : votes) {
      if (vote.Vote_Number__c != null) {
        sumSquaredDiff += Math.pow((Double) (vote.Vote_Number__c - avg), 2);
        count++;
      }
    }

    if (count < 2) {
      return outliers;
    }

    Decimal stdDev = Math.sqrt((Double) (sumSquaredDiff / count));
    Decimal lowerBound = avg - (2 * stdDev);
    Decimal upperBound = avg + (2 * stdDev);

    for (Estimation_Vote__c vote : votes) {
      if (
        vote.Vote_Number__c != null &&
        (vote.Vote_Number__c < lowerBound ||
        vote.Vote_Number__c > upperBound)
      ) {
        outliers.add(vote);
      }
    }

    return outliers;
  }

  /**
   * @description Converts a vote value to a numeric value based on the scale
   * @param voteValue The string vote value to convert
   * @param scale The estimation scale being used
   * @return The numeric equivalent or null if not convertible
   */
  public static Decimal convertVoteToNumber(String voteValue, String scale) {
    if (String.isBlank(voteValue) || voteValue == '?' || voteValue == '☕') {
      return null;
    }

    // Handle T-Shirt sizes
    if (
      scale == 'T-Shirt Sizes' &&
      TSHIRT_VALUES.containsKey(voteValue.toUpperCase())
    ) {
      return TSHIRT_VALUES.get(voteValue.toUpperCase());
    }

    // Try to parse as decimal
    try {
      return Decimal.valueOf(voteValue);
    } catch (Exception e) {
      // Non-numeric vote values return null intentionally
      return null;
    }
  }

  /**
   * @description Generates a comprehensive estimation report for a room
   * @param roomId The room to generate the report for
   * @return Map containing room details, stories, summary stats, and participation data
   */
  public static Map<String, Object> generateEstimationReport(Id roomId) {
    Map<String, Object> report = new Map<String, Object>();

    // Get room details
    Estimation_Poker_Room__c room = [
      SELECT
        Id,
        Name,
        Room_Code__c,
        Status__c,
        Estimation_Scale__c,
        Start_DateTime__c,
        End_DateTime__c,
        Facilitator__r.Name
      FROM Estimation_Poker_Room__c
      WHERE Id = :roomId
      WITH USER_MODE
      LIMIT 1
    ];

    report.put('room', room);

    // Get all stories with votes
    List<User_Story__c> stories = [
      SELECT
        Id,
        Name,
        Story_Title__c,
        Status__c,
        Final_Estimate__c,
        Average_Estimate__c,
        Story_Order__c,
        Estimated_Date__c,
        (
          SELECT
            Id,
            Vote_Value__c,
            Vote_Number__c,
            Room_Member__r.User__r.Name,
            Duration__c
          FROM Estimation_Votes__r
        )
      FROM User_Story__c
      WHERE Room__c = :roomId
      WITH USER_MODE
      ORDER BY Story_Order__c NULLS LAST
    ];

    report.put('stories', stories);

    // Calculate summary statistics
    Integer totalStories = stories.size();
    Integer estimatedStories = 0;
    Integer skippedStories = 0;
    Decimal totalPoints = 0;
    Integer storiesWithPoints = 0;

    for (User_Story__c story : stories) {
      if (story.Status__c == 'Estimated') {
        estimatedStories++;
        if (story.Average_Estimate__c != null) {
          totalPoints += story.Average_Estimate__c;
          storiesWithPoints++;
        }
      } else if (story.Status__c == 'Skipped') {
        skippedStories++;
      }
    }

    Map<String, Object> summary = new Map<String, Object>{
      'totalStories' => totalStories,
      'estimatedStories' => estimatedStories,
      'skippedStories' => skippedStories,
      'pendingStories' => totalStories -
      estimatedStories -
      skippedStories,
      'totalPoints' => totalPoints,
      'averagePointsPerStory' => storiesWithPoints > 0
        ? totalPoints / storiesWithPoints
        : 0
    };

    report.put('summary', summary);

    // Get participation data
    List<Room_Member__c> members = [
      SELECT
        Id,
        User__r.Name,
        Role_In_Room__c,
        Can_Vote__c,
        (SELECT Id FROM Estimation_Votes__r)
      FROM Room_Member__c
      WHERE Room__c = :roomId AND Status__c = 'Active'
      WITH USER_MODE
    ];

    List<Map<String, Object>> participation = new List<Map<String, Object>>();
    for (Room_Member__c member : members) {
      if (member.Can_Vote__c) {
        participation.add(
          new Map<String, Object>{
            'name' => member.User__r.Name,
            'role' => member.Role_In_Room__c,
            'votesCount' => member.Estimation_Votes__r.size()
          }
        );
      }
    }

    report.put('participation', participation);

    return report;
  }

  /**
   * @description Gets vote distribution for a story
   * @param votes List of vote records to analyze
   * @return Map of vote values to their counts
   */
  public static Map<String, Integer> getVoteDistribution(
    List<Estimation_Vote__c> votes
  ) {
    Map<String, Integer> distribution = new Map<String, Integer>();

    for (Estimation_Vote__c vote : votes) {
      String value = vote.Vote_Value__c;
      if (distribution.containsKey(value)) {
        distribution.put(value, distribution.get(value) + 1);
      } else {
        distribution.put(value, 1);
      }
    }

    return distribution;
  }

  /**
   * @description Gets statistics for a set of votes
   * @param votes List of vote records to calculate statistics for
   * @return Map containing average, median, min, max, distribution, and other stats
   */
  public static Map<String, Object> getVoteStatistics(
    List<Estimation_Vote__c> votes
  ) {
    Map<String, Object> stats = new Map<String, Object>();

    if (votes == null || votes.isEmpty()) {
      return stats;
    }

    Decimal avg = calculateAverage(votes);
    Decimal median = calculateMedian(votes);
    Map<String, Integer> distribution = getVoteDistribution(votes);
    List<Estimation_Vote__c> outliers = identifyOutliers(votes);

    // Find min and max
    Decimal minVote = null;
    Decimal maxVote = null;
    for (Estimation_Vote__c vote : votes) {
      if (vote.Vote_Number__c != null) {
        if (minVote == null || vote.Vote_Number__c < minVote) {
          minVote = vote.Vote_Number__c;
        }
        if (maxVote == null || vote.Vote_Number__c > maxVote) {
          maxVote = vote.Vote_Number__c;
        }
      }
    }

    stats.put('average', avg);
    stats.put('median', median);
    stats.put('min', minVote);
    stats.put('max', maxVote);
    stats.put(
      'range',
      (maxVote != null && minVote != null) ? (maxVote - minVote) : 0
    );
    stats.put('distribution', distribution);
    stats.put('outlierCount', outliers.size());
    stats.put('totalVotes', votes.size());
    // Agreement needs at least two votes: a single vote cannot be a consensus
    stats.put('hasConsensus', votes.size() >= 2 && distribution.size() == 1);

    // Calculate standard deviation for results visibility
    if (avg != null && votes.size() > 1) {
      Decimal sumSquaredDiff = 0;
      Integer count = 0;
      for (Estimation_Vote__c vote : votes) {
        if (vote.Vote_Number__c != null) {
          sumSquaredDiff += Math.pow((Double) (vote.Vote_Number__c - avg), 2);
          count++;
        }
      }
      if (count > 0) {
        stats.put(
          'standardDeviation',
          Math.sqrt((Double) (sumSquaredDiff / count))
        );
      }
    }

    return stats;
  }
}
