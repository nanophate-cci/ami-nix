# circleci-image.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    # Import base AWS image configuration if needed
    # ./aws-image.nix
  ];

  # Basic system configuration
  system.stateVersion = "23.11";

  # User configuration - based on packer circleci user
  users.mutableUsers = false;
  users.groups.sudo = {};
  users.users.circleci = {
    group = "circleci";
    uid = 1001;
    isNormalUser = true;
    description = "CircleCI user";
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "sudo"
    ];
    # No password set in packer
    hashedPassword = null;
    # Set up SSH for the circleci user
    openssh.authorizedKeys.keys = [];
    shell = pkgs.bash;
    home = "/home/circleci";
  };
  
  # Create circleci group
  users.groups.circleci = {
    gid = 1001;
  };

  # Root user configuration
  users.users.root = {
    extraGroups = [
      "docker"
    ];
  };

  # SSH configuration similar to circleci-specific.sh
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      StrictHostKeyChecking = "no";
      HashKnownHosts = false;
      UseDNS = false;
      X11Forwarding = true;
      PermitTunnel = "yes";
      MaxStartups = 1000;
      MaxSessions = 1000;
      AddressFamily = "inet";
    };
  };

  # Package installations directly matching provision.sh and your NixOS snippet
  environment.systemPackages = with pkgs; [
    # Base requirements
    coreutils # sha256sum
    curl
    ethtool
    git
    git-lfs
    gzip
    jq
    p7zip
    sudo
    
    # From your NixOS snippet
    ntp
    
    # From provision.sh browsers section
    firefox
    chromium # equivalent to chrome in provision.sh
    
    # Cloud tools from provision.sh
    google-cloud-sdk # gcloud in provision.sh
    awscli2 # awscli in provision.sh
    heroku
    
    # Docker from provision.sh and your NixOS snippet
    docker
    docker-compose
    
    # Xvfb and window manager from circleci-specific.sh
    xorg.xorgserver
    xfce.xfwm4
    
    # Additional tools specified in provision.sh
    yq
    nodejs-14_x # nodejs 14.17.3 in provision.sh
    nodejs-16_x # nodejs 16.4.2 in provision.sh
    yarn
    go # golang in provision.sh
    ruby
    maven
    gradle
    ant
    python27
    python39
    scala
    clojure
    socat
    nsenter
  ];

  # Docker configuration
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  # Language environment setup
  programs.java = {
    enable = true;
    package = pkgs.jdk11;
  };

  # Node.js configuration
  programs.npm = {
    enable = true;
    package = pkgs.nodejs_14;
  };
  
  # Python configuration
  programs.python = {
    enable = true;
    package = pkgs.python39;
    enableSitePackages = true;
  };

  # Xvfb service from circleci-specific.sh
  systemd.services.xvfb = {
    description = "XVFB Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xorg.xorgserver}/bin/Xvfb :99 -screen 0 1280x1024x24";
      Type = "simple";
    };
  };

  # Environment variables from circleci-specific.sh
  environment.variables = {
    DISPLAY = ":99";
    GIT_ASKPASS = "echo";
    SSH_ASKPASS = "false";
    DBUS_SESSION_BUS_ADDRESS = "/dev/null";
    CIRCLECI_PKG_DIR = "/opt/circleci";
  };

  # Firewall rules (iptables equivalent from circleci-specific.sh)
  networking.firewall = {
    enable = true;
    extraCommands = ''
      iptables -I INPUT -m conntrack --ctstate INVALID -j DROP
    '';
  };

  # Cloud-init configuration (from your existing NixOS config)
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings.cloud_config_modules = lib.mkForce [
      "disk_setup"
      "mounts"
      "ssh-import-id"
      "set-passwords"
      "timezone"
      "runcmd"
      "ssh"
    ];
  };

  # Disable automatic updates (equivalent to the cleanup in provision.sh)
  system.autoUpgrade.enable = false;
  
  # Disable CircleCI runner services as mentioned in the existing NixOS config
  systemd.targets.circleci-runners = lib.mkForce {};
  systemd.services."circleci@" = lib.mkForce {};
  
  # Add path for circleci user's bin directory
  environment.homeBinInPath = true;
  
  # Custom shell configuration for circleci user (matching circleci-specific.sh)
  system.activationScripts.circleciUserConfig = ''
    mkdir -p /home/circleci/bin
    
    # Create .circlerc file with same contents as in circleci-specific.sh
    cat > /home/circleci/.circlerc << 'EOF'
export GIT_ASKPASS=echo
export SSH_ASKPASS=false
export PATH=~/bin:$PATH
export CIRCLECI_PKG_DIR="/opt/circleci"
export DISPLAY=:99
export DBUS_SESSION_BUS_ADDRESS=/dev/null
EOF
    
    # Create .bash_profile and .bashrc as in circleci-specific.sh
    echo 'source ~/.bashrc &>/dev/null' > /home/circleci/.bash_profile
    echo 'source ~/.circlerc &>/dev/null' > /home/circleci/.bashrc
    echo 'if ! echo $- | grep -q "i" && [ -n "$BASH_ENV" ] && [ -f "$BASH_ENV" ]; then . "$BASH_ENV"; fi' >> /home/circleci/.bashrc
    
    # Set proper ownership
    chown -R circleci:circleci /home/circleci
  '';
  
  # Create /opt/circleci directory structure (mimicking the provisioning script)
  system.activationScripts.circleciDirs = ''
    mkdir -p /opt/circleci
    mkdir -p /opt/circleci-provision-scripts
    chown -R circleci:circleci /opt/circleci
  '';
}
