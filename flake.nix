{
  description = "Japanese word motions for Vim and Neovim on goda.vim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    goda-vim = {
      url = "github:Shougo/goda.vim/v0.9.0";
      flake = false;
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      goda-vim,
      git-hooks,
      treefmt-nix,
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

      mkFormatter =
        pkgs:
        treefmt-nix.lib.mkWrapper pkgs {
          projectRootFile = "flake.nix";
          programs = {
            gofumpt.enable = true;
            stylua.enable = true;
          };
        };

      # golangci-lint needs the Go modules, which the sandbox of a flake check
      # cannot download, so the hooks run on commit only and the checks below
      # run the same tools.
      mkHooks =
        pkgs:
        git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
          src = ./.;
          hooks = {
            treefmt = {
              enable = true;
              package = mkFormatter pkgs;
            };
            golangci-lint = {
              enable = true;
              extraPackages = [ pkgs.go_1_26 ];
            };
            selene.enable = true;
          };
        };
    in
    {
      formatter = forAllSystems mkFormatter;

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
          format = pkgs.runCommand "goda-wakachi-format" { nativeBuildInputs = [ (mkFormatter pkgs) ]; } ''
            cp -r ${./.} source
            chmod -R +w source
            cd source
            treefmt --ci --no-cache
            touch $out
          '';
          lint-go =
            (goTest "lint-go" ''
              export HOME=$TMPDIR
              golangci-lint run ./...
            '').overrideAttrs
              (old: {
                nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.golangci-lint ];
              });
          lint-lua = pkgs.runCommand "goda-wakachi-lint-lua" { nativeBuildInputs = [ pkgs.selene ]; } ''
            cd ${./.}
            selene .
            touch $out
          '';
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
          inherit (mkHooks pkgs) shellHook;
          packages = [
            (mkFormatter pkgs)
            pkgs.go_1_26
            pkgs.golangci-lint
            pkgs.selene
            pkgs.vim
            pkgs.neovim
          ];
        };
      });
    };
}
