import { stripNamespace, getEventChannel, getPrefix } from "c/nsUtil";
import getNamespacePrefix from "@salesforce/apex/NamespaceController.getNamespacePrefix";

jest.mock(
  "@salesforce/apex/NamespaceController.getNamespacePrefix",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

describe("c-ns-util stripNamespace", () => {
  it("removes the namespace from custom fields and relationships", () => {
    const input = {
      Id: "001",
      ns__Status__c: "Voting",
      ns__User__r: { Name: "A", ns__Role__c: "x" }
    };
    expect(stripNamespace(input)).toEqual({
      Id: "001",
      Status__c: "Voting",
      User__r: { Name: "A", Role__c: "x" }
    });
  });

  it("leaves un-namespaced and standard keys untouched", () => {
    const input = {
      Id: "1",
      Name: "n",
      Status__c: "a",
      Room_Code__c: "b",
      User__r: { Name: "c" }
    };
    expect(stripNamespace(input)).toEqual(input);
  });

  it("handles arrays, nulls and primitives, and does not mutate input", () => {
    const input = [{ ns__A__c: 1 }, null, "text", 5];
    const copy = JSON.parse(JSON.stringify(input));
    expect(stripNamespace(input)).toEqual([{ A__c: 1 }, null, "text", 5]);
    expect(input).toEqual(copy);
  });
});

describe("c-ns-util channels", () => {
  it("builds an un-namespaced channel when the prefix is empty", async () => {
    getNamespacePrefix.mockResolvedValue("");
    expect(await getPrefix()).toBe("");
    expect(await getEventChannel("Poker_Vote_Event__e")).toBe(
      "/event/Poker_Vote_Event__e"
    );
  });
});
