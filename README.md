# Managed Platform Playground

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdanielscholl%2Fmanaged-platform%2Fmain%2Fazuredeploy.json)

## Get Owner Role Id

```bash
az role definition list --name Owner --query [].name --output tsv
```


# Links to remember

[UI Sandbox](https://portal.azure.com/?feature.customPortal=false&#blade/Microsoft_Azure_CreateUIDef/SandboxBlade)

[UI Definition Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-overview)

[Mastering the Marketplace](http://aka.ms/MasteringTheMarketplace)
