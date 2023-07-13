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
        nativeBuildInputs = with pkgs; [
          llvmPackages_16.bintools
          pkg-config
          xorg.libXcursor
          compdb
          cmake
          ninja
          shaderc
        ];
        buildInputs = with pkgs; [
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
      in {
        formatter = pkgs.alejandra;
        packages = rec {
          fetchfiles = {
            files,
            sha256 ? "",
            preferLocalBuild ? true,
            parallel ? 100,
            checkCertificate ? true,
          }:
            pkgs.stdenvNoCC.mkDerivation {
              name = "files";
              nativeBuildInputs = [pkgs.aria];
              outputHashAlgo = "sha256";
              outputHashMode = "recursive";
              outputHash = sha256;
              parallel = toString parallel;
              checkCertificate = toString checkCertificate;

              inherit files;
              SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

              builder = ./builder.sh;
              impureEnvVars = pkgs.lib.fetchers.proxyImpureEnvVars;
              inherit preferLocalBuild;
            };

          bar-content = pkgs.stdenv.mkDerivation {
            name = "bar-content";
            src = fetchfiles {
              files = ./sources/files.list;
              sha256 = "sha256-LJmwCcWV/UTyouJHnhxETn0p1BDAil7oh5Cu//4bjWs=";
              checkCertificate = false;
            };
            buildPhase = ''
              mkdir -p $out
              cp -vLr rapid $out
              cp -vLr pool $out
              cp -vLr packages $out
            '';
          };

          spring = pkgs.stdenv.mkDerivation rec {
            pname = "spring-bar";
            version = "105.1.1-1821-gaca6f20";
            inherit nativeBuildInputs buildInputs;

            hardeningDisable = ["all"];

            src = pkgs.fetchFromGitHub {
              owner = "beyond-all-reason";
              repo = "spring";
              rev = "aca6f204edbc2e64b8726996283fd522f404e1a2";
              sha256 = "sha256-NSgKUx83YejNTOcANAG+EAgoXz8AIXnS8iqE8LsHgCc=";
              fetchSubmodules = true;
            };

            configurePhase = ''
              echo "${version} BAR105" > VERSION
              mkdir builddir-nix
              cd builddir-nix
              FLAGS='-msse -mno-sse3 -mno-ssse3 -mno-sse4.1 -mno-sse4.2 -mno-sse4 -mno-sse4a -mno-avx -mno-fma -mno-fma4 -mno-xop -mno-lwp -mno-avx2 -mfpmath=sse -fsingle-precision-constant -frounding-math -mieee-fp -pipe -fno-strict-aliasing  -fvisibility=hidden -pthread -O3 -g -DNDEBUG -DNDEBUG -DCURL_STATICLIB'
              cmake \
                -DCMAKE_TOOLCHAIN_FILE="${./toolchain/gcc_x86_64-pc-linux-gnu.cmake}" \
                -DCMAKE_CXX_COMPILER_LAUNCHER="" \
                -DCMAKE_CXX_FLAGS_REL="$FLAGS -std=c++17 -fvisibility-inlines-hidden" \
                -DCMAKE_C_FLAGS_REL="$FLAGS" \
                -DCMAKE_BUILD_TYPE=REL \
                -DDEBUG_MAX_WARNINGS=OFF \
                -DAI_TYPES=NATIVE \
                -DINSTALL_PORTABLE=ON \
                -DCMAKE_USE_RELATIVE_PATHS:BOOL=1 \
                -DBINDIR:PATH=./ \
                -DLIBDIR:PATH=./ \
                -DDATADIR:PATH=./ \
                -DCMAKE_INSTALL_PREFIX="$out/bin" \
                -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
                -G Ninja \
                ..
            '';

            installPhase = ''
              ninja install
            '';
          };

          byar = pkgs.stdenv.mkDerivation {
            pname = "byar";
            version = "105.1.1-1821-gaca6f20";
            passAsFile = ["text"];
            text = ''
              SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
              if [ -n "$WAYLAND_DISPLAY" ]; then
                export SDL_VIDEODRIVER=wayland
              fi

              mkdir -p $HOME/.local/share/spring/bar
              $SCRIPT_DIR/spring --isolation --isolation-dir $SCRIPT_DIR --write-dir $HOME/.local/share/spring/bar --menu 'rapid://byar-chobby:test'
            '';

            src = ./.;

            buildPhase = ''
              mkdir -p $out/bin
              cp -vLr ${spring}/bin/* $out/bin

              ln -s ${bar-content}/rapid $out/bin/rapid
              ln -s ${bar-content}/pool $out/bin/pool
              ln -s ${bar-content}/packages $out/bin/packages

              cat ${./chobby_config.json} > $out/bin/chobby_config.json

              if [ -e "$textPath" ]; then
                mv -f "$textPath" "$out/bin/byar"
              else
                echo -n "$text" > "$out/bin/byar"
              fi
              chmod +x $out/bin/byar
            '';
          };
        };
        devShell = pkgs.mkShell {
          inherit nativeBuildInputs buildInputs;
          hardeningDisable = ["all"];
        };
      }
    );
}
