/**
 * @description Validation service for Planning Poker data
 * Using 'without sharing' to allow validation queries to run without sharing restrictions
 */
@SuppressWarnings(
  'PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.AvoidDeeplyNestedIfStmts'
)
public with sharing class ValidationService {
  /** @description Custom exception for validation errors */
  public class ValidationException extends Exception {
  }

  /**
   * @description Validates room data before creation/update
   * @param roomData Map of room fields
   */
  public static void validateRoomData(Map<String, Object> roomData) {
    List<String> errors = new List<String>();

    validateBasicRoomInfo(roomData, errors);
    validateScaleConfig(roomData, errors);
    validateFacilitator(roomData, errors);

    if (!errors.isEmpty()) {
      throw new ValidationException(String.join(errors, '; '));
    }
  }

  /**
   * @description Validates basic room information fields
   * @param roomData Map of room field values
   * @param errors List to collect validation error messages
   */
  private static void validateBasicRoomInfo(
    Map<String, Object> roomData,
    List<String> errors
  ) {
    String roomName = (String) roomData.get('name');
    if (String.isBlank(roomName)) {
      errors.add('Room name is required');
    } else if (roomName.length() > 80) {
      errors.add('Room name cannot exceed 80 characters');
    }
  }

  /**
   * @description Validates estimation scale configuration
   * @param roomData Map of room field values
   * @param errors List to collect validation error messages
   */
  private static void validateScaleConfig(
    Map<String, Object> roomData,
    List<String> errors
  ) {
    String scale = (String) roomData.get('estimationScale');
    if (String.isNotBlank(scale)) {
      Set<String> validScales = new Set<String>{
        'Fibonacci',
        'Modified Fibonacci',
        'T-Shirt Sizes',
        'Powers of 2',
        'Custom'
      };
      if (!validScales.contains(scale)) {
        errors.add('Invalid estimation scale: ' + scale);
      }

      if (scale == 'Custom') {
        String customValues = (String) roomData.get('customScaleValues');
        if (String.isBlank(customValues)) {
          errors.add(
            'Custom scale values are required when using Custom scale'
          );
        }
      }
    }
  }

  /**
   * @description Validates the facilitator ID if provided
   * @param roomData Map of room field values
   * @param errors List to collect validation error messages
   */
  private static void validateFacilitator(
    Map<String, Object> roomData,
    List<String> errors
  ) {
    String facilitatorId = (String) roomData.get('facilitatorId');
    if (String.isNotBlank(facilitatorId)) {
      try {
        Id.valueOf(facilitatorId);
      } catch (Exception e) {
        errors.add('Invalid facilitator ID');
      }
    }
  }

  /**
   * @description Validates story data before creation/update
   * @param storyData Map of story fields
   */
  public static void validateStoryData(Map<String, Object> storyData) {
    List<String> errors = new List<String>();

    validateStoryBasicInfo(storyData, errors);
    validateStoryOrder(storyData, errors);

    if (!errors.isEmpty()) {
      throw new ValidationException(String.join(errors, '; '));
    }
  }

  /**
   * @description Validates basic story information fields
   * @param storyData Map of story field values
   * @param errors List to collect validation error messages
   */
  private static void validateStoryBasicInfo(
    Map<String, Object> storyData,
    List<String> errors
  ) {
    String title = (String) storyData.get('title');
    if (String.isBlank(title)) {
      errors.add('Story title is required');
    } else if (title.length() > 255) {
      errors.add('Story title cannot exceed 255 characters');
    }

    String roomId = (String) storyData.get('roomId');
    if (String.isBlank(roomId)) {
      errors.add('Room ID is required');
    } else {
      try {
        Id.valueOf(roomId);
      } catch (Exception e) {
        errors.add('Invalid room ID');
      }
    }
  }

  /**
   * @description Validates the story order value if provided
   * @param storyData Map of story field values
   * @param errors List to collect validation error messages
   */
  private static void validateStoryOrder(
    Map<String, Object> storyData,
    List<String> errors
  ) {
    Object orderObj = storyData.get('storyOrder');
    if (orderObj != null) {
      try {
        Integer order = Integer.valueOf(String.valueOf(orderObj));
        if (order < 0) {
          errors.add('Story order cannot be negative');
        }
      } catch (Exception e) {
        errors.add('Invalid story order value');
      }
    }
  }

  /**
   * @description Validates vote data before submission
   * @param voteData Map of vote fields
   */
  public static void validateVote(Map<String, Object> voteData) {
    List<String> errors = new List<String>();

    // Validate story ID
    String storyId = (String) voteData.get('storyId');
    if (String.isBlank(storyId)) {
      errors.add('Story ID is required');
    }

    // Validate room member ID
    String roomMemberId = (String) voteData.get('roomMemberId');
    if (String.isBlank(roomMemberId)) {
      errors.add('Room member ID is required');
    }

    // Validate vote value
    String voteValue = (String) voteData.get('voteValue');
    if (String.isBlank(voteValue)) {
      errors.add('Vote value is required');
    } else if (voteValue.length() > 50) {
      errors.add('Vote value cannot exceed 50 characters');
    }

    if (!errors.isEmpty()) {
      throw new ValidationException(String.join(errors, '; '));
    }
  }

  /**
   * @description Checks if a user can vote on a specific story
   * @param roomMemberId ID of the room member
   * @param storyId ID of the story
   * @return True if voting is allowed
   */
  public static Boolean canUserVote(Id roomMemberId, Id storyId) {
    // Get room member details
    List<Room_Member__c> members = [
      SELECT Id, Can_Vote__c, Status__c, Room__c, Room__r.Status__c
      FROM Room_Member__c
      WHERE Id = :roomMemberId
      WITH USER_MODE
      LIMIT 1
    ];

    if (members.isEmpty()) {
      return false;
    }

    Room_Member__c member = members[0];

    // Check if member is active/invited and can vote
    if (
      !member.Can_Vote__c ||
      (member.Status__c != 'Active' &&
      member.Status__c != 'Invited')
    ) {
      return false;
    }

    // Check if room is active
    if (member.Room__r.Status__c != 'Active') {
      return false;
    }

    // Get story details
    List<User_Story__c> stories = [
      SELECT Id, Status__c, Room__c, Votes_Revealed__c
      FROM User_Story__c
      WHERE Id = :storyId
      WITH USER_MODE
      LIMIT 1
    ];

    if (stories.isEmpty()) {
      return false;
    }

    User_Story__c story = stories[0];

    // Check if story belongs to the same room
    if (story.Room__c != member.Room__c) {
      return false;
    }

    // Check if story is in voting status and votes are not revealed
    if (story.Status__c != 'Voting' && story.Status__c != 'Discussing') {
      return false;
    }

    if (story.Votes_Revealed__c) {
      return false;
    }

    return true;
  }

  /**
   * @description Validates that room name is unique among active rooms
   * @param roomName Name to check
   * @param excludeRoomId ID to exclude (for updates)
   */
  public static void validateUniqueRoomName(String roomName, Id excludeRoomId) {
    String query = 'SELECT Id FROM Estimation_Poker_Room__c WHERE Name = :roomName AND Status__c != \'Archived\'';

    if (excludeRoomId != null) {
      query += ' AND Id != :excludeRoomId';
    }
    query += ' WITH USER_MODE';

    List<Estimation_Poker_Room__c> existingRooms = Database.query(query);

    if (!existingRooms.isEmpty()) {
      throw new ValidationException('A room with this name already exists');
    }
  }

  /**
   * @description Validates that a user is not already a member of the room
   * @param roomId ID of the room
   * @param odataUserId ID of the user
   * @param excludeMemberId ID to exclude
   */
  public static void validateUniqueRoomMember(
    Id roomId,
    Id odataUserId,
    Id excludeMemberId
  ) {
    String query = 'SELECT Id FROM Room_Member__c WHERE Room__c = :roomId AND User__c = :odataUserId AND Status__c != \'Removed\'';

    if (excludeMemberId != null) {
      query += ' AND Id != :excludeMemberId';
    }
    query += ' WITH USER_MODE';

    List<Room_Member__c> existingMembers = Database.query(query);

    if (!existingMembers.isEmpty()) {
      throw new ValidationException(
        'User is already an active member of this room'
      );
    }
  }

  /**
   * @description Validates team member uniqueness
   * @param teamId ID of the team
   * @param odataUserId ID of the user
   * @param excludeMemberId ID to exclude
   */
  public static void validateUniqueTeamMember(
    Id teamId,
    Id odataUserId,
    Id excludeMemberId
  ) {
    String query = 'SELECT Id FROM Team_Member__c WHERE Team__c = :teamId AND User__c = :odataUserId AND Active__c = true';

    if (excludeMemberId != null) {
      query += ' AND Id != :excludeMemberId';
    }
    query += ' WITH USER_MODE';

    List<Team_Member__c> existingMembers = Database.query(query);

    if (!existingMembers.isEmpty()) {
      throw new ValidationException(
        'User is already an active member of this team'
      );
    }
  }

  /**
   * @description Validates that estimate cannot be finalized without votes
   * @param storyId ID of the story
   */
  public static void validateFinalizeEstimate(Id storyId) {
    List<Estimation_Vote__c> votes = [
      SELECT Id
      FROM Estimation_Vote__c
      WHERE User_Story__c = :storyId
      WITH USER_MODE
      LIMIT 1
    ];

    if (votes.isEmpty()) {
      throw new ValidationException(
        'Cannot finalize estimate without any votes'
      );
    }
  }

  /**
   * @description Whether the running user holds the Facilitate Estimation Rooms custom permission,
   * which the Facilitator and Admin permission sets grant
   * @return True if the user may facilitate rooms
   */
  public static Boolean hasFacilitatorPermission() {
    return FeatureManagement.checkPermission('Facilitate_Estimation_Rooms');
  }

  /**
   * @description Throws unless the running user can manage the given room
   * @param roomId The room being changed
   * @param message The error shown to the user when access is denied
   */
  public static void requireRoomManager(Id roomId, String message) {
    if (!canManageRoom(roomId, UserInfo.getUserId())) {
      AuraHandledException ex = new AuraHandledException(message);
      ex.setMessage(message);
      throw ex;
    }
  }

  /**
   * @description Checks if user has permission to manage room
   * @param roomId ID of the room
   * @param odataUserId ID of the user
   * @return True if user can manage the room
   */
  public static Boolean canManageRoom(Id roomId, Id odataUserId) {
    // Facilitating is an admin-granted capability (custom permission), so it cannot be gained by editing
    // room data. FeatureManagement only evaluates the running user, which is who every caller passes in.
    if (odataUserId != UserInfo.getUserId() || !hasFacilitatorPermission()) {
      return false;
    }

    List<Estimation_Poker_Room__c> rooms = [
      SELECT Id, Facilitator__c
      FROM Estimation_Poker_Room__c
      WHERE Id = :roomId
      WITH USER_MODE
      LIMIT 1
    ];

    if (rooms.isEmpty()) {
      return false;
    }

    // Room facilitator can manage
    if (rooms[0].Facilitator__c == odataUserId) {
      return true;
    }

    // Check if user is a facilitator in the room
    List<Room_Member__c> members = [
      SELECT Id
      FROM Room_Member__c
      WHERE
        Room__c = :roomId
        AND User__c = :odataUserId
        AND Role_In_Room__c = 'Facilitator'
        AND Status__c = 'Active'
      WITH USER_MODE
      LIMIT 1
    ];

    return !members.isEmpty();
  }
}
