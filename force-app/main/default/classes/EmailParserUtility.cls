public class EmailParserUtility { 

 

    private static final String START_DELIM = 

        '--- CYRIX HEALTHCARE LEAD ---'; 

    private static final String END_DELIM = 

        '--- END LEAD ---'; 

 

    /** 

     * Parses structured email body into a map of 

     * field name -> value. 

     * @param emailBody - Raw email text 

     * @return Map of parsed fields or null 

     */ 

    public static Map<String, String> parseLeadEmail( 

        String emailBody 

    ) { 

        if (String.isBlank(emailBody)) return null; 

 

        // Strip HTML tags if present 

        emailBody = emailBody.stripHtmlTags(); 

 

        // Find the structured block 

        Integer startIdx = 

            emailBody.indexOf(START_DELIM); 

        Integer endIdx = 

            emailBody.indexOf(END_DELIM); 

 

        if (startIdx == -1 || endIdx == -1 || 

            endIdx <= startIdx) { 

            System.debug( 

                'WARNING: Email format not recognized'); 

            return null; 

        } 

 

        // Extract content between delimiters 

        String content = emailBody.substring( 

            startIdx + START_DELIM.length(), endIdx 

        ).trim(); 

 

        // Parse key: value pairs 

        Map<String, String> result = 

            new Map<String, String>(); 

        List<String> lines = content.split('\n'); 

 

        for (String line : lines) { 

            line = line.trim(); 

            if (String.isBlank(line)) continue; 

 

            Integer colonIdx = line.indexOf(':'); 

            if (colonIdx > 0) { 

                String key = line.substring( 

                    0, colonIdx).trim(); 

                String value = line.substring( 

                    colonIdx + 1).trim(); 

 

                if (String.isNotBlank(value) && 

                    value != 'N/A') { 

                    result.put(key, value); 

                } 

            } 

        } 

 

        System.debug('Parsed ' + result.size() + 

            ' fields from email'); 

        return result; 

    } 

 

    /** 

     * Validates required fields are present. 

     */ 

    public static Boolean validateRequiredFields( 

        Map<String, String> fields 

    ) { 

        if (fields == null) return false; 

 

        List<String> required = new List<String>{ 

            'LastName', 'Email' 

        }; 

 

        for (String field : required) { 

            if (!fields.containsKey(field) || 

                String.isBlank(fields.get(field))) { 

                System.debug( 

                    'Missing required: ' + field); 

                return false; 

            } 

        } 

        return true; 

    } 

}