public with sharing class AddressSearchController {

    @AuraEnabled(cacheable=false)
    public static List<AddressSuggestion> searchAddress(String input) {
        List<AddressSuggestion> suggestions = new List<AddressSuggestion>();
        if (String.isBlank(input) || input.length() < 3) return suggestions;

        String apiKey = Label.GOOGLE_MAPS_API_KEY;
        if (String.isBlank(apiKey)) return suggestions;

        try {
            String encodedInput = EncodingUtil.urlEncode(input, 'UTF-8');
            String endpoint = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
                + '?input=' + encodedInput
                + '&key=' + apiKey
                + '&types=address';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> predictions = (List<Object>) body.get('predictions');
                if (predictions != null) {
                    for (Object pred : predictions) {
                        Map<String, Object> p = (Map<String, Object>) pred;
                        AddressSuggestion s = new AddressSuggestion();
                        s.placeId = (String) p.get('place_id');
                        s.description = (String) p.get('description');
                        suggestions.add(s);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Address search error: ' + e.getMessage());
        }

        return suggestions;
    }

    @AuraEnabled(cacheable=false)
    public static AddressDetail getPlaceDetails(String placeId) {
        AddressDetail detail = new AddressDetail();
        if (String.isBlank(placeId)) return detail;

        String apiKey = Label.GOOGLE_MAPS_API_KEY;
        if (String.isBlank(apiKey)) return detail;

        try {
            String endpoint = 'https://maps.googleapis.com/maps/api/place/details/json'
                + '?place_id=' + placeId
                + '&fields=address_components,formatted_address'
                + '&key=' + apiKey;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> result = (Map<String, Object>) body.get('result');
                if (result != null) {
                    detail.formattedAddress = (String) result.get('formatted_address');
                    List<Object> components = (List<Object>) result.get('address_components');
                    if (components != null) {
                        detail = parseAddressComponents(components, detail);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Place details error: ' + e.getMessage());
        }

        return detail;
    }

    private static AddressDetail parseAddressComponents(List<Object> components, AddressDetail detail) {
        List<String> streetParts = new List<String>();

        for (Object comp : components) {
            Map<String, Object> c = (Map<String, Object>) comp;
            List<Object> types = (List<Object>) c.get('types');
            String longName = (String) c.get('long_name');
            String shortName = (String) c.get('short_name');

            Set<String> typeSet = new Set<String>();
            for (Object t : types) {
                typeSet.add((String) t);
            }

            if (typeSet.contains('street_number')) {
                streetParts.add(0, longName);
            } else if (typeSet.contains('route')) {
                streetParts.add(longName);
            } else if (typeSet.contains('sublocality_level_1') || typeSet.contains('sublocality')) {
                streetParts.add(longName);
            } else if (typeSet.contains('locality')) {
                detail.city = longName;
            } else if (typeSet.contains('administrative_area_level_1')) {
                detail.state = shortName;
                detail.stateName = longName;
            } else if (typeSet.contains('country')) {
                detail.country = shortName;
                detail.countryName = longName;
            } else if (typeSet.contains('postal_code')) {
                detail.postalCode = longName;
            }
        }

        if (!streetParts.isEmpty()) {
            detail.street = String.join(streetParts, ', ');
        }

        return detail;
    }

    public class AddressSuggestion {
        @AuraEnabled public String placeId;
        @AuraEnabled public String description;
    }

    public class AddressDetail {
        @AuraEnabled public String formattedAddress;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String stateName;
        @AuraEnabled public String country;
        @AuraEnabled public String countryName;
        @AuraEnabled public String postalCode;
    }
}
