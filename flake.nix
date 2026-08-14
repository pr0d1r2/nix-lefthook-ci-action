{
  description = "CHANGEME";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting";
    set-and-setting.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    set-and-setting.lib.mkConsumerFlake {
      inherit self nixpkgs set-and-setting;
      fragments = [
        "base"
        "actions"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];
      lib = set-and-setting.lib // {
        # The pinned set-and-setting helper still passes a scalar regex to
        # nixpkgs' sourceByRegex.  Override it locally until that dependency
        # updates, while preserving actionlint's workflow-file selection.
        mkActionlintCheck =
          args:
          set-and-setting.lib.mkLefthookCheck {
            inherit (args) pkgs;
            src = args.pkgs.lib.sources.sourceByRegex args.src [ "^\\.github/workflows/.*" ];
            wrapper = args.pkgs.writeShellApplication {
              name = "actionlint-check";
              runtimeInputs = [ args.pkgs.actionlint ];
              text = ''
                actionlint "$@"
              '';
            };
            name = args.name or "actionlint";
            suffices = [
              ".yml"
              ".yaml"
            ];
            checkFlag = "";
          };
        checksFor =
          {
            pkgs,
            src,
            fragments,
          }:
          import "${set-and-setting}/lib/checks-for.nix" {
            inherit pkgs src fragments;
            inherit (set-and-setting.lib)
              mkNixfmtCheck
              mkShfmtCheck
              mkTrailingWhitespaceCheck
              mkMissingFinalNewlineCheck
              mkEditorconfigCheckerCheck
              mkShellcheckCheck
              mkNoShellFunctionsCheck
              mkAsciiOnlyCheck
              mkTyposCheck
              mkStatixCheck
              mkDeadnixCheck
              mkNixNoEmbeddedShellCheck
              mkFlakeManifestCheck
              mkGitleaksCheck
              mkGitConflictMarkersCheck
              mkGitNoLocalPathsCheck
              mkExecutePermissionsCheck
              mkFileSizeCheckCheck
              mkLinterCoverageCheck
              ;
            mkActionlintCheck =
              args:
              set-and-setting.lib.mkLefthookCheck {
                inherit (args) pkgs;
                src = args.pkgs.lib.sources.sourceByRegex args.src [ "^\\.github/workflows/.*" ];
                wrapper = args.pkgs.writeShellApplication {
                  name = "actionlint-check";
                  runtimeInputs = [ args.pkgs.actionlint ];
                  text = ''
                    actionlint "$@"
                  '';
                };
                name = args.name or "actionlint";
                suffices = [
                  ".yml"
                  ".yaml"
                ];
                checkFlag = "";
              };
          };
        materializationFor =
          args:
          (
            let
              materialization = set-and-setting.lib.materializationFor args;
            in
            materialization
            // {
              packages = materialization.packages ++ [
                (args.pkgs.writeShellApplication {
                  name = "lefthook-actionlint";
                  runtimeInputs = [ args.pkgs.actionlint ];
                  text = ''
                    actionlint "$@"
                  '';
                })
              ];
            }
          );
      };
      src = ./.;
    };
}
