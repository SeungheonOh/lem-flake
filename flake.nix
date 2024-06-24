{
  description = "lem";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = {self, nixpkgs}: {
    packages.x86_64-linux.lem =
      with import nixpkgs { system = "x86_64-linux"; };

      let
        micros = pkgs.sbcl.buildASDFSystem rec {
          pname = "micros";
          version = "0.0.0";
          src = pkgs.fetchFromGitHub {
            owner = "lem-project";
            repo = "micros";
            rev = "9fc7f1e5b0dbf1b9218a3f0aca7ed46e90aa86fd";
            sha256 = "sha256-bLFqFA3VxtS5qDEVVi1aTFYLZ33wsJUf26bwIY46Gtw=";
          };
        };

        lem-mailbox = pkgs.sbcl.buildASDFSystem rec {
          pname = "lem-mailbox";
          version = "0.0.0";
          src = pkgs.fetchFromGitHub {
            owner = "lem-project";
            repo = "lem-mailbox";
            rev = "12d629541da440fadf771b0225a051ae65fa342a";
            sha256 = "sha256-hb6GSWA7vUuvSSPSmfZ80aBuvSVyg74qveoCPRP2CeI=";
          };
          lispLibs = with pkgs.sbclPackages; [
            bordeaux-threads
            bt-semaphore
	          queues
            queues_dot_simple-cqueue
          ];
        };

      in
        pkgs.sbcl.buildASDFSystem rec {
          pname = "lem";

          version = "2.2.0";

          # https://nixos.wiki/wiki/Packaging/Binaries
          src = pkgs.fetchFromGitHub {
            owner = "lem-project";
            repo = "lem";
            rev = "2c6a0da38594d4eb2c28a0151326bc19994fecb9";
            sha256 = "sha256-AuzN82m3+m+I3Qlmr3AqMVCI75XJSc3rELdJe+GxbZ4=";
          };
          lispLibs = with pkgs.sbclPackages; [
            iterate
            closer-mop
            trivia
            alexandria
            trivial-gray-streams
            trivial-types
            cl-ppcre
            inquisitor
            babel
            bordeaux-threads
            yason
            log4cl
            split-sequence
            str
            dexador
            qlot
          ] ++ [micros lem-mailbox];
        };

    packages.x86_64-linux.lem-base16-themes =
      with import nixpkgs { system = "x86_64-linux"; };
      pkgs.sbcl.buildASDFSystem {
        pname = "lem-base16-themes";
        version = "unstable-2023-07-04";
        src = pkgs.fetchFromGitHub {
          owner = "lem-project";
          repo = "lem-base16-themes";
          rev = "07dacae6c1807beaeffc730063b54487d5c82eb0";
          hash = "sha256-UoVJfY2v4+Oc1MfJ9+4iT2ZwIzUEYs4jRi2Xu69nGkM=";
        };
        lispLibs = [self.packages.x86_64-linux.lem];
      };

    packages.x86_64-linux.lem-exec =
      with import nixpkgs { system = "x86_64-linux"; };
      let
        jsonrpc = pkgs.sbclPackages.jsonrpc.overrideLispAttrs (oldAttrs: {
          src = pkgs.fetchFromGitHub {
            owner = "cxxxr";
            repo = "jsonrpc";
            rev = "6e3d23f9bec1af1a3155c21cc05dad9d856754bc";
            hash = "sha256-QbXesQbHHrDtcV2D4FTnKMacEYZJb2mRBIMC7hZM/A8=";
          };
          systems =
            [ "jsonrpc" "jsonrpc/transport/stdio" "jsonrpc/transport/tcp" ];
          lispLibs = with pkgs.sbclPackages;
            oldAttrs.lispLibs ++ [ cl_plus_ssl quri fast-io trivial-utf-8 ];
        });
        queues = pkgs.sbclPackages.queues.overrideLispAttrs (oldAttrs: {
          systems = [ "queues" "queues.priority-cqueue" "queues.priority-queue" "queues.simple-cqueue" "queues.simple-queue" ];
          lispLibs = oldAttrs.lispLibs ++ (with pkgs.sbclPackages; [bordeaux-threads]);
        });
      in
      frontend: pkgs.sbcl.buildASDFSystem {
        inherit (self.packages.x86_64-linux.lem) src;
        pname = "lem-exec";
        version = "unstable";
        lispLibs = [
          self.packages.x86_64-linux.lem
          self.packages.x86_64-linux.lem-base16-themes
          jsonrpc
        ] ++ (with pkgs.sbcl.pkgs; [
          _3bmd
          _3bmd-ext-code-blocks
          lisp-preprocessor
          trivial-ws
          trivial-open-browser
          cl-charms
          cl-setlocale
          parse-number
          cl-package-locks
          async-process
          swank
        ])
        ++ (if frontend == "sdl2" then (with pkgs.sbcl.pkgs; [sdl2 sdl2-ttf sdl2-image trivial-main-thread]) else []);
        nativeLibs = if frontend == "sdl2" then with pkgs; [SDL2 SDL2_ttf SDL2_image] else [];
        nativeBuildInputs = with pkgs; [ openssl makeWrapper ];
        buildScript = pkgs.writeText "build-lem.lisp" ''
          (load (concatenate 'string (sb-ext:posix-getenv "asdfFasl") "/asdf.fasl"))
          ; Uncomment this line to load the :lem-tetris contrib system
          ;(asdf:load-system :lem-tetris)
          ${if frontend == "sdl2" then "(asdf:load-system :lem-sdl2)" else "(asdf:load-system :lem-ncurses)"}
          (sb-ext:save-lisp-and-die
            "lem"
            :executable t
            :purify t
            #+sb-core-compression :compression
            #+sb-core-compression t
            :toplevel #'lem:main)
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp -v lem $out/bin/lem-exec
          wrapProgram $out/bin/lem-exec \
            --prefix LD_LIBRARY_PATH : $LD_LIBRARY_PATH \
        '';
        passthru = {
          withPackages = import ./wrapper.nix { inherit (pkgs) makeWrapper sbcl lib symlinkJoin; lem = self.packages.x86_64-linux.lem-exec frontend; };
        };
      };

    packages.x86_64-linux.lem-ncurses = self.packages.x86_64-linux.lem-exec "ncurses";
    packages.x86_64-linux.lem-sdl2 = self.packages.x86_64-linux.lem-exec "sdl2";
  };
}
