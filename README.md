# SES Email Forwarder Module

This is a terraform module that accomplishes the simple goal of configuring SES as an incoming resouce and a lambda function to forward emails to another domain. Requires that an approved SES domain is configured.

Configures the following:

- An S3 bucket to receive emails.
- An SES rule to save emails to S3 and then fire a lambda function.
- A lambda function to receive events from SES and forward emails.

## Usage

```hcl
provider "aws" {
  region  = "us-west-2"
}

module "emails" {
  source = "github.com/ColDog/ses-email-forwarder"

  # Name to prefix all resources.
  name = "test-email-forwarder"

  # SES approved domain to send from.
  from_email = "test@example.com"

  # A list of recipients to receive. This is sent to the SES rule.
  recipients = ["test@example.com"]

  # Specify a mapping to forward to:
  mapping = {
    "@example.com" = ["test@gmail.com"]
  }
}
```

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| from_email | The email address to forward from. | string | - | yes |
| mapping | Email forward mapping containing an incoming email mapped to outgoing emails | map | - | yes |
| name | Resource name | string | - | yes |
| recipients | Recipients are a list of email addresses to match | list | `<list>` | no |
| tags | Configurable tags for all AWS resources | map | `<map>` | no |

