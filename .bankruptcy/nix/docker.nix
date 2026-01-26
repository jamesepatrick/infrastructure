{ pkgs, ... }: {
  users.users."nix".extraGroups = [ "docker" ];

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  environment.systemPackages = with pkgs; [ docker-compose ];

  systemd.services.docker-autostart = {
    description = "Automatically start up docker compose images";
    after = [ "network-pre.target" "docker.service" ];
    wants = [ "network-pre.target" "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ docker-compose ];
    script = ''
      sleep 2
      cd /opt/infrastructure && docker-compose up
    '';
  };
}
