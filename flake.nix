{
  description = "Local-hive flake";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";

  outputs = { self, nixpkgs }:
    let
      goVersion = 23; # Change this to update the whole stack
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };
      });
    in
    {
      overlays.default = final: prev: {
        go = final."go_1_${toString goVersion}";
      };

      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            gum
            go # version is specified by overlay
            gotools
            golangci-lint
            nomad
            firecracker
            firectl
            cni-plugins
          ];
          shellHook = ''
            export NOMAD_ADDR=http://127.0.0.1:4646
            sudo mkdir -p /opt/cni/bin
            sudo cp "${pkgs.cni-plugins}"/bin/* /opt/cni/bin
          '';
        };
      });
    };
}
