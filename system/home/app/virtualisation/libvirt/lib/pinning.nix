# Shared CPU pin layout: 12 vCPUs onto cores 2-7 + their SMT siblings
# 10-15, leaving 0-1,8-9 to the host. Used by the Windows gaming VMs and
# the macOS GPU VM so the layouts can't drift.
{
  vmCores = [ 2 10 3 11 4 12 5 13 6 14 7 15 ];
  hostCores = "0-1,8-9";
}
