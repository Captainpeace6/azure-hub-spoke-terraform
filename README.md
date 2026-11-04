# azure-hub-spoke-terraform

[![terraform-ci](https://github.com/Captainpeace6/azure-hub-spoke-terraform/actions/workflows/ci.yml/badge.svg)](https://github.com/Captainpeace6/azure-hub-spoke-terraform/actions/workflows/ci.yml)

Azure hub-and-spoke network in Terraform. One hub VNet holds a shared Azure Firewall; `dev` and `prod` spokes peer only with the hub and send all egress through the firewall. Ships with an Azure DevOps pipeline that applies the exact plan a reviewer approved.

## Architecture

```mermaid
flowchart TB
  NET((Internet))
  subgraph HUB[Hub VNet 10.0.0.0/22]
    AFW[Azure Firewall<br/>threat intel: deny]
    POL[Child policy<br/>inherits baseline policy]
    LAW[(Log Analytics)]
    AFW --- POL
    AFW -. all logs .-> LAW
  end
  subgraph DEV[Spoke: dev 10.1.0.0/16]
    DA[snet-app] --> DD[snet-data]
  end
  subgraph PROD[Spoke: prod 10.2.0.0/16]
    PA[snet-app] --> PD[snet-data]
  end
  DEV <-- peering --> HUB
  PROD <-- peering --> HUB
  DEV -. 0.0.0.0/0 via firewall .-> AFW
  PROD -. 0.0.0.0/0 via firewall .-> AFW
  AFW --> NET
  DEV x--x PROD
```

## How dev and prod stay apart

1. **Peering isn't transitive.** Each spoke peers only with the hub, so dev has no direct route to prod.
2. **Every spoke route goes to the firewall.** A user-defined route sends `0.0.0.0/0` to the firewall's private IP, with BGP propagation off so nothing can override it.
3. **The firewall denies by default.** Traffic between spokes passes only if a rule allows it, and none does.
4. **NSGs on every subnet.** Explicit allows (HTTPS from the corporate range to `app`, Postgres from `app` to `data`), then deny-all inbound.

## Firewall policy hierarchy

| Policy | Owns | Who changes it |
|---|---|---|
| `baseline` (parent) | Threat intel in deny mode, DNS proxy, org-wide allows (OS updates, Azure Monitor) | Platform team |
| `hub` (child, attached to the firewall) | Inherits baseline, plus one rule collection group per spoke | Each spoke's team, on its own group |

Dev may pull from npm, PyPI and GHCR. Prod may reach only GHCR.

## Pipelines

- **GitHub Actions (`.github/workflows/ci.yml`):** `terraform fmt`, `validate`, TFLint and Checkov on every push and PR.
- **Azure DevOps (`pipelines/azure-pipelines.yml`):** Validate, then Plan, then Apply.
  - Authenticates with **Workload Identity Federation**, so the pipeline stores no client secret.
  - Plan publishes the binary `tfplan` as an artifact, and Apply runs *that file* after approval on the `hub-spoke-prod` environment. A fresh plan at apply time could include changes nobody reviewed.

## Trade-offs

- **Firewall Standard, not Premium.** Premium adds IDPS and TLS inspection for roughly 3× the cost. The Checkov skip for IDPS says so in the code.
- **One shared firewall.** It's cheaper and gives one place to audit egress. A team with strict blast-radius rules could run a hub per environment instead; the spoke module wouldn't change.

## Usage

```bash
cd live
az login
export ARM_SUBSCRIPTION_ID=<subscription-id>
terraform init -backend-config=backend.hcl   # resource_group_name, storage_account_name, container_name, key
terraform plan
```

> **Cost:** Azure Firewall Standard runs about $900/month plus data processing, before anything else. Run `terraform destroy` after trying it.
