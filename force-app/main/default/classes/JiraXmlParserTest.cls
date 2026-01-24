/**
 * @description Test class for JiraXmlParser
 */
@isTest
public class JiraXmlParserTest {
    
    @isTest
    static void testParseValidJiraXml() {
        // Create sample Jira XML
        String jiraXml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<rss version="0.92">' +
            '<channel>' +
            '<item>' +
            '<key>PROJ-123</key>' +
            '<summary>Implement user login</summary>' +
            '<description>As a user, I want to log in to the system</description>' +
            '<customfields>' +
            '<customfield id="customfield_10001" key="com.atlassian.jira.plugin.system.customfieldtypes:storypoints">' +
            '<customfieldvalues>' +
            '<customfieldvalue>5</customfieldvalue>' +
            '</customfieldvalues>' +
            '</customfield>' +
            '</customfields>' +
            '</item>' +
            '<item>' +
            '<key>PROJ-124</key>' +
            '<summary>Create dashboard</summary>' +
            '<description>Dashboard for viewing metrics</description>' +
            '</item>' +
            '</channel>' +
            '</rss>';
        
        Test.startTest();
        List<Map<String, Object>> stories = JiraXmlParser.parseJiraXml(jiraXml);
        Test.stopTest();
        
        // Verify results
        System.assertEquals(2, stories.size(), 'Should parse 2 stories');
        
        Map<String, Object> story1 = stories[0];
        System.assertEquals('Implement user login', story1.get('title'));
        System.assertEquals('PROJ-123', story1.get('externalId'));
        System.assertEquals('As a user, I want to log in to the system', story1.get('description'));
        
        Map<String, Object> story2 = stories[1];
        System.assertEquals('Create dashboard', story2.get('title'));
        System.assertEquals('PROJ-124', story2.get('externalId'));
    }
    
    @isTest
    static void testParseJiraXmlWithCustomFields() {
        String jiraXml = '<?xml version="1.0" encoding="UTF-8"?>' +
            '<rss version="0.92">' +
            '<channel>' +
            '<item>' +
            '<key>PROJ-125</key>' +
            '<summary>Test story</summary>' +
            '<description>Test description</description>' +
            '<customfields>' +
            '<customfield id="customfield_10001" key="com.atlassian.jira.plugin.system.customfieldtypes:storypoints">' +
            '<customfieldvalues>' +
            '<customfieldvalue>8</customfieldvalue>' +
            '</customfieldvalues>' +
            '</customfield>' +
            '<customfield id="customfield_10002" key="com.atlassian.acceptance.criteria">' +
            '<customfieldvalues>' +
            '<customfieldvalue>Given user is logged in, when they click submit, then form is saved</customfieldvalue>' +
            '</customfieldvalues>' +
            '</customfield>' +
            '</customfields>' +
            '</item>' +
            '</channel>' +
            '</rss>';
        
        Test.startTest();
        List<Map<String, Object>> stories = JiraXmlParser.parseJiraXml(jiraXml);
        Test.stopTest();
        
        System.assertEquals(1, stories.size());
        Map<String, Object> story = stories[0];
        
        String notes = (String) story.get('notes');
        System.assert(notes.contains('8'), 'Notes should contain story points');
        
        String acceptanceCriteria = (String) story.get('acceptanceCriteria');
        System.assert(acceptanceCriteria.contains('Given user is logged in'), 'Should parse acceptance criteria');
    }
    
    @isTest
    static void testIsValidJiraXml() {
        String validXml = '<?xml version="1.0" encoding="UTF-8"?><rss version="0.92"><channel></channel></rss>';
        String invalidXml = '<?xml version="1.0" encoding="UTF-8"?><invalid></invalid>';
        String malformedXml = 'This is not XML';
        
        Test.startTest();
        Boolean isValid1 = JiraXmlParser.isValidJiraXml(validXml);
        Boolean isValid2 = JiraXmlParser.isValidJiraXml(invalidXml);
        Boolean isValid3 = JiraXmlParser.isValidJiraXml(malformedXml);
        Test.stopTest();
        
        System.assertEquals(true, isValid1, 'Valid Jira XML should return true');
        System.assertEquals(false, isValid2, 'Non-RSS XML should return false');
        System.assertEquals(false, isValid3, 'Malformed XML should return false');
    }
    
    @isTest
    static void testParseInvalidXml() {
        String invalidXml = 'Not valid XML content';
        
        Test.startTest();
        try {
            List<Map<String, Object>> stories = JiraXmlParser.parseJiraXml(invalidXml);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to parse'), 'Should throw parsing error');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testParseEmptyXml() {
        String emptyXml = '<?xml version="1.0" encoding="UTF-8"?><rss version="0.92"><channel></channel></rss>';
        
        Test.startTest();
        List<Map<String, Object>> stories = JiraXmlParser.parseJiraXml(emptyXml);
        Test.stopTest();
        
        System.assertEquals(0, stories.size(), 'Empty XML should return empty list');
    }
}