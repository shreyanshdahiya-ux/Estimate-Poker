/**
 * @description Test helper: grants the package permission sets that user-mode code and the facilitator check rely on
 */
@isTest
public with sharing class TestAccess {
  /**
   * @description Assigns the Admin permission set to the running user. Call from @testSetup so
   * records created and read in tests behave as they do for a real, licensed administrator.
   */
  public static void grantAdminToRunningUser() {
    List<PermissionSet> sets = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Estimation_Poker_Admin'
      LIMIT 1
    ];
    if (sets.isEmpty()) {
      return;
    }
    Id userId = UserInfo.getUserId();
    Integer existing = [
      SELECT COUNT()
      FROM PermissionSetAssignment
      WHERE AssigneeId = :userId AND PermissionSetId = :sets[0].Id
    ];
    if (existing == 0) {
      insert new PermissionSetAssignment(
        AssigneeId = userId,
        PermissionSetId = sets[0].Id
      );
    }
  }

  /**
   * @description Creates a standard user holding only the named package permission set.
   * Setup objects are inserted in their own context to avoid mixed DML with record data.
   * @param permissionSetName API name of the permission set, e.g. Estimation_Poker_Team_Member
   * @param key A unique fragment for the username
   */
  public static User createUserWithPermissionSet(
    String permissionSetName,
    String key
  ) {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :permissionSetName
      LIMIT 1
    ];
    User testUser = new User(
      Alias = key.left(8),
      Email = key + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Test' + key.left(8),
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = key + '@example.com'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert testUser;
      insert new PermissionSetAssignment(
        AssigneeId = testUser.Id,
        PermissionSetId = ps.Id
      );
    }
    return testUser;
  }
}
