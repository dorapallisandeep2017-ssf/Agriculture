import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createCropListing
    from '@salesforce/apex/AgriChainFactoryController.createCropListing';
import listMyCropListings
    from '@salesforce/apex/AgriChainFactoryController.listMyCropListings';
import updateCropListing
    from '@salesforce/apex/AgriChainFactoryController.updateCropListing';
import updateCropListingStatus
    from '@salesforce/apex/AgriChainFactoryController.updateCropListingStatus';

const COLUMNS = [
    { label: 'Listing No.', fieldName: 'Name', type: 'text' },
    { label: 'Crop', fieldName: 'Crop_Name__c', type: 'text' },
    { label: 'Variety', fieldName: 'Variety__c', type: 'text' },
    { label: 'Quantity (kg)', fieldName: 'Quantity_Kg__c', type: 'number' },
    { label: 'Price/kg', fieldName: 'Price_Per_Kg__c', type: 'currency' },
    { label: 'Location', fieldName: 'Location__c', type: 'text' },
    { label: 'Harvest Date', fieldName: 'Harvest_Date__c', type: 'date' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Deactivate', name: 'deactivate' },
                { label: 'Activate', name: 'activate' }
            ]
        }
    }
];

export default class AgriCropListings extends LightningElement {
    columns = COLUMNS;
    listings = [];
    cropName = '';
    variety = '';
    quantityKg = '';
    pricePerKg = '';
    location = '';
    harvestDate = '';
    searchTerm = '';
    editingId;
    isLoading = false;
    isSaving = false;

    connectedCallback() {
        this.loadListings();
    }

    get isEditing() {
        return Boolean(this.editingId);
    }

    get formTitle() {
        return this.isEditing ? 'Edit Crop Listing' : 'Create Crop Listing';
    }

    get submitLabel() {
        return this.isEditing ? 'Save Changes' : 'Create Listing';
    }

    get hasListings() {
        return this.filteredListings.length > 0;
    }

    get filteredListings() {
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) {
            return this.listings;
        }

        return this.listings.filter(item =>
            [item.Name, item.Crop_Name__c, item.Variety__c, item.Location__c]
                .some(value => (value || '').toLowerCase().includes(term))
        );
    }

    handleInput(event) {
        this[event.target.dataset.field] = event.target.value;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    async loadListings() {
        this.isLoading = true;
        try {
            this.listings = await listMyCropListings({ maxRows: 200 });
        } catch (error) {
            this.showToast(
                'Unable to load listings',
                error?.body?.message || 'Please try again.',
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        if (!inputs.every(input => input.reportValidity())) {
            return;
        }

        const quantity = Number(this.quantityKg);
        const price = Number(this.pricePerKg);
        if (!(quantity > 0) || !(price > 0)) {
            this.showToast(
                'Invalid values',
                'Quantity and price must be greater than zero.',
                'error'
            );
            return;
        }

        this.isSaving = true;
        try {
            const values = {
                cropName: this.cropName,
                variety: this.variety,
                quantityKg: quantity,
                pricePerKg: price,
                location: this.location,
                harvestDate: this.harvestDate || null
            };

            if (this.isEditing) {
                await updateCropListing({
                    listingId: this.editingId,
                    ...values
                });
                this.showToast('Listing updated', 'Your crop listing was updated.', 'success');
            } else {
                await createCropListing(values);
                this.showToast('Listing created', 'Your crop listing was created.', 'success');
            }

            this.resetForm();
            await this.loadListings();
        } catch (error) {
            this.showToast(
                'Save failed',
                error?.body?.message || 'Unable to save crop listing.',
                'error'
            );
        } finally {
            this.isSaving = false;
        }
    }

    async handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        if (action === 'edit') {
            this.editingId = row.Id;
            this.cropName = row.Crop_Name__c || '';
            this.variety = row.Variety__c || '';
            this.quantityKg = String(row.Quantity_Kg__c ?? '');
            this.pricePerKg = String(row.Price_Per_Kg__c ?? '');
            this.location = row.Location__c || '';
            this.harvestDate = row.Harvest_Date__c || '';
            return;
        }

        const status = action === 'activate' ? 'Active' : 'Inactive';
        try {
            await updateCropListingStatus({
                listingId: row.Id,
                newStatus: status
            });
            this.showToast('Status updated', `Listing is now ${status}.`, 'success');
            await this.loadListings();
        } catch (error) {
            this.showToast(
                'Status update failed',
                error?.body?.message || 'Unable to update listing status.',
                'error'
            );
        }
    }

    handleCancelEdit() {
        this.resetForm();
    }

    resetForm() {
        this.editingId = undefined;
        this.cropName = '';
        this.variety = '';
        this.quantityKg = '';
        this.pricePerKg = '';
        this.location = '';
        this.harvestDate = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
