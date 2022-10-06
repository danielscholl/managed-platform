# Managed Platform Playground

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdanielscholl%2Fmanaged-platform%2Fmain%2Fazuredeploy.json)


## Background

This project is a playground to look into the feasibility of a managed platform for Azure. The goal is to provide a platform that can be used to deploy and manage kuberenetes applications into Azure. A platform should be thought of as a building block that other teams can leverage to either build applications in or build on top of.  An example of building on top of a platform would be the delivery mechanism of the platform. The goal of the playground is to investigate building a Managed Application using the IaC from the platform.

Currently the Azure Managed App is built into this platform but the expectation is that it be seperated into a seperate repository.

This project attempts to leverage guidance from the following sources:

- [AKS Secure Baseline](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks/secure-baseline-aks)
- [Well Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
- [Cloud Adoption Framework](https://azure.microsoft.com/cloud-adoption-framework/)
- [Enterprise-Scale](https://github.com/Azure/Enterprise-Scale) 


Further information on this project can be found in the [docs](docs/setup.md) folder.

## Project Principals

The guiding principal we have with this project is to focus on the the *downstream use* of the project (see [releases](https://github.com/danielscholl/managed-platform/releases))  The goal is to work on infrastructure and a managed platform in a manner that other components can consume the platform or infrastructure deployment. As such, these are our specific practices.

1. Deploy all components through a single, modular, idempotent bicep template Converge on a single bicep template, which can easily be consumed as a module
2. Provide best-practice defaults, then use parameters for flagging on additional options.
3. Minimise "manual" steps for ease of automation
4. Maintain quality through validation & CI/CD pipelines that also serve as working samples/docs
5. Allow for platfrom deployment via Service Definition files.

## Contributing

If you're interested in contributing, we have two contribution guides in the repo which you should read first.

Guide | Description
----- | -----------
[Generic Contribution Guide](CONTRIBUTING.md) | Talks about the branching strategy, using CodeSpaces and general guidance


## Helpful Links on working with Azure Managed Applications

- [UI Sandbox](https://portal.azure.com/?feature.customPortal=false&#blade/Microsoft_Azure_CreateUIDef/SandboxBlade)
- [UI Definition Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/managed-applications/create-uidefinition-overview)
- [Mastering the Marketplace](http://aka.ms/MasteringTheMarketplace)
- [Blog Part 1](https://arsenvlad.medium.com/simple-azure-managed-application-creating-testing-and-publishing-in-partner-center-d2cb3b98bed2)
- [Blog Part 2](https://arsenvlad.medium.com/azure-managed-application-with-aks-and-deployment-time-or-cross-tenant-role-assignments-to-vm-and-3ebce7d607c2)
