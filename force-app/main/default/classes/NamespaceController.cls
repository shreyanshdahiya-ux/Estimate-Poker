/**
 * @description Exposes the package namespace prefix to Lightning Web Components so
 * channel names (e.g. /event/ns__Poker_Vote_Event__e) can be built without hardcoding it.
 */
public with sharing class NamespaceController {
  /**
   * @description Returns the namespace prefix including the trailing double underscore
   * (e.g. 'ns__'), or an empty string when running outside a namespaced package.
   * @return The namespace prefix or an empty string
   */
  @AuraEnabled(cacheable=true)
  public static String getNamespacePrefix() {
    // Type names of namespaced classes are returned as 'namespace.ClassName'
    String className = NamespaceController.class.getName();
    return className.contains('.') ? className.substringBefore('.') + '__' : '';
  }
}
