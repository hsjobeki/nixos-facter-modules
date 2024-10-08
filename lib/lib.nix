lib:
let

  inherit (lib) assertMsg;

  hasCpu =
    name:
    {
      hardware ? { },
      ...
    }:
    let
      cpus = hardware.cpu or [ ];
    in
    assert assertMsg (hardware != { }) "no hardware entries found in the report";
    assert assertMsg (cpus != [ ]) "no cpu entries found in the report";
    builtins.any (
      {
        vendor_name ? null,
        ...
      }:
      assert assertMsg (vendor_name != null) "detail.vendor_name not found in cpu entry";
      vendor_name == name
    ) cpus;

in
{
  inherit hasCpu;
  hasAmdCpu = hasCpu "AuthenticAMD";
  hasIntelCpu = hasCpu "GenuineIntel";
}
