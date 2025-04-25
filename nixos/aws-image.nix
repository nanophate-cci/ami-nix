# aws-image.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/virtualisation/amazon-image.nix>
  ];

  # AMI-specific configuration
  ec2.hvm = true;
  ec2.efi = false;

  # Set root device size to 10GB (exactly matching packer config)
  ec2.blockDeviceMapping = {
    "/dev/sda1" = {
      size = 10240;  # 10GB in MB
      volumeType = "gp2";
      deleteOnTermination = true;
    };
  };

  # AMI name pattern from the packer config
  ec2.ami.name = "ubuntu-2004-vm-circleci-classic-nixos-${config.system.nixos.label}";
  
  # Set AMI description similar to packer config
  ec2.ami.description = "NixOS CircleCI runner image based on original packer config";

  # Configure cloud-init user data from packer
  services.cloud-init = {
    enable = true;
    network.enable = true;
    
    # User data matching the packer config
    extraConfig = ''
      #cloud-config
      system_info:
        default_user:
          name: circleci
    '';
  };

  # Configure network for AWS
  networking = {
    hostName = "circleci-nixos";
    useDHCP = true;
  };

  # To allow connecting by SSH as in the original packer config
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };
}
