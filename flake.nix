# ---
# --- MODULES
# --- QUICKPKGS
# ---
{
  description = "Home Manager module: npm, pipx, eget package installer";

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
        };

        config = {
          home.activation.installNpmPackages =
            if config.npm.enable
            then
              lib.hm.dag.entryAfter ["writeBoundary"] ''
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

                # Search nixpkgs for npm package alternatives
                # echo "Searching nixpkgs for npm package alternatives..."
                # matches_found=false
                # for pkg in ${joinQuoted config.npm.packages}; do
                #   clean_pkg=$(echo "$pkg" | sed 's/^[[:space:][:punct:]]*//; s/[[:space:][:punct:]]*$//; s/[[:punct:]]/ /g')
                #   nix_matches=""
                #   if command -v nix >/dev/null 2>&1; then
                #     nix_matches=$(nix search nixpkgs "$clean_pkg" 2>/dev/null | grep -v '^$' | head -5)
                #   fi
                #   if [ -n "$nix_matches" ]; then
                #     matches_found=true
                #     echo "possible Nixpkg matches found for '$pkg':"
                #     echo "$nix_matches"
                #   fi
                # done
                # if [ "$matches_found" = false ]; then
                #   echo "No nixpkgs matches found for npm packages."
                # fi
                # echo

                for pkg in ${joinQuoted config.npm.packages}; do
                  if ! npm list -g --depth=0 | grep -q "$pkg@"; then
                    echo "Installing npm package $pkg globally..."
                    npm install -g $pkg
                  fi
                done
              ''
            else null;

          home.activation.installPipxPackages =
            if config.pipx.enable
            then
              lib.hm.dag.entryAfter ["writeBoundary"] ''
                export PATH=${pkgs.pipx}/bin:$PATH
                if ! command -v pipx >/dev/null 2>&1; then
                  echo "Error: pipx not found, please install pipx via nixpkgs"
                  exit 1
                fi
                mkdir -p ${config.pipx.path}
                export PIPX_BIN_DIR=${config.pipx.path}
                export PATH=${config.pipx.path}:$PATH

                # Search nixpkgs for pipx package alternatives
                # echo "Searching nixpkgs for pipx package alternatives..."
                # matches_found=false
                # for pkg in ${joinQuoted config.pipx.packages}; do
                #   clean_pkg=$(echo "$pkg" | sed 's/^[[:space:][:punct:]]*//; s/[[:space:][:punct:]]*$//; s/[[:punct:]]/ /g')
                #   nix_matches=""
                #   if command -v nix >/dev/null 2>&1; then
                #     nix_matches=$(nix search nixpkgs "$clean_pkg" 2>/dev/null | grep -v '^$' | head -5)
                #   fi
                #   if [ -n "$nix_matches" ]; then
                #     matches_found=true
                #     echo "possible Nixpkg matches found for '$pkg':"
                #     echo "$nix_matches"
                #   fi
                # done
                # if [ "$matches_found" = false ]; then
                #   echo "No nixpkgs matches found for pipx packages."
                # fi
                # echo

                for pkg in ${joinQuoted config.pipx.packages}; do
                  if ! pipx list --short | grep -q "$pkg"; then
                    echo "Installing pipx package $pkg..."
                    pipx install $pkg
                  fi
                done

                # Auto-fix invalid interpreters
                if pipx list 2>&1 | grep -q "invalid interpreter"; then
                  echo "Detected invalid interpreters, running pipx reinstall-all..."
                  pipx reinstall-all
                fi
              ''
            else null;

          home.activation.installEgetPackages =
            if config.eget.enable
            then
              lib.hm.dag.entryAfter ["writeBoundary"] ''
                export PATH=${pkgs.eget}/bin:$PATH
                if ! command -v eget >/dev/null 2>&1; then
                  echo "Error: eget not found, please install eget via nixpkgs"
                  exit 1
                fi
                mkdir -p ${config.eget.path}
                export EGET_BIN=${config.eget.path}
                export PATH=${config.eget.path}:$PATH

                # Search nixpkgs for eget package alternatives
                # echo "Searching nixpkgs for eget package alternatives..."
                # matches_found=false
                # for pkg in ${joinQuoted config.eget.packages}; do
                #   clean_pkg=$(basename "$pkg" | sed 's/^[[:space:][:punct:]]*//; s/[[:space:][:punct:]]*$//; s/[[:punct:]]/ /g')
                #   nix_matches=""
                #   if command -v nix >/dev/null 2>&1; then
                #     nix_matches=$(nix search nixpkgs "$clean_pkg" 2>/dev/null | grep -v '^$' | head -5)
                #   fi
                #   if [ -n "$nix_matches" ]; then
                #     matches_found=true
                #     echo "possible Nixpkg matches found for '$pkg':"
                #     echo "$nix_matches"
                #   fi
                # done
                # if [ "$matches_found" = false ]; then
                #   echo "No nixpkgs matches found for eget packages."
                # fi
                # echo

                for pkg in ${joinQuoted config.eget.packages}; do
                  binname=$(basename $pkg)
                  if [ ! -x "${config.eget.path}/$binname" ]; then
                    echo "Installing eget package $pkg..."
                    eget $pkg --to=${config.eget.path}
                  fi
                done
              ''
            else null;

          home.sessionVariables = {
            PATH = "${config.npm.path}:${config.eget.path}:${config.pipx.path}:$PATH";
          };

          home.packages = with pkgs; [
            pipx
            nodePackages_latest.nodejs
            eget
          ];
        };
      };
    };
  };
}
