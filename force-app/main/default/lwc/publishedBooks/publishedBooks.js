import { LightningElement, track } from 'lwc';               // Core LWC base class and reactive decorator
import { subscribe, unsubscribe, onError } from 'lightning/empApi'; // EMP API for platform event streaming

// LWC component class responsible for subscribing to MostPublishedBooks__e platform events
export default class MostPublishedBooks extends LightningElement {
    channelName = '/event/MostPublishedBooks__e'; // Platform event channel name
    subscription;                                 // Holds active subscription object (if any)

    @track books = [];                            // Reactive array of book records parsed from event payload

    // Column configuration for lightning-datatable
    columns = [
        { label: 'Title', fieldName: 'Title', type: 'text', wrapText: true },
        { label: 'Author', fieldName: 'Author', type: 'text', wrapText: true },
        { label: 'Edition', fieldName: 'Edition', type: 'number', cellAttributes: { alignment: 'right' } }
    ];

    // Lifecycle hook: auto-subscribe when component is inserted
    connectedCallback() {
        this.subscribeChannel();
    }

    // Establish subscription to the platform event channel (idempotent)
    subscribeChannel() {
        if (this.subscription) {
            return; // Already subscribed
        }
        subscribe(this.channelName, -1, (event) => this.handleEvent(event))
            .then(response => {
                this.subscription = response; // Store subscription reference
            });
    }

    // Handler invoked for each incoming platform event
    handleEvent(event) {
        const payload = event?.data?.payload; // Safe navigation to payload
        if (!payload || !payload.Books__c) {
            return; // Ignore malformed or empty events
        }
        try {
            this.books = JSON.parse(payload.Books__c); // Expecting JSON array of book objects
        } catch (e) {
            // Silent parse failure logging (does not disrupt UI)
            console.log('Error parsing JSON', payload.Books__c);
        }
    }

    // Unsubscribe from the platform event stream
    handleUnsubscribe() {
        if (!this.subscription) return;
        unsubscribe(this.subscription, () => {
            this.subscription = null;
        });
    }

    // Clear displayed list (does not affect subscription)
    handleClear() {
        this.books = [];
    }

    // Computed flag to disable unsubscribe button when not subscribed
    get notSubscribed() {
        return !this.subscription;
    }
}