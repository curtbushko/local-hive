job "cell-with-cni" {
  datacenters = ["dc1"]
  type        = "service"

  group "cell-test" {
    restart {
      attempts = 0
      mode     = "fail"
    }
    task "cell1" {
      driver = "firecracker-task-driver"
      config {
        BootDisk    = "CELL_ROOTFS"
        Firecracker = "/usr/bin/firecracker"
        KernelImage = "CELL_KERNEL"
        Mem         = 12
        Network     = "box"
        Vcpus       = 1
      }
    }
  }
}
