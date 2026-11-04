# SecureBank Pro — Azure Security Architecture Lab

**A practical Azure architecture prototype covering secure application configuration, Key Vault, Managed Identity, Azure SQL, Bicep, and monitoring.**

SecureBank Pro models the foundations of a fictional banking application hosted on Azure App Service and backed by Azure SQL Database. It is a learning and portfolio lab, not a production banking service.

> **Implementation boundary:** The repository contains Bicep templates and a small Express demo API. The API does not connect to Azure SQL, implement user authentication, or process financial data. The templates are provided for review and deployment in your own Azure lab; a committed template is not proof that the corresponding resource has been deployed or tested in a live subscription.

## What is in this repository?

| Component | What it demonstrates | Current boundary |
|---|---|---|
| Azure SQL Database | Logical server and Basic database provisioning | No application database connection is implemented |
| Azure Key Vault | Stores the SQL administrator password as a secret | Lab uses access-policy authorization |
| App Service | Linux Node.js web app with system-assigned identity | Demo API only; no banking functionality |
| Managed Identity | App Service identity receives Key Vault secret `secrets/get` permission | SQL authentication via Entra ID is not implemented |
| Key Vault reference | Exposes the secret to App Service as `DB_PASSWORD` | Demo API reports whether it is configured; it never returns the value |
| Log Analytics | Central log workspace | Requires deployment and workspace validation |
| Application Insights | Workspace-based Application Insights component | Node.js telemetry instrumentation is not configured |
| Diagnostic settings | App Service HTTP logs and metrics routed to Log Analytics | No Sentinel analytics rules or incident playbooks are deployed |

## Architecture

1. Bicep provisions an Azure Key Vault and Azure SQL logical server/database.
2. The SQL administrator password is passed as a secure Bicep parameter and stored in Key Vault as a secret.
3. Bicep provisions a Linux App Service with a system-assigned managed identity.
4. The identity receives only the Key Vault `secrets/get` permission through a vault access policy.
5. An App Service application setting references the Key Vault secret. The setting is created after the access policy so the reference has permission to resolve.
6. A separate Bicep template creates Log Analytics, an Application Insights component, and App Service diagnostic settings.

The App Service demo currently does **not** connect to Azure SQL. A future phase should implement SQL connectivity using Microsoft Entra authentication and the App Service managed identity rather than using the SQL administrator credential for application access.

## Technology stack

- Microsoft Azure
- Azure Bicep
- Azure App Service (Linux)
- Azure SQL Database
- Azure Key Vault
- System-assigned Managed Identity
- Key Vault references
- Azure Monitor
- Log Analytics
- Application Insights
- Node.js 24 LTS
- Express 5
- GitHub Actions

## Repository structure

```text
SecureBank-Pro/
├── .github/
│   └── workflows/
│       └── ci.yml
├── app/
│   ├── package.json
│   ├── package-lock.json
│   ├── server.js
│   └── server.test.js
├── bicep/
│   ├── step2-secrets-and-db.bicep
│   ├── step3-app-and-identity.bicep
│   └── step4-monitoring.bicep
├── .gitignore
└── README.md
```

## Run the demo API locally

### Prerequisites

- Node.js 24 LTS
- npm

### Install, test, and start

```bash
cd app
npm ci
npm test
npm start
```

The API listens on port 3000 by default.

- `GET /` returns the service status and a Boolean indicating whether `DB_PASSWORD` is configured.
- `GET /healthz` returns a basic health response.

The API deliberately does not return or log the value of `DB_PASSWORD`.

To test the configuration indicator locally:

```bash
DB_PASSWORD='local-test-value' npm start
```

Do not use a real database password for this local test.

## Deploy the Azure infrastructure

### Prerequisites

- An Azure subscription and permission to create the resources below.
- Azure CLI installed and authenticated with `az login`.
- Bicep CLI available through Azure CLI (`az bicep install`).
- A resource group in a region that supports the selected service tiers.
- A globally unique Azure SQL server name, Key Vault name, and App Service name if you override the generated defaults.

**Cost note:** Azure SQL Database, Key Vault, Log Analytics ingestion/retention, and other services can incur charges. The App Service plan defaults to the Free F1 tier, but this does not make the entire solution free. Review the price and region availability of every resource before deploying.

### 1. Create a resource group

```bash
az group create --name SecureBankRG --location eastus
```

### 2. Deploy Key Vault and Azure SQL

Create a local deployment-parameters file named `securebank.local.parameters.json`. Keep the file out of Git. Example structure:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "adminPassword": {
      "value": "REPLACE_WITH_A_STRONG_UNIQUE_PASSWORD"
    }
  }
}
```

The parameter is declared with Bicep's `@secure()` decorator. Use a strong password that meets Azure SQL complexity requirements. Do not paste a real password into source code, a README, terminal history, or a committed parameter file.

Deploy:

```bash
az deployment group create \
  --name securebank-step2 \
  --resource-group SecureBankRG \
  --template-file ./bicep/step2-secrets-and-db.bicep \
  --parameters @securebank.local.parameters.json
```

The template outputs the generated Key Vault and SQL names:

```bash
az deployment group show \
  --name securebank-step2 \
  --resource-group SecureBankRG \
  --query properties.outputs \
  --output json
```

### 3. Deploy App Service and Managed Identity

Use the Key Vault name returned by Step 2:

```bash
az deployment group create \
  --name securebank-step3 \
  --resource-group SecureBankRG \
  --template-file ./bicep/step3-app-and-identity.bicep \
  --parameters keyVaultName=YOUR_KEY_VAULT_NAME
```

The template creates the web app identity, grants it Key Vault secret-read access, and then creates the Key Vault reference in the `DB_PASSWORD` application setting. Check the Key Vault reference resolution status in the App Service configuration after deployment.

### 4. Deploy monitoring resources

```bash
az deployment group create \
  --name securebank-step4 \
  --resource-group SecureBankRG \
  --template-file ./bicep/step4-monitoring.bicep
```

This creates the Log Analytics workspace, an Application Insights component, and an App Service diagnostic setting for HTTP logs and metrics. The template does not configure Node.js Application Insights instrumentation or Microsoft Sentinel.

## CI validation

GitHub Actions runs on pushes and pull requests targeting `main`.

The workflow:
1. Installs Node.js 24.
2. Runs `npm ci` in `app/`.
3. Runs the Node.js test suite.
4. Installs the Bicep CLI and compiles the three Bicep templates.

The tests check that the demo API returns a health response and does not expose the configured database credential in its HTTP response.

## Security considerations and known limitations

- **No real banking workflow:** there is no user login, authorization model, payment processing, or sensitive customer data.
- **No database connectivity:** the SQL server and database are provisioned by Bicep, but the Express application does not connect to them.
- **Prefer workload identity to passwords:** a future implementation should use the App Service managed identity with Microsoft Entra authentication to Azure SQL and a narrowly scoped database principal. The SQL administrator password should remain for administration only.
- **Network restrictions are incomplete:** the templates do not create a VNet, private endpoints, SQL firewall rules, or App Service VNet integration. Do not treat the SQL service as privately isolated.
- **Key Vault access model:** the Key Vault template uses vault access policies. An enterprise implementation should evaluate Azure RBAC authorization and policy governance consistently across the environment.
- **Monitoring is partial:** a Log Analytics workspace, Application Insights component, and App Service diagnostic settings are provisioned by template, but application instrumentation, alert rules, Sentinel, and incident response automation are not included.
- **Defender for Cloud is not enabled by these templates:** Defender plans are subscription-level settings and can incur additional charges. Enable them only after reviewing the current plan scope and pricing.
- **Deployment is not evidenced here:** successful Bicep compilation in CI validates template syntax, not successful Azure resource provisioning. Add deployment outputs and redacted screenshots only after testing in your own subscription.

## Next engineering improvements

1. Implement a real data access layer using App Service Managed Identity and Microsoft Entra authentication to Azure SQL.
2. Restrict SQL network access and design private connectivity before enabling application-to-database traffic.
3. Configure App Insights SDK/agent instrumentation and actionable Azure Monitor alerts.
4. Add Defender for Cloud recommendations and Sentinel detection/response only after the underlying data sources are connected.
5. Add a deployment workflow with a review/approval gate and a safe rollback strategy.
6. Add Bicep what-if checks and policy validation before deployment.

## License

No license file is currently included. All rights remain with the respective copyright holders unless a license is added. Obtain appropriate rights for any third-party assets or code before redistribution.

---

**Author:** Kelvin Arigbe  
**Repository:** [github.com/KelvinArigbe/SecureBank-Pro](https://github.com/KelvinArigbe/SecureBank-Pro)
