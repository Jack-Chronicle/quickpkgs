# quickpkgs: User Package Installer for Home Manager

Easily manage global package installation with npm, pipx, and eget within Home Manager using this reusable module.

## Features

- Ensures installation of python3Full, pipx, nodejs, and eget packages.
- Adds configured binary directories to user PATH.
- Supports enabling/disabling each package manager and customizing package lists and install paths.

## Usage

1. Add the flake to your nix config inputs:
```
inputs = {
  quickpkgs.url = "github:Jack-Chronicle/quickpkgs";
};
```

2. Include the module in your home-manager configuration:
```
imports = [
  inputs.quickpkgs.homeModules.default
];
```

# Default Configuration Options

```
{
  npm = {
    enable = true; # Enable npm package installation
    path = "${config.home.homeDirectory}/.local/bin"; # Install location
    packages = []; # List of npm global packages to install
  };
  pipx = {
    enable = true;
    path = "${config.home.homeDirectory}/.local/bin/";
    packages = [];
  };
  eget = {
    enable = true;
    path = "${config.home.homeDirectory}/.local/bin";
    packages = [];
  };
}
```

## Requirements

- Your system must have `python3Full`, `pipx`, `nodejs`, and `eget` available via nixpkgs (included automatically by the module).
