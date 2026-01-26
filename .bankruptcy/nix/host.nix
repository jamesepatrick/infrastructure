{ config, lib, pkgs, user, ... }:
with lib;
let
  publicKey = pkgs.fetchurl {
    url = "https://github.com/jamesepatrick.keys";
    sha256 = "sha256-VGdWnlzD11L8fjoN/etmV50nHr5xrIP91BGV7x0Otks=";
  };
in {
  imports = [ ./tailscale.nix ./docker.nix ];

  users.users = {
    "nix" = {
      description = "nix";
      extraGroups = [ "wheel" "systemd-journal" ];
      isNormalUser = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keyFiles = [ publicKey ];
    };
  };

  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Quality of life basic tooling
  environment.systemPackages = with pkgs; [
    file
    fzf
    git
    git-lfs
    gnumake
    htop
    jq
    just
    killall
    ncdu
    ripgrep
    tailspin
    tmux
    unzip
    vim
    vim
    zsh
  ];

  fileSystems = {
    "/" = {
      device = "/dev/sda1";
      fsType = "ext4";
    };
    "/data" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
    };
  };

  # networking
  networking = {
    defaultGateway.interface = "eth0";
    useNetworkd = true;
    useDHCP = true;
  };

  security.sudo.wheelNeedsPassword = false;

  system.autoUpgrade.enable = true;
  systemd = {
    network.wait-online.enable = false;
    services = {
      NetworkManager-wait-online.enable = false;
      systemd-networkd.stopIfChanged = false;
      systemd-resolved.stopIfChanged = false;
    };
  };
}
