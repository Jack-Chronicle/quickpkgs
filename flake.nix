# ---
# --- MODULES
# --- QUICKPKGS
# ---
{
  description = "Home Manager module: npm, uv, cargo, eget, and go package installer";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    config,
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

      # Shared build environment with common toolchains
      toolEnv = pkgs.buildEnv {
        name = "dev-tools-env";
        paths = with pkgs; [
          # language toolchains
          go
          cargo
          nodePackages_latest.nodejs

          # C toolchain + build tools
          gcc
          pkg-config
          gnumake
          binutils
        ];
      };
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
          uv = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable uv package installation.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of uv packages to install.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.local/bin";
              description = "Installation prefix path for uv packages.";
            };
          };
          cargo = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable cargo package installation.";
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "List of cargo packages to install.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              default = "${config.home.homeDirectory}/.local/bin";
              description = "Installation prefix path for cargo packages.";
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
          home.packages = with pkgs; [
            uv
            eget
            toolEnv
          ];

          home.activation.installNpmPackages =
            if config.npm.enable
            then lib.hm.dag.entryAfter ["writeBoundary"] ''
              export PATH=${toolEnv}/bin:$PATH
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

          home.activation.installUvPackages =
            if config.uv.enable
            then lib.hm.dag.entryAfter ["writeBoundary"] ''
              export PATH=${pkgs.uv}/bin:$PATH
              export PATH=${toolEnv}/bin:$PATH
              if ! command -v uv >/dev/null 2>&1; then
                echo "Error: uv not found, please install uv via nixpkgs"
                exit 1
              fi

              mkdir -p ${config.uv.path}
              export UV_TOOLS_DIR=${config.uv.path}
              export PATH=${config.uv.path}:$PATH

              for pkg in ${joinQuoted config.uv.packages}; do
                if ! uv tool list | grep -q "$pkg"; then
                  echo "Installing uv tool package $pkg..."
                  uv tool install $pkg
                else
                  echo "$pkg already installed, skipping..."
                fi
              done
            ''
            else null;

          home.activation.installCargoPackages =
            if config.cargo.enable
            then lib.hm.dag.entryAfter ["writeBoundary"] ''
              export PATH=${toolEnv}/bin:$PATH
              if ! command -v cargo >/dev/null 2>&1; then
                echo "Error: cargo not found, please install cargo via nixpkgs"
                exit 1
              fi

              mkdir -p ${config.home.homeDirectory}/.local/share/cargo
              export CARGO_HOME=${config.home.homeDirectory}/.local/share/cargo
              export PATH=${config.cargo.path}:$PATH
              if [ ! -L "${config.cargo.path}" ]; then
                ln -s "${config.home.homeDirectory}/.local/share/cargo/bin/" "${config.cargo.path}"
              fi

              for pkg in ${joinQuoted config.cargo.packages}; do
                if ! cargo install --list | grep -q "$pkg"; then
                  echo "Installing cargo package $pkg..."
                  cargo install --root $CARGO_HOME $pkg >/dev/null 2>&1
                else
                  echo "$pkg already installed, skipping..."
                fi
              done
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
              export PATH=${toolEnv}/bin:$PATH

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
              # Go build environment is now guaranteed to be in PATH
              export PATH=${toolEnv}/bin:$PATH
              export CGO_ENABLED=1

              if ! command -v go >/dev/null 2>&1; then
                echo "Error: go not found in build environment"
                exit 1
              fi
              if ! command -v gcc >/dev/null 2>&1; then
                echo "Error: gcc not found in build environment"
                exit 1
              fi

              mkdir -p ${config.go.path}
              export PATH=${config.go.path}:$PATH
              export GOBIN=${config.go.path}
              export GOPATH=${config.home.homeDirectory}/.local/share/go
              mkdir -p "$GOPATH"

              for pkg in ${joinQuoted config.go.packages}; do
                binname=$(basename "$pkg")
                if [ ! -x "${config.go.path}/$binname" ]; then
                  echo "Installing Go package $binname..."
                  if ! go install "$pkg"; then
                    echo "Warning: Failed to install $pkg (may require additional C libraries)"
                  fi
                else
                  echo "$binname already exists, skipping..."
                fi
              done
            ''
            else null;

          home.sessionVariables = {
            PATH = "${config.npm.path}:${config.eget.path}:${config.uv.path}:${config.go.path}:${config.cargo.path}:$PATH";
            GOPATH = "${config.home.homeDirectory}/.local/share/go";
            GOBIN = "${config.go.path}";
            CGO_ENABLED = "1";
          };
        };
      };
    };
  };
}
