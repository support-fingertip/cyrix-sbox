public class EmailParserUtility {

    private static final String LEAD_START_DELIMITER = '--- CYRIX HEALTHCARE LEAD ---';
    private static final String LEAD_END_DELIMITER   = '--- END LEAD ---';

    private static final Map<String, String> FIELD_NAME_MAP = new Map<String, String>{
        'name'               => 'FirstName',
        'first name'         => 'FirstName',
        'firstname'          => 'FirstName',
        'last name'          => 'LastName',
        'lastname'           => 'LastName',
        'surname'            => 'LastName',
        'sender name'        => 'LastName',
        'email'              => 'Email',
        'email address'      => 'Email',
        'phone'              => 'Phone',
        'mobile'             => 'Phone',
        'contact'            => 'Phone',
        'company'            => 'Company',
        'organization'       => 'Company',
        'organisation'       => 'Company',
        'company name'       => 'Company',
        'message'            => 'Message',
        'comments'           => 'Message',
        'comment'            => 'Message',
        'requirement'        => 'Message',
        'product details'    => 'Message',
        'requirement details'=> 'Message'
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

        if (body.containsIgnoreCase('tradeindia') || body.contains('Buyer Details')) {
            Map<String, String> tiResult = parseTradeIndiaEmail(body);
            if (tiResult != null) {
                return tiResult;
            }
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

    public static Map<String, String> parseTradeIndiaEmail(String body) {
        if (body == null) {
            return null;
        }

        Map<String, String> result = new Map<String, String>();
        List<String> lines = body.split('\n');

        for (String line : lines) {
            line = line.trim();
            // Strip leading bullet marker
            if (line.startsWith('*')) {
                line = line.substring(1).trim();
            }

            String rawKey = null;
            String value = null;

            // Try colon separator first
            Integer colonIdx = line.indexOf(':');
            if (colonIdx > 0) {
                rawKey = line.substring(0, colonIdx).trim().toLowerCase();
                value  = line.substring(colonIdx + 1).trim();
            } else {
                // Try dash separator
                Integer dashIdx = line.indexOf(' - ');
                if (dashIdx > 0) {
                    rawKey = line.substring(0, dashIdx).trim().toLowerCase();
                    value  = line.substring(dashIdx + 3).trim();
                }
            }

            if (String.isBlank(rawKey) || String.isBlank(value)) {
                continue;
            }

            // Skip noreply email values
            if (rawKey == 'email' && value.containsIgnoreCase('noreply')) {
                continue;
            }

            String mappedKey = FIELD_NAME_MAP.get(rawKey);
            if (mappedKey != null && !result.containsKey(mappedKey)) {
                result.put(mappedKey, value);
            }
        }

        // Extract Mobile via regex if not already found
        if (!result.containsKey('Phone')) {
            String phone = extractPattern(body, 'Mobile:\\s*([+\\d]+)');
            if (phone == null) {
                phone = extractPattern(body, 'Mobile -\\s*([+\\d]+)');
            }
            if (phone != null) {
                result.put('Phone', phone);
            }
        }

        // Extract Company Name via regex if not already found
        if (!result.containsKey('Company')) {
            String company = extractPattern(body, 'Company Name:\\s*([^\\n]+)');
            if (company == null) {
                company = extractPattern(body, 'Company Name -\\s*([^\\n]+)');
            }
            if (company != null) {
                result.put('Company', company.trim());
            }
        }

        return result.isEmpty() ? null : result;
    }

    private static String extractPattern(String text, String regex) {
        Pattern p = Pattern.compile(regex);
        Matcher m = p.matcher(text);
        if (m.find()) {
            return m.group(1);
        }
        return null;
    }

    public static String validateRequiredFields(Map<String, String> leadData) {
        if (leadData == null || !leadData.containsKey('LastName') || String.isBlank(leadData.get('LastName'))) {
            return 'Missing required fields: LastName';
        }
        Boolean hasEmail = leadData.containsKey('Email') && String.isNotBlank(leadData.get('Email'));
        Boolean hasPhone = leadData.containsKey('Phone') && String.isNotBlank(leadData.get('Phone'));
        if (!hasEmail && !hasPhone) {
            return 'Missing required fields: Email or Phone';
        }
        return null;
    }
}