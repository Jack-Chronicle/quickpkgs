# ---
# --- MODULES
# --- QUICKPKGS
# ---
{
  description = "Home Manager module: npm, pipx, eget, go package installer";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  }: {
    homeModules = {
      default = {
        config,
        lib,
        pkgs,
        ...
      }: let
        joinQuoted = list: lib.concatMapStringsSep " " (pkg: ''"${pkg}"'') list;
      in {
        options = {
          npm = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable npm global package installation.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of npm global packages to install.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.local/bin";
              description = "Installation prefix path for npm global packages.";
            };
          };
          pipx = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable pipx package installation.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of pipx packages to install.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.local/bin";
              description = "Installation prefix path for pipx packages.";
            };
          };
          eget = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable eget package installation.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of packages to install using eget.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.local/bin";
              description = "Installation path for eget binaries.";
            };
          };
          go = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable Go package installation via `go install`.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of Go packages to install (e.g., \"github.com/cli/cli/cmd/gh@latest\").";
            };
            path = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.local/bin";
              description = "Installation prefix path for Go packages.";
            };
          };
        };

        config = {
          home.activation.installNpmPackages =
            if config.npm.enable
            then lib.hm.dag.entryAfter ["writeBoundary"] ''
              export PATH=${pkgs.nodePackages_latest.nodejs}/bin:$PATH
              if ! command -v npm >/dev/null 2>&1; then
                echo "Error: npm not found, please install npm via nixpkgs"
                exit 1
              fi
              export PATH=${config.npm.path}:$PATH
              mkdir -p ${config.home.homeDirectory}/.local/share/npm/bin
              if [ ! -L "${config.npm.path}" ]; then
                ln -s "${config.home.homeDirectory}/.local/share/npm/bin/" "${config.npm.path}"
              fi

              for pkg in ${joinQuoted config.npm.packages}; do
                if ! npm list -g --depth=0 | grep -q "$pkg@"; then
                  echo "Installing npm package $pkg..."
                  npm install -g $pkg
                fi
              done
            ''
            else null;

          home.activation.installPipxPackages =
            if config.pipx.enable
            then lib.hm.dag.entryAfter ["writeBoundary"] ''
              export PATH=${pkgs.pipx}/bin:$PATH
              if ! command -v pipx >/dev/null 2>&1; then
                echo "Error: pipx not found, please install pipx via nixpkgs"
                exit 1
              fi
              mkdir -p ${config.pipx.path}
              export PIPX_BIN_DIR=${config.pipx.path}
              export PATH=${config.pipx.path}:$PATH

              for pkg in ${joinQuoted config.pipx.packages}; do
                if ! pipx list --short | grep -q "$pkg"; then
                  echo "Installing pipx package $pkg..."
                  pipx install $pkg
                fi
              done

              if pipx list 2>&1 | grep -q "invalid interpreter"; then
                echo "Detected invalid interpreters, running pipx reinstall-all..."
                pipx reinstall-all
              fi
            ''
            else null;

          home.activation.installEgetPackages =
            if config.eget.enable
            then lib.hm.dag.entryAfter ["writeBoundary"] ''
              export PATH=${pkgs.eget}/bin:$PATH
              if ! command -v eget >/dev/null 2>&1; then
                echo "Error: eget not found, please install eget via nixpkgs"
                exit 1
              fi
              mkdir -p ${config.eget.path}
              export EGET_BIN=${config.eget.path}
              export PATH=${config.eget.path}:$PATH

              for pkg in ${joinQuoted config.eget.packages}; do
                binname=$(basename $pkg)
                if [ ! -x "${config.eget.path}/$binname" ]; then
                  echo "Installing eget package $pkg..."
                  eget $pkg --to=${config.eget.path}
                fi
              done
            ''
            else null;

          home.activation.installGoPackages =
            if config.go.enable
            then lib.hm.dag.entryAfter ["writeBoundary"] ''
              # Add C compiler and build tools to PATH for cgo support
              export PATH=${pkgs.gcc}/bin:${pkgs.pkg-config}/bin:$PATH
              export CGO_ENABLED=1
              
              if ! command -v go >/dev/null 2>&1; then
                echo "Error: go not found, please install go via nixpkgs"
                exit 1
              fi
              if ! command -v gcc >/dev/null 2>&1; then
                echo "Error: gcc not found, please install gcc via nixpkgs"
                exit 1
              fi
              
              mkdir -p ${config.go.path}
              export PATH=${config.go.path}:$PATH
              export GOBIN=${config.go.path}
              export GOPATH=${config.home.homeDirectory}/.go
              mkdir -p "$GOPATH"

              for pkg in ${joinQuoted config.go.packages}; do
                binname=$(basename $pkg)
                if [ ! -x "${config.go.path}/$binname" ]; then
                  echo "Installing Go package $pkg..."
                  go install $pkg
                fi
              done
            ''
            else null;

          home.sessionVariables = {
            PATH = "${config.npm.path}:${config.eget.path}:${config.pipx.path}:${config.go.path}:$PATH";
            GOPATH = "${config.home.homeDirectory}/.go";
          };

          home.packages = with pkgs; [
            pipx
            nodePackages_latest.nodejs
            eget
            go
            gcc
            pkg-config
          ];
        };
      };
    };
  };
}
