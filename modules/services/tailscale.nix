{
  # The node joins the club tailnet once, by `sudo tailscale up` and a login URL; its state then lives in /var/lib/tailscale.
  services.tailscale = {
    enable = true;
    # Lets peers reach it over direct WireGuard instead of the DERP relays when the network allows it.
    openFirewall = true;
  };

  # Keeps tailscaled from asking the school's router to open ports; STUN and DERP still connect peers.
  systemd.services.tailscaled.environment.TS_DISABLE_PORTMAPPER = "1";
}
