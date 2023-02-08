<h1 align="center">
  <img src="https://raw.githubusercontent.com/ShadowBlip/OpenGamepadUI/main/icon.svg" alt="OpenGamepadUI Logo" width="200">
  <br>
  Open Gamepad UI
</h1>

<p align="center">
  <a href="https://github.com/ShadowBlip/OpenGamepadUI/stargazers"><img src="https://img.shields.io/github/stars/ShadowBlip/OpenGamepadUI" /></a>
  <a href="https://github.com/ShadowBlip/OpenGamepadUI/commits/main"><img src="https://img.shields.io/github/last-commit/ShadowBlip/OpenGamepadUI.svg" /></a>
  <a href="https://github.com/ShadowBlip/OpenGamepadUI/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ShadowBlip/OpenGamepadUI" /></a>
  <br>
  <br>
  <img src="https://raw.githubusercontent.com/ShadowBlip/OpenGamepadUI/main/docs/media/screenshot02.png" alt="OpenGamepadUI screenshot" width="80%">
</p>

## About

Open Gamepad UI is a free and open source game launcher and overlay written using the
[Godot Game Engine 4](https://godotengine.org/) designed with a gamepad native
experience in mind. Its goal is to provide an open and extendable foundation
to launch and play games.

> :warning: NOTE: This project is currently in the very early stages of development.

## Documentation

You can read documentation about how to use and develop for the project here:

- [User Guide](./docs/USER.md)
- [Developer Guide](./docs/DEVELOPER.md)
- [Plugin Guide](./docs/PLUGINS.md)

## Requirements

### Runtime Requirements

The following are required to run Open Gamepad UI:

- gamescope
- gcc-libs
- glibc
- libx11
- libxau
- libxcb
- libxdmcp
- libxext
- libxres
- ryzenadj (optional)
- mangoapp (optional)
- wireplumber (optional)
- firejail (optional)

## Installation

OpenGamepadUI is still in the early stages of development, so expect to
encounter many bugs. Knowing this, if you still want to try, use the following
steps below to install and run OpenGamepadUI:

#### ArchLinux

If you are using ArchLinux, you can install OpenGamepadUI from the AUR:

https://aur.archlinux.org/packages/ogui-bin


#### Other distributions

- Ensure you have the dependencies listed above installed.

- Download the latest version of OpenGamepadUI from the [releases](https://github.com/ShadowBlip/OpenGamepadUI/releases) page.

- Extract the archive to a folder

```bash
tar xvfz opengamepadui.tar.gz
```

- Copy the files from the archive to your system

```bash
sudo cp -r ./opengamepadui/usr/share/opengamepadui /usr/share
sudo cp ./opengamepadui/usr/bin/opengamepadui /usr/bin
```

## Usage

Once OpenGamepadUI is installed, you can run it inside gamescope with:

```bash
opengamepadui
```

## License

OpenGamepadUI is licensed under THE GNU GPLv3+. See LICENSE for details.
