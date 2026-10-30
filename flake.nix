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
  };

  outputs = { self, nixpkgs, disko, sops-nix, hermes-agent, ... }: {
    nixosConfigurations.evo-serv1 = nixpkgs.lib.nixosSystem {
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
