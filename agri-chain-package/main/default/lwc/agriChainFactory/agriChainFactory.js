import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import listOpenRequirements
    from '@salesforce/apex/AgriChainFactoryController.listOpenRequirements';
import listMyFactoryResponses
    from '@salesforce/apex/AgriChainFactoryController.listMyFactoryResponses';
import listMyOrders
    from '@salesforce/apex/AgriChainFactoryController.listMyOrders';
import listMyFactoryOrders
    from '@salesforce/apex/AgriChainFactoryController.listMyFactoryOrders';
import updateFactoryOrderStatus
    from '@salesforce/apex/AgriChainFactoryController.updateFactoryOrderStatus';
import listMyWalletTransactions
    from '@salesforce/apex/AgriChainFactoryController.listMyWalletTransactions';

export default class AgriChainFactory extends NavigationMixin(LightningElement) {
    openRequirementsCount = 0;
    responsesCount = 0;
    activeOrdersCount = 0;
    pendingPaymentsCount = 0;

    orders = [];
    orderColumns = [
        { label: 'Order Number', fieldName: 'Name', type: 'text' },
        { label: 'Order Date', fieldName: 'Order_Date__c', type: 'date' },
        {
            label: 'Total Amount',
            fieldName: 'Total_Amount__c',
            type: 'currency'
        },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Mark Preparing', name: 'prepare' },
                    { label: 'Cancel Order', name: 'cancel' }
                ]
            }
        }
    ];

    isLoading = false;
    errorMessage = '';

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const [
                requirements,
                responses,
                orders,
                transactions,
                factoryOrders
            ] = await Promise.all([
                listOpenRequirements({ maxRows: 200 }),
                listMyFactoryResponses({ maxRows: 200 }),
                listMyOrders({ maxRows: 200 }),
                listMyWalletTransactions({ maxRows: 200 }),
                listMyFactoryOrders({ maxRows: 200 })
            ]);

            this.orders = factoryOrders;
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

    async handleOrderAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        const statusByAction = {
            prepare: 'Preparing',
            cancel: 'Cancelled'
        };

        const status = statusByAction[action];
        if (!status) {
            return;
        }

        try {
            await updateFactoryOrderStatus({
                orderId: row.Id,
                status
            });

            this.showToast(
                'Order updated',
                `Order ${row.Name} is now ${status}.`,
                'success'
            );

            await this.loadDashboard();
        } catch (error) {
            this.showToast(
                'Order update failed',
                error?.body?.message || 'Unable to update this order.',
                'error'
            );
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
