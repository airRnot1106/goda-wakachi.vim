{
  description = "Japanese word motions for Vim and Neovim on goda.vim";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    goda-vim = {
      url = "github:Shougo/goda.vim/v0.9.0";
      flake = false;
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
      goda-vim,
      nixpkgs,
      treefmt-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "0.1.0";

        goda-wakachi = pkgs.buildGo126Module {
          pname = "goda-wakachi";
          inherit version;
          src = ./.;
          vendorHash = "sha256-3G6hwSgzzBxkyjR4NWlGtsgjfpLSl5hi5PKv65/aBLA=";
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

        # Only goda.vim and this plugin are loaded, with the motions on the
        # native keys.
        vimrc = pkgs.writeText "goda-wakachi-vimrc" ''
          set nocompatible encoding=utf-8
          set runtimepath^=${vim-plugin},${goda-vim-plugin}
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
              extraPackages = [ pkgs.go_1_26 ];
            };
            selene.enable = true;
            treefmt = {
              enable = true;
              package = formatter;
            };
          };
        };

        goTest =
          name: command:
          goda-wakachi.overrideAttrs {
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
        inherit formatter;

        apps = rec {
          default = nvim;
          nvim = flake-utils.lib.mkApp { drv = mkEditor "nvim" pkgs.neovim; };
          vim = flake-utils.lib.mkApp { drv = mkEditor "vim" pkgs.vim; };
        };

        packages = {
          default = vim-plugin;
          goda-vim = goda-vim-plugin;
          inherit goda-wakachi vim-plugin;
        };

        checks = {
          e2e = goTest "e2e" ''
            export HOME=$TMPDIR
            export PATH=${
              pkgs.lib.makeBinPath [
                pkgs.neovim
                pkgs.vim
              ]
            }:$PATH
            export GODA_WAKACHI_E2E_GODA=${goda-vim}
            export GODA_WAKACHI_E2E_STRICT=1
            go test -v -count=1 ./e2e
          '';
          format = pkgs.runCommand "goda-wakachi-format" { nativeBuildInputs = [ formatter ]; } ''
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
          unit = goTest "unit" "go test ./internal/...";
        };

        devShells.default = pkgs.mkShell {
          inherit (hooks) shellHook;
          packages = [
            formatter
            pkgs.go_1_26
            pkgs.golangci-lint
            pkgs.neovim
            pkgs.selene
            pkgs.vim
          ];
        };
      }
    );
}
