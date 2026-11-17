{
  description = "Japanese word motions for Vim and Neovim on goda.vim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    goda-vim = {
      url = "github:Shougo/goda.vim/v0.9.0";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      goda-vim,
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      version = "0.1.0";

      mkPackages = pkgs: rec {
        goda-wakachi = pkgs.buildGo126Module {
          pname = "goda-wakachi";
          inherit version;
          src = ./.;
          vendorHash = "sha256-o5Yg4RNN7R98kJsZ4fOY56Q020SPiEZEcKNFi1f+Kig=";
          subPackages = [ "." ];
          doCheck = false;
          postInstall = ''
            mv $out/bin/goda-wakachi.vim $out/bin/goda-wakachi
          '';
          meta.mainProgram = "goda-wakachi";
        };

        goda-vim-plugin = pkgs.vimUtils.buildVimPlugin {
          pname = "goda.vim";
          version = "0-${goda-vim.shortRev}";
          src = goda-vim;
        };

        vim-plugin = pkgs.vimUtils.buildVimPlugin {
          pname = "goda-wakachi.vim";
          inherit version;
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./LICENSE
              ./autoload
              ./doc
              ./plugin
            ];
          };
          dependencies = [ goda-vim-plugin ];
          preInstall = ''
            cp -r ${goda-wakachi}/bin .
          '';
        };

        default = vim-plugin;
      };
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          built = mkPackages pkgs;
        in
        {
          inherit (built)
            goda-wakachi
            vim-plugin
            default
            ;
          goda-vim = built.goda-vim-plugin;
        }
      );

      checks = forAllSystems (
        pkgs:
        let
          built = mkPackages pkgs;
          goTest =
            name: command:
            built.goda-wakachi.overrideAttrs {
              pname = "goda-wakachi-${name}";
              doCheck = true;
              checkPhase = ''
                runHook preCheck
                ${command}
                runHook postCheck
              '';
              installPhase = "touch $out";
              postInstall = "";
            };
        in
        {
          unit = goTest "unit" "go test ./internal/...";
          e2e = goTest "e2e" ''
            export HOME=$TMPDIR
            export PATH=${
              pkgs.lib.makeBinPath [
                pkgs.vim
                pkgs.neovim
              ]
            }:$PATH
            export GODA_WAKACHI_E2E_GODA=${goda-vim}
            export GODA_WAKACHI_E2E_STRICT=1
            go test -v -count=1 ./e2e
          '';
        }
      );

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.go_1_26
            pkgs.vim
            pkgs.neovim
          ];
        };
      });
    };
}
