# Terraform / OpenTofu Remote State Backend

## Backend Infrastructure

All Terraform stacks use a shared S3 backend with DynamoDB state locking.

| Resource | Name / ARN |
|---|---|
| **S3 Bucket** | `070066739317-terraform-state` |
| **DynamoDB Table** | `terraform-state-lock` |
| **Region** | `us-east-1` |

**Cost:** Both are effectively free when idle. S3 charges only for storage (~KB per state file). DynamoDB uses `PAY_PER_REQUEST` — charges only per read/write during active Terraform operations.

---

## Adding a New Stack

### 1. Create `backend.tf` in your stack's Terraform directory

```hcl
terraform {
  backend "s3" {
    bucket         = "070066739317-terraform-state"
    key            = "stacks/<your-stack-name>/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

Replace `<your-stack-name>` with a short identifier (e.g. `remote-dev`, `vpc-base`, `monitoring`).

### 2. Initialize

```bash
tofu init
```

### 3. Work normally

```bash
tofu plan
tofu apply
```

State is automatically stored in S3 and locked via DynamoDB during operations.

---

## State Key Structure

```
s3://070066739317-terraform-state/
└── stacks/
    ├── remote-dev/terraform.tfstate
    ├── <next-stack>/terraform.tfstate
    └── ...
```

---

## Existing Stacks

| Stack | Key | Description |
|---|---|---|
| `remote-dev` | `stacks/remote-dev/terraform.tfstate` | EC2 dev instance + NetBird + security group |

---

## Persistent Instance Protection

The `remote-dev` EC2 instance uses `lifecycle { ignore_changes = [ami, user_data] }` to prevent accidental replacement when:
- A new Ubuntu AMI is released (data source would otherwise force replacement)
- The `user-data.sh.tpl` template is modified

To intentionally replace the instance, use `tofu taint aws_instance.remote_dev` before `tofu apply`.

---

## Importing Existing Resources

If an AWS resource was created outside of Terraform (or state was lost):

```bash
tofu import aws_instance.remote_dev <instance-id>
tofu import aws_security_group.remote_dev <sg-id>
tofu import aws_vpc_security_group_egress_rule.all_outbound <sgr-id>
```

Run `tofu plan` after import to review drift between actual state and config.

---

## S3 Bucket Properties

- **Versioning**: Enabled — every state update is versioned, allowing rollback
- **Encryption**: SSE-S3 (AES-256) at rest
- **Public access**: Fully blocked
