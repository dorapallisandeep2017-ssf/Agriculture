import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import listOpenRequirements
    from '@salesforce/apex/AgriChainFactoryController.listOpenRequirements';
import listMyOrders
    from '@salesforce/apex/AgriChainFactoryController.listMyOrders';
import listMyWalletTransactions
    from '@salesforce/apex/AgriChainFactoryController.listMyWalletTransactions';

export default class AgriChainFactory extends LightningElement {
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
            const [requirements, orders, transactions] = await Promise.all([
                listOpenRequirements({ maxRows: 200 }),
                listMyOrders({ maxRows: 200 }),
                listMyWalletTransactions({ maxRows: 200 })
            ]);

            this.openRequirementsCount = requirements.length;
            this.activeOrdersCount = orders.filter(
                order => !['Delivered', 'Cancelled'].includes(order.Status__c)
            ).length;

            this.pendingPaymentsCount = transactions.filter(
                transaction => transaction.Status__c === 'Pending'
            ).length;

            // Response count will be connected to a dedicated Apex method next.
            this.responsesCount = 0;
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
        this.dispatchEvent(
            new CustomEvent('openobject', {
                detail: { objectApiName },
                bubbles: true,
                composed: true
            })
        );

        this.showToast(
            'Navigation',
            `Requested navigation to ${objectApiName}.`,
            'info'
        );
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
