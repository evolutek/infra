{
  description = "Evolutek club servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations.evo-serv1 = nixpkgs.lib.nixosSystem {
      modules = [
        disko.nixosModules.disko
        ./hosts/evo-serv1/configuration.nix
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
      ];
    };
  };
}
