ThreadCtl-rs WebUI (Original Native)

This KernelSU module packages the unmodified upstream threadctl-rs daemon and adds only:
- boot/service scripts
- persistent configuration files
- a KernelSU WebUI for selecting installed apps and built-in profiles
- a raw advanced KDL editor

Upstream source:
https://github.com/StarfallSeas/threadctl-rs
Pinned source commit:
60f223d156d630082a803a165ac9ac898f43f8b9

The WebUI-managed rules and advanced KDL are merged into config/threadctl.kdl.
The original Rust daemon is the only scheduling engine in this module.
