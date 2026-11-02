import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import listOpenRequirements
    from '@salesforce/apex/AgriChainFactoryController.listOpenRequirements';
import listMyFactoryResponses
    from '@salesforce/apex/AgriChainFactoryController.listMyFactoryResponses';
import listMyOrders
    from '@salesforce/apex/AgriChainFactoryController.listMyOrders';
import listMyWalletTransactions
    from '@salesforce/apex/AgriChainFactoryController.listMyWalletTransactions';

export default class AgriChainFactory extends NavigationMixin(LightningElement) {
    openRequirementsCount = 0;
    responsesCount = 0;
    activeOrdersCount = 0;
    pendingPaymentsCount = 0;

    isLoading = false;
    errorMessage = '';

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const [requirements, responses, orders, transactions] =
                await Promise.all([
                    listOpenRequirements({ maxRows: 200 }),
                    listMyFactoryResponses({ maxRows: 200 }),
                    listMyOrders({ maxRows: 200 }),
                    listMyWalletTransactions({ maxRows: 200 })
                ]);

            this.openRequirementsCount = requirements.length;
            this.responsesCount = responses.length;

            this.activeOrdersCount = orders.filter(
                order => !['Delivered', 'Cancelled'].includes(order.Status__c)
            ).length;

            this.pendingPaymentsCount = transactions.filter(
                transaction => transaction.Status__c === 'Pending'
            ).length;

        } catch (error) {
            this.errorMessage =
                error?.body?.message || 'Unable to load the factory dashboard.';

            this.showToast('Dashboard error', this.errorMessage, 'error');

        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadDashboard();
    }

    handleViewRequirements() {
        this.openObjectTab('Farmer_Requirement__c');
    }

    handleViewResponses() {
        this.openObjectTab('Farmer_Response__c');
    }

    handleViewOrders() {
        this.openObjectTab('AgriChain_Order__c');
    }

    handleViewPayments() {
        this.openObjectTab('AgriChain_Wallet_Transaction__c');
    }

    openObjectTab(objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName: 'list'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
