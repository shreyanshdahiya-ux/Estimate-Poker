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

describe("c-ns-util with a namespace", () => {
  it("builds namespaced event channels from the prefix Apex returns", async () => {
    let nsUtil;
    let apexMock;
    // Isolated registry: the prefix is cached per module instance
    jest.isolateModules(() => {
      nsUtil = require("c/nsUtil");
      apexMock =
        require("@salesforce/apex/NamespaceController.getNamespacePrefix").default;
    });
    apexMock.mockResolvedValue("estpoker__");

    expect(await nsUtil.getEventChannel("Poker_Vote_Event__e")).toBe(
      "/event/estpoker__Poker_Vote_Event__e"
    );
    expect(await nsUtil.getEventChannel("Poker_Room_Event__e")).toBe(
      "/event/estpoker__Poker_Room_Event__e"
    );
  });

  it("strips a real namespace from Apex results and event payloads", () => {
    const payload = {
      estpoker__Story_Id__c: "a0I1",
      estpoker__Final_Estimate__c: "8",
      estpoker__Current_Story__r: { Name: "S-1" },
      Id: "a0J1"
    };
    expect(stripNamespace(payload)).toEqual({
      Story_Id__c: "a0I1",
      Final_Estimate__c: "8",
      Current_Story__r: { Name: "S-1" },
      Id: "a0J1"
    });
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
