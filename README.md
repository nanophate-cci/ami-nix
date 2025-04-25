# Converting CircleCI Packer Images to NixOS

This guide shows how to build CircleCI runner images using NixOS configurations instead of Packer.

## Files Structure

```
nixos/
├── circleci-image.nix     # CircleCI-specific configuration
├── aws-image.nix          # AWS-specific image configuration
└── flake.nix              # Flake for building images
```

## Flake Configuration

Create a `flake.nix` file with the following content:

```nix
{
  description = "CircleCI NixOS Images";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      # AWS EC2 image configuration - matches the packer amazon-ebs builder
      amazonImage = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./circleci-image.nix
          ./aws-image.nix
        ];
      };
      
      # GCE image configuration - matches the packer googlecompute builder
      googleComputeImage = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./circleci-image.nix
          # We would add a GCE image module here
          {
            networking.hostName = "circleci-gce";
          }
        ];
      };
    };
  };
}
```

## Building Images

### Build AWS AMI

To build an AWS AMI (equivalent to packer's amazon-ebs builder):

```bash
nix build .#nixosConfigurations.amazonImage.config.system.build.amazonImage
```

The resulting image will be in `./result/nix-support/ami-id` and can be directly used in AWS.

### Build GCE Image

To build a Google Compute Engine image (equivalent to packer's googlecompute builder):

```bash
nix build .#nixosConfigurations.googleComputeImage.config.system.build.googleComputeImage
```

## Creating a GCE Image Module

For the Google Compute Engine image, you'll need to create a `gce-image.nix` file similar to:

```nix
# gce-image.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/virtualisation/google-compute-image.nix>
  ];

  # Set disk size to 10GB (matching packer config)
  google.diskSize = 10;
  
  # Metadata equivalent to packer config
  google.instanceMetadata = {
    # Define metadata according to your needs
  };
}
```

## Additional Configuration

The CircleCI NixOS configuration mimics the Packer provisioning process with these key aspects:

1. **User setup**: Creates the circleci user with appropriate permissions
2. **Package installation**: Installs the packages specified in provision.sh
3. **Environment configuration**: Sets up the environment variables and paths
4. **Service configuration**: Configures services like Docker and Xvfb

## Testing

Before deployment, you can build and test locally:

```bash
# For AWS images
nix build .#nixosConfigurations.amazonImage.config.system.build.amazonImage

# Once built, you can use AWS CLI to register and launch instances using the AMI
```

## CircleCI Integration

After building and uploading your images to your cloud provider, update your CircleCI configuration to use them as runners.
