{
  description = "Digital Exchange Daiary (backend)";

  outputs = inputs @ {
    nixpkgs,
    systems,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      imports = with inputs; [
        treefmt-nix.flakeModule
        flake-root.flakeModule
        process-compose-flake.flakeModule
      ];
      perSystem = {
        config,
        system,
        pkgs,
        ...
      }: {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (
              self: super:
                with super; {
                  elixir = beam.packages.erlang_28.elixir_1_19;
                  erlang = beam.packages.erlang_28.erlang;
                }
            )
          ];
        };
        devShells.default = pkgs.mkShell {
          inputsFrom = with config; [
            flake-root.devShell
            treefmt.build.devShell
            process-compose."db".services.outputs.devShell
          ];
          packages = with pkgs; [
            elixir
            erlang
            inotify-tools
            process-compose
          ];
          shellHook = ''
            export DATABASE_URL="postgresql:///postgres?host=$PWD/data/postgres&port=5432&user=postgres"
          '';
        };
        treefmt = {
          programs = {
            alejandra.enable = true;
            mdformat.enable = true;
            mix-format.enable = true;
          };
        };
        process-compose."db" = {
          imports = [inputs.services-flake.processComposeModules.default];
          services.postgres."postgres" = {
            enable = true;
            superuser = "postgres";
            initialScript.before = ''
              CREATE ROLE postgres;
            '';
            initialDatabases = [{name = "postgres";}];
            listen_addresses = "*";
            socketDir = "data/postgres";
          };
        };
      };
    };

  inputs = {
    # Common
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";

    # Flake Modules
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-root.url = "github:srid/flake-root";
    process-compose-flake.url = "github:platonic-systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
}
