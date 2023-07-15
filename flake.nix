{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        versions = import ./versions.nix;
      in {
        formatter = pkgs.alejandra;
        packages = rec {
          spring-byar = with pkgs;
            stdenv.mkDerivation {
              pname = "spring-byar";
              version = versions.spring-byar.version;

              src = fetchurl {
                url = versions.spring-byar.url;
                sha256 = versions.spring-byar.sha256;
              };

              nativeBuildInputs = [
                p7zip
                autoPatchelfHook
              ];

              buildInputs = [
                xorg.libXcursor
                SDL2.dev
                libdevil.dev
                curl.dev
                p7zip
                openal
                libogg.dev
                libvorbis.dev
                libunwind.dev
                freetype.dev
                glew.dev
                minizip
                fontconfig.dev
                jsoncpp.dev
                vulkan-headers
                vulkan-loader
              ];

              unpackPhase = ''
                7z x "$src"
              '';

              installPhase = ''
                mkdir -p $out
                cp -aLv . $out/bin
              '';
            };

          pr-downloader-bar = with pkgs;
            stdenv.mkDerivation {
              pname = "pr-downloader-bar";
              version = versions.pr-downloader-bar.version;
              src = fetchFromGitHub {
                owner = "beyond-all-reason";
                repo = "pr-downloader";
                rev = versions.pr-downloader-bar.rev;
                sha256 = versions.pr-downloader-bar.sha256;
                fetchSubmodules = true;
              };
              buildInputs = [
                gcc
                cmake
                curl
                pkg-config
                jsoncpp
                boost
                minizip
              ];
              postInstall = ''
                mkdir $out/bin
                mv $out/pr-downloader $out/bin
              '';
            };

          spring-launcher-byar = with pkgs; let
            chobby-byar-src = fetchFromGitHub {
              owner = "beyond-all-reason";
              repo = "BYAR-Chobby";
              rev = versions.chobby-byar.rev;
              sha256 = versions.chobby-byar.sha256;
            };
            spring-launcher-byar-src = fetchFromGitHub {
              owner = "beyond-all-reason";
              repo = "spring-launcher";
              rev = versions.spring-launcher-byar.rev;
              sha256 = versions.spring-launcher-byar.sha256;
            };
            version = "${versions.chobby-byar.version}-launcher-${versions.spring-launcher-byar.version}";
            src =
              runCommand "byar-launcher-src-${version}"
              {
                buildInputs = [nodejs jq nodePackages.npm];
              } ''
                cp -r ${chobby-byar-src} BYAR-Chobby
                cp -r ${spring-launcher-byar-src} launcher
                chmod -R +w *

                pushd launcher
                echo "Patching files..."
                patch -p1 < ${./patches/01-disable-updates.patch}
                popd

                echo "Applying chobby ${versions.chobby-byar.version} to launcher ${versions.spring-launcher-byar.version}..."
                cp -r BYAR-Chobby/dist_cfg/* launcher/src/
                for dir in bin files build; do
                  mkdir -p launcher/$dir
                  if [ -d launcher/src/$dir/ ]; then
                    mv launcher/src/$dir/* launcher/$dir/
                    rm -rf launcher/src/$dir
                  fi
                done

                GITHUB_REPOSITORY=beyond-all-reason/BYAR-Chobby
                PACKAGE_VERSION=${version}
                pushd BYAR-Chobby
                echo "Creating package.json for launcher..."
                node build/make_package_json.js ../launcher/package.json dist_cfg/config.json $GITHUB_REPOSITORY $PACKAGE_VERSION
                popd

                echo "Removing electron as dependency..."
                cat launcher/package.json \
                  | jq 'del(.devDependencies.electron)' \
                  > temp
                mv temp launcher/package.json
                cat launcher/package-lock.json \
                  | jq 'del(.packages."".devDependencies.electron)' \
                  | jq 'del(.packages."node_modules/electron")' \
                  > temp
                mv temp launcher/package-lock.json

                mv launcher $out
              '';
            nodeModules = buildNpmPackage {
              inherit src version;
              pname = "spring-launcher-byar-node-modules";
              npmDepsHash = versions.spring-launcher-byar.npmDepsHash;
              npmFlags = ["--legacy-peer-deps"];
              dontNpmBuild = true;
              passthru = {
                buildInputs = [
                  nodejs
                  libcxx
                  xorg.libX11
                ];
              };
              installPhase = ''
                mv node_modules $out
              '';
            };
          in
            stdenv.mkDerivation {
              pname = "spring-launcher-byar";
              inherit version src;

              phases = ["buildPhase"];
              buildPhase = ''
                mkdir -p "$out/lib"
                cp -aLv "$src" "$out/lib/dist"
                chmod -R +w "$out"
                cp -r "${nodeModules}" "$out/lib/dist/node_modules"

                # rm will validate that the original file exist
                rm "$out/lib/dist/bin/butler/linux/butler"
                ln -s "${pkgs.butler}/bin/butler" "$out/lib/dist/bin/butler/linux/butler"

                rm "$out/lib/dist/bin/pr-downloader"
                ln -s "${pr-downloader-bar}/bin/pr-downloader" "$out/lib/dist/bin/pr-downloader"

                ln -s "${p7zip}/bin/7z" "$out/lib/dist/bin/7z"

                rm "$out/lib/dist/src/path_7za.js"
                cat << EOF > "$out/lib/dist/src/path_7za.js"
                'use strict';
                module.exports = "$out/lib/dist/bin/7z";
                EOF
              '';
            };

          byar = with pkgs;
            writeShellApplication {
              name = "byar";

              text = let
                electron = electron_24;
              in ''
                declare -a args=( )
                if [ -n "$WAYLAND_DISPLAY" ]; then
                  export SDL_VIDEODRIVER=wayland
                  args+=(
                    --enable-features="UseOzonePlatform,WaylandWindowDecorations"
                  )
                fi
                ${electron}/bin/electron \
                    "''${args[@]}" \
                    ${spring-launcher-byar}/lib/dist \
                      --write-path="$HOME/.cache/beyond-all-reason/" \
                      --engine-path='${spring-byar}/bin/spring'
              '';
            };
        };
        devShell = pkgs.mkShell {
          hardeningDisable = ["all"];
          packages = with pkgs; [aria];
        };
      }
    );
}
