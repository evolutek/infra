{
  description = "Evolutek club servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # No follows: Hermes builds its Python set from its own nixos-unstable pin.
    hermes-agent.url = "github:NousResearch/hermes-agent";
    # The benchmark's suite; pinned on the commit its results are measured with.
    evolubot = {
      url = "github:evolutek/EvoluBot/7aa18dbbaf05703cb290aa697d301c6f361b48f8";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, hermes-agent, evolubot, ... }: {
    nixosConfigurations.evo-serv1 = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit evolubot; };
      modules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        hermes-agent.nixosModules.default
        ./hosts/evo-serv1/configuration.nix
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
      ];
    };
  };
}
