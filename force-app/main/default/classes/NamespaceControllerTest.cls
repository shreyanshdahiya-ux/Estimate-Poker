@isTest
public with sharing class NamespaceControllerTest {
  @isTest
  static void testGetNamespacePrefix_MatchesOrgNamespace() {
    Test.startTest();
    String prefix = NamespaceController.getNamespacePrefix();
    Test.stopTest();

    String className = NamespaceController.class.getName();
    String expected = className.contains('.')
      ? className.substringBefore('.') + '__'
      : '';
    System.assertEquals(
      expected,
      prefix,
      'Prefix should be derived from the class namespace'
    );
    if (String.isNotEmpty(prefix)) {
      System.assert(
        prefix.endsWith('__'),
        'A namespace prefix must end with a double underscore'
      );
    }
  }
}
