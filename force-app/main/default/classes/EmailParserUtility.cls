public class EmailParserUtility {

    private static final String LEAD_START_DELIMITER = '--- CYRIX HEALTHCARE LEAD ---';
    private static final String LEAD_END_DELIMITER   = '--- END LEAD ---';

    private static final Map<String, String> FIELD_NAME_MAP = new Map<String, String>{
        'name'          => 'FirstName',
        'first name'    => 'FirstName',
        'firstname'     => 'FirstName',
        'last name'     => 'LastName',
        'lastname'      => 'LastName',
        'surname'       => 'LastName',
        'email'         => 'Email',
        'email address' => 'Email',
        'phone'         => 'Phone',
        'mobile'        => 'Phone',
        'contact'       => 'Phone',
        'company'       => 'Company',
        'organization'  => 'Company',
        'organisation'  => 'Company',
        'message'       => 'Message',
        'comments'      => 'Message',
        'comment'       => 'Message',
        'requirement'   => 'Message'
    };

    public static Map<String, String> parseLeadEmail(String body) {
        if (body == null) {
            return null;
        }

        Integer startIdx = body.indexOf(LEAD_START_DELIMITER);
        Integer endIdx   = body.indexOf(LEAD_END_DELIMITER);

        if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
            String leadSection = body.substring(
                startIdx + LEAD_START_DELIMITER.length(),
                endIdx
            ).trim();
            return parseKeyValuePairs(leadSection);
        }

        return parseFallback(body);
    }

    public static Map<String, String> parseFallback(String body) {
        if (body == null) {
            return null;
        }

        Map<String, String> result = new Map<String, String>();
        List<String> lines = body.split('\n');

        for (String line : lines) {
            line = line.trim();
            Integer colonIdx = line.indexOf(':');
            if (colonIdx > 0) {
                String rawKey = line.substring(0, colonIdx).trim().toLowerCase();
                String value  = line.substring(colonIdx + 1).trim();
                if (String.isNotBlank(value)) {
                    String mappedKey = FIELD_NAME_MAP.get(rawKey);
                    if (mappedKey != null) {
                        result.put(mappedKey, value);
                    }
                }
            }
        }

        return result.isEmpty() ? null : result;
    }

    private static Map<String, String> parseKeyValuePairs(String section) {
        if (String.isBlank(section)) {
            return null;
        }

        Map<String, String> result = new Map<String, String>();
        List<String> lines = section.split('\n');

        for (String line : lines) {
            line = line.trim();
            Integer colonIdx = line.indexOf(':');
            if (colonIdx > 0) {
                String key   = line.substring(0, colonIdx).trim();
                String value = line.substring(colonIdx + 1).trim();
                if (String.isNotBlank(key) && String.isNotBlank(value)) {
                    result.put(key, value);
                }
            }
        }

        return result.isEmpty() ? null : result;
    }

    public static String validateRequiredFields(Map<String, String> leadData) {
        List<String> required = new List<String>{ 'LastName' };
        List<String> missing  = new List<String>();

        for (String field : required) {
            if (leadData == null || !leadData.containsKey(field) || String.isBlank(leadData.get(field))) {
                missing.add(field);
            }
        }

        if (!missing.isEmpty()) {
            return 'Missing required fields: ' + String.join(missing, ', ');
        }
        return null;
    }
}