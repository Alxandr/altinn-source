{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # https://devenv.sh/packages/
  packages = [ ];

  languages.dotnet.enable = true;
  languages.dotnet.package = pkgs.dotnetCorePackages.sdk_10_0;
}
