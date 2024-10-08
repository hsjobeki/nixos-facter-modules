{
  lib,
  config,
  options,
  ...
}:
let
  cfg = config.facter;
  modulePath = lib.concatStringsSep "/" (lib.take 4 (lib.splitString [ "/" ] __curPos.file));
in
{
  imports = [
    ./boot.nix
    ./networking
    ./virtualisation.nix
    ./firmware.nix
    ./system.nix
  ];

  options.facter = with lib; {
    report = mkOption {
      type = types.raw;
      default = builtins.fromJSON (builtins.readFile config.facter.reportPath);
      description = "An import fo the reportPath.";
    };

    reportPath = mkOption {
      type = types.path;
      description = "Path to a report generated by nixos-facter.";
    };

    debug = {
      options = mkOption {
        type = types.raw;
        description = "All of the options affected by Facter modules";
      };
      config = mkOption {
        type = types.raw;
        description = "A breakdown of the NixOS config being applied by each Facter module.";
      };
    };
  };

  config.facter.debug = {
    options =
      let
        # we want all options except our own, otherwise we get into recursive issues
        otherOptions = lib.filterAttrs (n: _: n != "facter") options;

        # a filter for identifying options where a Facter module has affected the value
        touchedByFacter =
          { definitionsWithLocations, ... }:
          let
            # some options fail when we try to evaluate them, so we wrap this in tryEval
            eval = builtins.tryEval (
              builtins.any (
                {
                  file ? "",
                  ...
                }:
                # we only want options affected by our modules
                lib.hasPrefix "${modulePath}/modules/nixos" file
              ) definitionsWithLocations
            );
          in
          eval.success && eval.value;
      in
      lib.fold (a: b: lib.recursiveUpdate a b) { } (
        map (value@{ loc, ... }: lib.setAttrByPath loc value) (
          # we collect the options first with simple option filter, and then we filter them some more, otherwise we get
          # a max-call depth exceeded error (dunno why)
          lib.filter touchedByFacter (lib.collect lib.isOption otherOptions)
        )
      );

    config =
      # extract the config values for each option, broken down by facter module
      lib.mapAttrsRecursiveCond
        (
          {
            definitionsWithLocations ? null,
            ...
          }:
          # keep recursing if we are not processing an option, otherwise apply the map function
          definitionsWithLocations == null
        )
        (
          _:
          { definitionsWithLocations, ... }:
          builtins.listToAttrs (
            map
              (
                { file, value }:
                {
                  name = "<facter>${lib.removePrefix modulePath file}";
                  inherit value;
                }
              )
              (
                # we only want facter modules
                lib.filter ({ file, ... }: lib.hasPrefix modulePath file) definitionsWithLocations
              )
          )
        )
        cfg.debug.options;
  };

}
