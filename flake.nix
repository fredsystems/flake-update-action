{
  description = "Update flakes using GitHub actions";

  inputs = {
    systems.url = "github:nix-systems/default";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    {
      self,
      systems,
      nixpkgs,
      git-hooks,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {

      # ============================================================
      # formatter
      # ============================================================
      formatter = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pc = self.checks.${system}.pre-commit-check;
          script = ''
            ${pkgs.lib.getExe pc.config.package} run --all-files --config ${pc.config.configFile}
          '';
        in
        pkgs.writeShellScriptBin "pre-commit-run" script
      );

      # ============================================================
      # checks (flake check)
      # ============================================================
      checks = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;

            hooks = {
              nixfmt.enable = true;

              deadnix = {
                enable = true;
                entry = "${pkgs.deadnix}/bin/deadnix";
                args = [ "--fail" ];
                files = "\\.nix$";
              };

              statix = {
                enable = true;
                entry = "${pkgs.statix}/bin/statix";
                args = [ "check" ];
                files = "\\.nix$";
              };

              # Prettier FULLY enabled, including Markdown
              prettier = {
                enable = true;
                types_or = [
                  "toml"
                  "json"
                  "yaml"
                  "markdown"
                ];
              };
            };
          };
        }
      );

      # ============================================================
      # devShell
      # ============================================================
      devShells = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pc = self.checks.${system}.pre-commit-check;
        in
        {
          default = pkgs.mkShell {
            inherit (pc) shellHook;
            buildInputs = pc.enabledPackages;
          };
        }
      );
    };
}
