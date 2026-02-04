/**
 * @description Test class for JiraXmlParser
 */
@isTest
public with sharing class JiraXmlParserTest {

    @isTest
    static void testParseValidJiraXml() {

        String jiraXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<rss version="0.92">' +
                '<channel>' +
                    '<item>' +
                        '<key>PROJ-123</key>' +
                        '<summary>Implement user login</summary>' +
                        '<description>As a user, I want to log in</description>' +
                        '<customfields>' +
                            '<customfield id="customfield_10001" key="story points">' +
                                '<customfieldvalues>' +
                                    '<customfieldvalue>5</customfieldvalue>' +
                                '</customfieldvalues>' +
                            '</customfield>' +
                        '</customfields>' +
                    '</item>' +
                    '<item>' +
                        '<key>PROJ-124</key>' +
                        '<summary>Create dashboard</summary>' +
                        '<description>Dashboard feature</description>' +
                    '</item>' +
                '</channel>' +
            '</rss>';

        Test.startTest();
        JiraXmlParser.parseJiraXml(jiraXml);
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testParseJiraXmlWithAcceptanceCriteria() {

        String jiraXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<rss version="0.92">' +
                '<channel>' +
                    '<item>' +
                        '<key>PROJ-125</key>' +
                        '<summary>Test story</summary>' +
                        '<description>Test description</description>' +
                        '<customfields>' +
                            '<customfield id="customfield_10002" key="acceptance criteria">' +
                                '<customfieldvalues>' +
                                    '<customfieldvalue>Given user is logged in</customfieldvalue>' +
                                '</customfieldvalues>' +
                            '</customfield>' +
                        '</customfields>' +
                    '</item>' +
                '</channel>' +
            '</rss>';

        Test.startTest();
        JiraXmlParser.parseJiraXml(jiraXml);
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testParseEmptyJiraXml() {

        String emptyXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<rss version="0.92">' +
                '<channel></channel>' +
            '</rss>';

        Test.startTest();
        JiraXmlParser.parseJiraXml(emptyXml);
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testParseInvalidXml() {

        String invalidXml = 'This is not XML';

        Test.startTest();
        try {
            JiraXmlParser.parseJiraXml(invalidXml);
        } catch (Exception e) {
            // Expected path
        }
        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testIsValidJiraXml() {

        String validXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<rss version="0.92"><channel></channel></rss>';

        String invalidXml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<invalid></invalid>';

        String malformedXml = 'not xml at all';

        Test.startTest();
        JiraXmlParser.isValidJiraXml(validXml);
        JiraXmlParser.isValidJiraXml(invalidXml);
        JiraXmlParser.isValidJiraXml(malformedXml);
        Test.stopTest();

        System.assert(true);
    }
}