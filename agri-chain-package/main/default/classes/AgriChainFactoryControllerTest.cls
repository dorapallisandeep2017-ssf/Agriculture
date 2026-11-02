@IsTest
private class AgriChainFactoryControllerTest {

    private static String testUsername() {
        return 'agrichain-test-' + UserInfo.getOrganizationId() + '@example.test';
    }

    @TestSetup
    static void createTestUserWithPermissions() {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User testUser = new User(
            FirstName = 'AgriChain',
            LastName = 'TestUser',
            Alias = 'agritest',
            Email = testUsername(),
            Username = testUsername(),
            CommunityNickname = 'agri' + UserInfo.getOrganizationId().substring(0, 8),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id
        );
        insert testUser;

        PermissionSet appPermissions = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'AgriChain_User_Perms'
            LIMIT 1
        ];

        insert new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = appPermissions.Id
        );
    }

    private static User getTestUser() {
        return [
            SELECT Id
            FROM User
            WHERE Username = :testUsername()
            LIMIT 1
        ];
    }

    @IsTest
    static void listingRequirementResponseAndOrderFlow() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Crop_Listing__c listing = new Crop_Listing__c(
                Farmer__c = testUser.Id,
                Crop_Name__c = 'Rice',
                Quantity_Kg__c = 500,
                Price_Per_Kg__c = 30,
                Location__c = 'Hyderabad',
                Status__c = 'Active'
            );
            insert listing;

            Farmer_Requirement__c req = new Farmer_Requirement__c(
                Factory__c = testUser.Id,
                Crop_Name__c = 'Rice',
                Quantity_Kg__c = 200,
                Target_Price_Per_Kg__c = 29,
                Delivery_Location__c = 'Hyderabad',
                Status__c = 'Open'
            );
            insert req;

            Test.startTest();
            Id responseId = AgriChainFactoryController.submitResponse(
                req.Id, listing.Id, 100, 28, 'Fresh harvest'
            );
            Id orderId = AgriChainFactoryController.acceptResponse(responseId, 27);
            Test.stopTest();

            List<AgriChain_Order__c> orders = [
                SELECT Id, Total_Amount__c, Agreed_Price_Per_Kg__c
                FROM AgriChain_Order__c
                WHERE Id = :orderId
            ];

            System.assertEquals(1, orders.size());
            System.assertEquals(2700, orders[0].Total_Amount__c);
            System.assertEquals(27, orders[0].Agreed_Price_Per_Kg__c);

            Farmer_Response__c savedResponse = [
                SELECT Status__c
                FROM Farmer_Response__c
                WHERE Id = :responseId
            ];
            System.assertEquals('Accepted', savedResponse.Status__c);
        }
    }

    @IsTest
    static void createsListingAndRequirement() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();

            Id listingId = AgriChainFactoryController.createCropListing(
                'Maize', 'Hybrid', 250, 22, 'Warangal', Date.today()
            );

            Id reqId = AgriChainFactoryController.createRequirement(
                'Maize', 100, 21, 'Warangal', Date.today().addDays(5)
            );

            Test.stopTest();

            System.assertNotEquals(null, listingId);
            System.assertNotEquals(null, reqId);
            System.assertEquals(
                1,
                [SELECT count() FROM Crop_Listing__c WHERE Id = :listingId]
            );
            System.assertEquals(
                1,
                [SELECT count() FROM Farmer_Requirement__c WHERE Id = :reqId]
            );
        }
    }
}
