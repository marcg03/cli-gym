# microVM settings for the player runtime (qemu, rootless, no network).
{ kvm }:
{ lib, ... }:
{
  microvm = {
    hypervisor = "qemu";
    mem = 512;
    vcpu = 1;
    interfaces = [ ];
    socket = null;
    # Share the host store read-only: no per-seed disk image to build.
    shares = [{
      proto = "9p";
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    }];
    # Without KVM (e.g. CI containers, nested setups) fall back to emulation.
    cpu = lib.mkIf (!kvm) "max";
  };
}
