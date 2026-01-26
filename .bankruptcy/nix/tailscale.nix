{ pkgs, ... }: {
  services.tailscale.enable = true;
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ jq tailscale ];
    script = ''
      sleep 2
      status="$(tailscale status -json | jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi
      tailscale up --authkey $(cat /etc/tailscale/authkey)
    '';
  };
}
