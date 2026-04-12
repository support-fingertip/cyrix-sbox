@isTest
private class AddressSearchControllerTest {

    @isTest
    static void testSearchAddressEmptyInput() {
        Test.startTest();
        List<AddressSearchController.AddressSuggestion> results =
            AddressSearchController.searchAddress('');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Empty input should return no suggestions');
    }

    @isTest
    static void testSearchAddressShortInput() {
        Test.startTest();
        List<AddressSearchController.AddressSuggestion> results =
            AddressSearchController.searchAddress('ab');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Short input should return no suggestions');
    }

    @isTest
    static void testSearchAddressWithMockResponse() {
        String mockBody = '{"predictions":[{"place_id":"ChIJ1","description":"123 MG Road, Kochi, Kerala, India"}],"status":"OK"}';

        Test.setMock(HttpCalloutMock.class, new AddressSearchMock(200, mockBody));

        Test.startTest();
        List<AddressSearchController.AddressSuggestion> results =
            AddressSearchController.searchAddress('123 MG Road');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 suggestion');
        System.assertEquals('ChIJ1', results[0].placeId);
        System.assert(results[0].description.contains('MG Road'));
    }

    @isTest
    static void testGetPlaceDetailsEmpty() {
        Test.startTest();
        AddressSearchController.AddressDetail detail =
            AddressSearchController.getPlaceDetails('');
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertEquals(null, detail.city);
    }

    @isTest
    static void testGetPlaceDetailsWithMockResponse() {
        String mockBody = '{"result":{"formatted_address":"123 MG Road, Kochi, Kerala 682001, India",'
            + '"address_components":['
            + '{"long_name":"123","short_name":"123","types":["street_number"]},'
            + '{"long_name":"MG Road","short_name":"MG Road","types":["route"]},'
            + '{"long_name":"Kochi","short_name":"Kochi","types":["locality"]},'
            + '{"long_name":"Kerala","short_name":"KL","types":["administrative_area_level_1"]},'
            + '{"long_name":"India","short_name":"IN","types":["country"]},'
            + '{"long_name":"682001","short_name":"682001","types":["postal_code"]}'
            + ']},"status":"OK"}';

        Test.setMock(HttpCalloutMock.class, new AddressSearchMock(200, mockBody));

        Test.startTest();
        AddressSearchController.AddressDetail detail =
            AddressSearchController.getPlaceDetails('ChIJ1');
        Test.stopTest();

        System.assertEquals('Kochi', detail.city);
        System.assertEquals('KL', detail.state);
        System.assertEquals('Kerala', detail.stateName);
        System.assertEquals('IN', detail.country);
        System.assertEquals('India', detail.countryName);
        System.assertEquals('682001', detail.postalCode);
        System.assert(detail.street.contains('MG Road'));
    }

    // Mock class for HTTP callouts
    private class AddressSearchMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        AddressSearchMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}
