import getNamespacePrefix from "@salesforce/apex/NamespaceController.getNamespacePrefix";

// Matches a namespace prefix on a custom API name, e.g. "ns__Status__c" -> "Status__c".
// Un-namespaced names ("Status__c") do not match because the remainder must itself end in __c/__r/__e/__mdt.
const NAMESPACE_PREFIX_PATTERN =
  /^[A-Za-z][A-Za-z0-9]*__(?=.+__(?:c|r|e|mdt)$)/;

let prefixPromise;

/**
 * Resolves the package namespace prefix ("ns__") or '' when not namespaced. Cached after the first call.
 */
export function getPrefix() {
  if (!prefixPromise) {
    prefixPromise = getNamespacePrefix().catch(() => "");
  }
  return prefixPromise;
}

/**
 * Builds the empApi channel for a platform event, e.g. '/event/ns__Poker_Vote_Event__e'.
 * @param {string} eventApiName Un-namespaced API name, e.g. 'Poker_Vote_Event__e'
 */
export async function getEventChannel(eventApiName) {
  const prefix = await getPrefix();
  return `/event/${prefix}${eventApiName}`;
}

/**
 * Recursively strips the namespace prefix from custom field/relationship keys so components can
 * always read un-namespaced names (Status__c, User__r) regardless of where the package is installed.
 * Works on Apex results, SObjects and platform event payloads. Returns a new object; input is not mutated.
 */
export function stripNamespace(value) {
  if (Array.isArray(value)) {
    return value.map(stripNamespace);
  }
  if (
    value &&
    typeof value === "object" &&
    Object.getPrototypeOf(value) === Object.prototype
  ) {
    const result = {};
    Object.keys(value).forEach((key) => {
      result[key.replace(NAMESPACE_PREFIX_PATTERN, "")] = stripNamespace(
        value[key]
      );
    });
    return result;
  }
  return value;
}
