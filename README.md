# AgriChain — Salesforce Project

AgriChain is a Salesforce-based agriculture marketplace designed to connect farmers, factories, and buyers. The project supports crop listings, requirements, farmer responses, order management, and delivery tracking.

## Key Features

- **Crop Listings:** Store and manage crop details.
- **Farmer Requirements:** Track crop requirements and target prices.
- **Farmer Responses:** Record farmer offers and responses.
- **Order Management:** Maintain order details and agreed prices.
- **Delivery Tracking:** Track delivery status and shipment details.
- **Wallet Transactions:** Store transaction records.
- **Agentforce:** Includes agent definitions and specifications for factory-related guidance.

## Technology Stack

- Salesforce Platform
- Salesforce DX
- Apex
- Salesforce metadata and custom objects
- Agentforce
- Git and GitHub

## Project Structure

- `force-app/` — Salesforce metadata, Apex classes, objects, and agent definitions.
- `config/` — Salesforce project and scratch-org configuration.
- `manifest/` — Metadata package manifest.
- `specs/` — Agent specifications.
- `.vscode/` — VS Code project settings.

## Prerequisites

- Salesforce CLI (`sf`)
- Visual Studio Code
- Salesforce Extension Pack
- Access to a Salesforce org

## Development

To review the authorized Salesforce orgs:

```bash
sf org list
```

To check the current project's deployment status, use the appropriate Salesforce CLI deployment report command for your org.

## Security

Do not commit credentials, access tokens, private keys, or local authentication files to GitHub.

## Project Status

The Salesforce metadata has been deployed successfully to a development org. Apex tests were not run as part of the reported deployment.

## Disclaimer

This project is under development. Features and metadata may change as implementation continues.
