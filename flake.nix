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
        materializationFor = args:
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
          };
      };
      extraChecks = pkgs: {
        actionlint = set-and-setting.lib.mkLefthookCheck {
          inherit pkgs;
          wrapper = pkgs.writeShellApplication {
            name = "actionlint-check";
            runtimeInputs = [ pkgs.actionlint ];
            text = ''
              actionlint "$@"
            '';
          };
          src = pkgs.lib.sources.sourceByRegex ./. [ "^.github/workflows/.*" ];
          name = "actionlint";
          suffices = [
            ".yml"
            ".yaml"
          ];
          checkFlag = "";
        };
      };
      src = ./.;
    };
}
