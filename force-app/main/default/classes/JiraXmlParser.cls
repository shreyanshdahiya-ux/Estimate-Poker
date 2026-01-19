/**
 * @description Parser for Jira XML export format
 */
public with sharing class JiraXmlParser {
    
    /**
     * @description Parses Jira XML export and returns list of story data
     * @param xmlContent The XML content from Jira export
     * @return List of story data maps
     */
    public static List<Map<String, Object>> parseJiraXml(String xmlContent) {
        List<Map<String, Object>> stories = new List<Map<String, Object>>();
        
        try {
            // Parse XML
            Dom.Document doc = new Dom.Document();
            doc.load(xmlContent);
            
            Dom.XmlNode root = doc.getRootElement();
            
            // Get all item nodes (issues)
            for (Dom.XmlNode channel : root.getChildElements()) {
                if (channel.getName() == 'channel') {
                    for (Dom.XmlNode item : channel.getChildElements()) {
                        if (item.getName() == 'item') {
                            Map<String, Object> story = parseItem(item);
                            if (story != null) {
                                stories.add(story);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Failed to parse Jira XML: ' + e.getMessage());
        }
        
        return stories;
    }
    
    /**
     * @description Parses a single Jira item node
     */
    private static Map<String, Object> parseItem(Dom.XmlNode item) {
        Map<String, Object> story = new Map<String, Object>();
        
        try {
            String key = '';
            String summary = '';
            String description = '';
            String storyPoints = '';
            String acceptanceCriteria = '';
            
            for (Dom.XmlNode child : item.getChildElements()) {
                String nodeName = child.getName();
                String nodeValue = child.getText();
                
                if (nodeName == 'key') {
                    key = nodeValue;
                } else if (nodeName == 'summary') {
                    summary = nodeValue;
                } else if (nodeName == 'description') {
                    description = nodeValue != null ? nodeValue : '';
                } else if (nodeName == 'customfields') {
                    // Parse custom fields for story points and acceptance criteria
                    Map<String, String> customFields = parseCustomFields(child);
                    storyPoints = customFields.get('storyPoints');
                    acceptanceCriteria = customFields.get('acceptanceCriteria');
                }
            }
            
            // Build story data
            story.put('title', summary);
            story.put('description', description);
            story.put('externalId', key);
            story.put('acceptanceCriteria', acceptanceCriteria != null ? acceptanceCriteria : '');
            story.put('notes', storyPoints != null ? 'Original Story Points: ' + storyPoints : '');
            
        } catch (Exception e) {
            System.debug('Error parsing item: ' + e.getMessage());
            return null;
        }
        
        return story;
    }
    
    /**
     * @description Parses custom fields from Jira XML
     */
    private static Map<String, String> parseCustomFields(Dom.XmlNode customFieldsNode) {
        Map<String, String> fields = new Map<String, String>();
        
        for (Dom.XmlNode customField : customFieldsNode.getChildElements()) {
            if (customField.getName() == 'customfield') {
                String fieldId = '';
                String fieldKey = '';
                String fieldValue = '';
                
                // Get field attributes
                for (Integer i = 0; i < customField.getAttributeCount(); i++) {
                    String attrName = customField.getAttributeKeyAt(i);
                    if (attrName == 'id') {
                        fieldId = customField.getAttributeValue(attrName, null);
                    } else if (attrName == 'key') {
                        fieldKey = customField.getAttributeValue(attrName, null);
                    }
                }
                
                // Get field value
                for (Dom.XmlNode valueNode : customField.getChildElements()) {
                    if (valueNode.getName() == 'customfieldvalues') {
                        for (Dom.XmlNode cfValue : valueNode.getChildElements()) {
                            if (cfValue.getName() == 'customfieldvalue') {
                                fieldValue = cfValue.getText();
                                break;
                            }
                        }
                    }
                }
                
                // Map common Jira custom fields
                if (fieldKey != null) {
                    if (fieldKey.containsIgnoreCase('story') && fieldKey.containsIgnoreCase('point')) {
                        fields.put('storyPoints', fieldValue);
                    } else if (fieldKey.containsIgnoreCase('acceptance')) {
                        fields.put('acceptanceCriteria', fieldValue);
                    }
                }
            }
        }
        
        return fields;
    }
    
    /**
     * @description Validates Jira XML format
     */
    public static Boolean isValidJiraXml(String xmlContent) {
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlContent);
            Dom.XmlNode root = doc.getRootElement();
            
            // Check if it's an RSS feed (Jira XML export format)
            return root.getName() == 'rss';
        } catch (Exception e) {
            return false;
        }
    }
}