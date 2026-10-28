public with sharing class AgriChainFactoryController {
    @AuraEnabled(cacheable=true)
    public static List<Crop_Listing__c> listCropListings(Integer maxRows) {
        Integer limitRows = (maxRows == null || maxRows < 1 || maxRows > 200) ? 50 : maxRows;
        return [SELECT Id, Name, Farmer__c, Crop_Name__c, Variety__c, Quantity_Kg__c,
                       Price_Per_Kg__c, Location__c, Harvest_Date__c, Status__c
                FROM Crop_Listing__c WHERE Status__c = 'Active'
                WITH USER_MODE ORDER BY CreatedDate DESC LIMIT :limitRows];
    }

    @AuraEnabled
    public static Id createCropListing(String cropName, String variety, Decimal quantityKg,
                                       Decimal pricePerKg, String location, Date harvestDate) {
        requirePositive(quantityKg, 'Quantity must be greater than zero.');
        requirePositive(pricePerKg, 'Price per kg must be greater than zero.');
        if (String.isBlank(cropName)) throw new AuraHandledException('Crop name is required.');
        Crop_Listing__c item = new Crop_Listing__c(
            Farmer__c = UserInfo.getUserId(),
            Crop_Name__c = cropName.trim(),
            Variety__c = variety,
            Quantity_Kg__c = quantityKg,
            Price_Per_Kg__c = pricePerKg,
            Location__c = location,
            Harvest_Date__c = harvestDate,
            Status__c = 'Active'
        );
        insert as user item;
        return item.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Farmer_Requirement__c> listOpenRequirements(Integer maxRows) {
        Integer limitRows = (maxRows == null || maxRows < 1 || maxRows > 200) ? 50 : maxRows;
        return [SELECT Id, Name, Factory__c, Crop_Name__c, Quantity_Kg__c,
                       Target_Price_Per_Kg__c, Delivery_Location__c, Required_By__c, Status__c
                FROM Farmer_Requirement__c WHERE Status__c IN ('Open','In Progress')
                WITH USER_MODE ORDER BY CreatedDate DESC LIMIT :limitRows];
    }

    @AuraEnabled
    public static Id createRequirement(String cropName, Decimal quantityKg, Decimal targetPricePerKg,
                                       String deliveryLocation, Date requiredBy) {
        requirePositive(quantityKg, 'Required quantity must be greater than zero.');
        if (String.isBlank(cropName)) throw new AuraHandledException('Crop name is required.');
        Farmer_Requirement__c req = new Farmer_Requirement__c(
            Factory__c = UserInfo.getUserId(),
            Crop_Name__c = cropName.trim(),
            Quantity_Kg__c = quantityKg,
            Target_Price_Per_Kg__c = targetPricePerKg,
            Delivery_Location__c = deliveryLocation,
            Required_By__c = requiredBy,
            Status__c = 'Open'
        );
        insert as user req;
        return req.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Farmer_Response__c> listResponses(Id requirementId) {
        if (requirementId == null) throw new AuraHandledException('Requirement is required.');
        return [SELECT Id, Name, Requirement__c, Crop_Listing__c, Farmer__c, Offered_Qty_Kg__c,
                       Offered_Price_Per_Kg__c, Message__c, Status__c, CreatedDate
                FROM Farmer_Response__c WHERE Requirement__c = :requirementId
                WITH USER_MODE ORDER BY CreatedDate DESC];
    }

    @AuraEnabled
    public static Id submitResponse(Id requirementId, Id cropListingId, Decimal offeredQtyKg,
                                    Decimal offeredPricePerKg, String message) {
        if (requirementId == null) throw new AuraHandledException('Requirement is required.');
        requirePositive(offeredQtyKg, 'Offered quantity must be greater than zero.');
        requirePositive(offeredPricePerKg, 'Offered price must be greater than zero.');
        Farmer_Requirement__c req = [SELECT Id, Status__c, Crop_Name__c, Quantity_Kg__c
                                     FROM Farmer_Requirement__c WHERE Id = :requirementId
                                     WITH USER_MODE LIMIT 1];
        if (req.Status__c != 'Open' && req.Status__c != 'In Progress')
            throw new AuraHandledException('This requirement is not accepting responses.');
        if (offeredQtyKg > req.Quantity_Kg__c)
            throw new AuraHandledException('Offered quantity cannot exceed the requirement quantity.');
        Farmer_Response__c response = new Farmer_Response__c(
            Requirement__c = requirementId,
            Crop_Listing__c = cropListingId,
            Farmer__c = UserInfo.getUserId(),
            Offered_Qty_Kg__c = offeredQtyKg,
            Offered_Price_Per_Kg__c = offeredPricePerKg,
            Message__c = message,
            Status__c = 'Pending'
        );
        insert as user response;
        return response.Id;
    }

    @AuraEnabled
    public static Id acceptResponse(Id responseId, Decimal agreedPricePerKg) {
        if (responseId == null) throw new AuraHandledException('Farmer response is required.');
        Farmer_Response__c response = [SELECT Id, Requirement__c, Crop_Listing__c, Farmer__c,
                                              Offered_Qty_Kg__c, Offered_Price_Per_Kg__c, Status__c
                                       FROM Farmer_Response__c WHERE Id = :responseId
                                       WITH USER_MODE FOR UPDATE];
        if (response.Status__c == 'Accepted')
            throw new AuraHandledException('This response has already been accepted.');
        if (response.Status__c == 'Rejected' || response.Status__c == 'Withdrawn')
            throw new AuraHandledException('This response can no longer be accepted.');
        Decimal price = agreedPricePerKg == null ? response.Offered_Price_Per_Kg__c : agreedPricePerKg;
        requirePositive(price, 'Agreed price must be greater than zero.');
        Farmer_Requirement__c req = [SELECT Id, Factory__c, Status__c FROM Farmer_Requirement__c
                                     WHERE Id = :response.Requirement__c WITH USER_MODE LIMIT 1];
        Decimal total = response.Offered_Qty_Kg__c * price;
        AgriChain_Order__c orderRec = new AgriChain_Order__c(
            Farmer_Response__c = response.Id,
            Crop_Listing__c = response.Crop_Listing__c,
            Requirement__c = req.Id,
            Farmer__c = response.Farmer__c,
            Factory__c = req.Factory__c,
            Quantity_Kg__c = response.Offered_Qty_Kg__c,
            Agreed_Price_Per_Kg__c = price,
            Total_Amount__c = total,
            Order_Date__c = Date.today(),
            Status__c = 'Confirmed'
        );
        insert as user orderRec;
        response.Status__c = 'Accepted';
        update as user response;
        req.Status__c = 'In Progress';
        update as user req;
        if (response.Crop_Listing__c != null) {
            Crop_Listing__c listing = [SELECT Id, Quantity_Kg__c, Status__c FROM Crop_Listing__c
                                       WHERE Id = :response.Crop_Listing__c WITH USER_MODE LIMIT 1];
            if (listing.Quantity_Kg__c < response.Offered_Qty_Kg__c)
                throw new AuraHandledException('The listing does not have enough available quantity.');
            listing.Status__c = listing.Quantity_Kg__c == response.Offered_Qty_Kg__c ? 'Reserved' : listing.Status__c;
            update as user listing;
        }
        return orderRec.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<AgriChain_Order__c> listMyOrders(Integer maxRows) {
        Integer limitRows = (maxRows == null || maxRows < 1 || maxRows > 200) ? 50 : maxRows;
        Id currentUser = UserInfo.getUserId();
        return [SELECT Id, Name, Farmer_Response__c, Crop_Listing__c, Requirement__c, Farmer__c,
                       Factory__c, Quantity_Kg__c, Agreed_Price_Per_Kg__c, Total_Amount__c,
                       Order_Date__c, Status__c
                FROM AgriChain_Order__c WHERE Farmer__c = :currentUser OR Factory__c = :currentUser
                WITH USER_MODE ORDER BY CreatedDate DESC LIMIT :limitRows];
    }

    @AuraEnabled
    public static Id updateDelivery(Id orderId, String status, String carrierName,
                                    String trackingNumber, Date pickupDate, Date deliveredDate, String notes) {
        if (orderId == null) throw new AuraHandledException('Order is required.');
        Set<String> allowed = new Set<String>{'Pending','Scheduled','Picked Up','In Transit','Delivered','Failed'};
        if (String.isBlank(status) || !allowed.contains(status))
            throw new AuraHandledException('Invalid delivery status.');
        List<AgriChain_Delivery__c> existing = [SELECT Id FROM AgriChain_Delivery__c
                                                WHERE Order__c = :orderId WITH USER_MODE LIMIT 1];
        AgriChain_Delivery__c deliveryRec;
        if (existing.isEmpty()) deliveryRec = new AgriChain_Delivery__c(Order__c = orderId);
        else deliveryRec = existing[0];
        deliveryRec.Status__c = status;
        deliveryRec.Carrier_Name__c = carrierName;
        deliveryRec.Tracking_Number__c = trackingNumber;
        deliveryRec.Pickup_Date__c = pickupDate;
        deliveryRec.Delivered_Date__c = deliveredDate;
        deliveryRec.Notes__c = notes;
        if (existing.isEmpty()) insert as user deliveryRec; else update as user deliveryRec;
        if (status == 'Delivered') {
            AgriChain_Order__c orderRec = [SELECT Id, Status__c FROM AgriChain_Order__c
                                           WHERE Id = :orderId WITH USER_MODE LIMIT 1];
            orderRec.Status__c = 'Delivered';
            update as user orderRec;
        }
        return deliveryRec.Id;
    }

    @AuraEnabled
    public static Id recordWalletTransaction(Id ownerId, Id orderId, Decimal amount,
                                             String type, String description, String reference) {
        requirePositive(amount, 'Transaction amount must be greater than zero.');
        Set<String> allowed = new Set<String>{'Credit','Debit','Escrow','Refund','Subsidy'};
        if (String.isBlank(type) || !allowed.contains(type))
            throw new AuraHandledException('Invalid transaction type.');
        Id actualOwner = ownerId == null ? UserInfo.getUserId() : ownerId;
        AgriChain_Wallet_Transaction__c txn = new AgriChain_Wallet_Transaction__c(
            Owner__c = actualOwner, Order__c = orderId, Amount__c = amount, Type__c = type,
            Status__c = 'Pending', Description__c = description, Reference__c = reference
        );
        insert as user txn;
        return txn.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<AgriChain_Wallet_Transaction__c> listMyWalletTransactions(Integer maxRows) {
        Integer limitRows = (maxRows == null || maxRows < 1 || maxRows > 200) ? 50 : maxRows;
        return [SELECT Id, Name, Owner__c, Order__c, Amount__c, Type__c, Status__c,
                       Reference__c, Description__c, CreatedDate
                FROM AgriChain_Wallet_Transaction__c WHERE Owner__c = :UserInfo.getUserId()
                WITH USER_MODE ORDER BY CreatedDate DESC LIMIT :limitRows];
    }

    private static void requirePositive(Decimal value, String message) {
        if (value == null || value <= 0) throw new AuraHandledException(message);
    }
}