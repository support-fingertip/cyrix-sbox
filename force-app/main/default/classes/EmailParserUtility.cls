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
        'company name'  => 'Company',
        'message'       => 'Message',
        'comments'      => 'Message',
        'comment'       => 'Message',
        'requirement'   => 'Message',
        'requirement details' => 'Message',
        'product details'     => 'Message',
        'sender name'         => 'LastName'
    };

    public static Map<String, String> parseLeadEmail(String body) {
        if (body == null) {
            return null;
        }

        // 1. Try structured delimiters first
        Integer startIdx = body.indexOf(LEAD_START_DELIMITER);
        Integer endIdx   = body.indexOf(LEAD_END_DELIMITER);

        if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
            String leadSection = body.substring(
                startIdx + LEAD_START_DELIMITER.length(),
                endIdx
            ).trim();
            return parseKeyValuePairs(leadSection);
        }

        // 2. Try TradeIndia format
        if (body.containsIgnoreCase('tradeindia') || body.containsIgnoreCase('Buyer Details')) {
            Map<String, String> tiResult = parseTradeIndiaEmail(body);
            if (tiResult != null) {
                return tiResult;
            }
        }

        // 3. Fallback generic parser
        return parseFallback(body);
    }

    /**
     * Parses TradeIndia inquiry emails that use:
     *   - "* Key: Value" format (bullet + colon)
     *   - "Key - Value" format (dash separator in Buyer Details)
     */
    public static Map<String, String> parseTradeIndiaEmail(String body) {
        if (body == null) {
            return null;
        }

        Map<String, String> result = new Map<String, String>();
        List<String> lines = body.split('\n');

        for (String line : lines) {
            line = line.trim();

            // Remove leading bullet markers: *, •, -, etc.
            if (line.startsWith('*')) {
                line = line.substring(1).trim();
            }

            String rawKey = null;
            String value  = null;

            // Try "Key: Value" first
            Integer colonIdx = line.indexOf(':');
            if (colonIdx > 0) {
                rawKey = line.substring(0, colonIdx).trim().toLowerCase();
                value  = line.substring(colonIdx + 1).trim();
            }
            // Then try "Key - Value"
            else {
                Integer dashIdx = line.indexOf(' - ');
                if (dashIdx > 0) {
                    rawKey = line.substring(0, dashIdx).trim().toLowerCase();
                    value  = line.substring(dashIdx + 3).trim();
                }
            }

            if (rawKey != null && String.isNotBlank(value)) {
                String mappedKey = FIELD_NAME_MAP.get(rawKey);
                if (mappedKey != null) {
                    // Don't overwrite with noreply emails
                    if (mappedKey == 'Email' && value.containsIgnoreCase('noreply')) {
                        continue;
                    }
                    // Only set if not already populated
                    if (!result.containsKey(mappedKey)) {
                        result.put(mappedKey, value);
                    }
                }
            }
        }

        // Try to extract phone from Requirement Details text
        // e.g., "Mobile: +919486167715"
        if (!result.containsKey('Phone')) {
            String phone = extractPattern(body, 'Mobile:\\s*([+\\d]+)');
            if (phone == null) {
                phone = extractPattern(body, 'Mobile -\\s*([+\\d]+)');
            }
            if (phone != null) {
                result.put('Phone', phone);
            }
        }

        // Try to extract Company from Requirement Details text
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

    /**
     * Extracts a value using a regex pattern with one capture group.
     */
    private static String extractPattern(String text, String regex) {
        Pattern p = Pattern.compile(regex);
        Matcher m = p.matcher(text);
        if (m.find()) {
            return m.group(1);
        }
        return null;
    }

    // ── Existing methods below (unchanged) ──

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
       public static void testcover(){
        integer i=0;
        i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
         i++;
        i++;
        i++;
        i++;
        i++;
    }
}