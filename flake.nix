{
  description = "Japanese word motions for Vim and Neovim on goda.vim";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    goda-nix = {
      url = "github:airRnot1106/goda.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      flake-utils,
      git-hooks,
      goda-nix,
      nixpkgs,
      treefmt-nix,
    }:
    flake-utils.lib.eachSystem
      [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ]
      (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          version = "0.1.0";

          plugin = goda-nix.lib.buildGodaPlugin pkgs {
            inherit version;
            src = ./.;
            vendorHash = "sha256-SMDqfYvHqjQ7j0cnx30WTxgCd4UrE1dEo0sJRTFK71g=";
          };

          # Only goda.vim and this plugin are loaded, with the motions on the
          # native keys.
          vimrc = pkgs.writeText "goda-wakachi-vimrc" ''
            set nocompatible encoding=utf-8
            set runtimepath^=${plugin},${plugin.godaVim}
            for s:key in ['w', 'b', 'e', 'ge']
              for s:map in ['nmap', 'xmap', 'omap']
                execute s:map s:key '<Plug>(goda-wakachi-' . s:key . ')'
              endfor
            endfor
          '';

          mkEditor =
            editor: package:
            pkgs.writeShellApplication {
              name = "goda-wakachi-${editor}";
              runtimeInputs = [ package ];
              text = ''
                exec ${editor} -u ${vimrc} -i NONE "$@"
              '';
            };

          formatter = treefmt-nix.lib.mkWrapper pkgs {
            projectRootFile = "flake.nix";
            programs = {
              gofumpt.enable = true;
              nixfmt.enable = true;
              stylua.enable = true;
            };
          };

          # golangci-lint needs the Go modules, which the sandbox of a flake check
          # cannot download, so the hooks run on commit only and the checks below
          # run the same tools.
          hooks = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              golangci-lint = {
                enable = true;
                extraPackages = [ plugin.binary.go ];
              };
              selene.enable = true;
              treefmt = {
                enable = true;
                package = formatter;
              };
            };
          };

          goTest =
            name: nativeBuildInputs: command:
            plugin.binary.overrideAttrs (prev: {
              name = "goda-wakachi-${name}";
              doCheck = true;
              nativeBuildInputs = prev.nativeBuildInputs ++ nativeBuildInputs;
              checkPhase = ''
                runHook preCheck
                export HOME=$TMPDIR
                ${command}
                runHook postCheck
              '';
              installPhase = "touch $out";
            });
        in
        {
          inherit formatter;

          apps = rec {
            default = nvim;
            nvim = flake-utils.lib.mkApp { drv = mkEditor "nvim" pkgs.neovim; };
            vim = flake-utils.lib.mkApp { drv = mkEditor "vim" pkgs.vim; };
          };

          packages = {
            default = plugin;
            goda-vim = plugin.godaVim;
            goda-wakachi = plugin.binary;
            vim-plugin = plugin;
          };

          checks = {
            e2e = goTest "e2e" [
              pkgs.neovim
              pkgs.vim
            ] "GODA_WAKACHI_E2E_STRICT=1 go test -v -count=1 ./e2e";
            format = pkgs.runCommand "goda-wakachi-format" { nativeBuildInputs = [ formatter ]; } ''
              cp -r ${./.} source
              chmod -R +w source
              cd source
              treefmt --ci --no-cache
              touch $out
            '';
            lint-go = goTest "lint-go" [ pkgs.golangci-lint ] "golangci-lint run ./...";
            lint-lua = pkgs.runCommand "goda-wakachi-lint-lua" { nativeBuildInputs = [ pkgs.selene ]; } ''
              cd ${./.}
              selene .
              touch $out
            '';
            unit = goTest "unit" [ ] "go test ./internal/...";
          };

          devShells.default = pkgs.mkShell {
            inherit (hooks) shellHook;
            packages = [
              formatter
              plugin.binary.go
              pkgs.golangci-lint
              pkgs.neovim
              pkgs.selene
              pkgs.vim
            ];
          };
        }
      );
}
