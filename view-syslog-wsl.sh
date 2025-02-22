#!/bin/bash
#
# Script to view syslog+dmesg logs on WSL2
#
# * By Kordian W. <code [at] kordy.com>, February 2025
#

####################
PROG=$(basename $0)
if [ "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<! >&2
$PROG: Script to view syslog+dmesg logs on WSL2

Usage: $PROG [options] <param>
	-h	this screen
!
else
  echo "* $PROG: dmesg log:"
  dmesg -T | egrep -v 'mini_init.*drop_caches: 1|R1[0-9]: 000.*R1[0-9]: 00|RBP: 0000.*000000|RDX: 0000.*000000|RAX: ffffff|RIP.*pci_user_read_config_dword|  <IRQ>$|  <.TASK>$|Call Trace:$|entry_SYSCALL_64_after_hwframe|do_syscall_64|kernfs_fop_read_iter|pci_read_config|new_sync_read|RIP: 0033:|RSP: 002b:0000.*00000000| <TASK>|  <.IRQ>$|RAX: 0000000000000000|RSI: 0000000000000|R08: 0000000000000000 R09|Code: c0 e9 c2 fe|Code: 48 8b 7b|dump_stack_lvl|update_process_times|hrtimer_interrupt|RSP: 0018:ffff|asm_sysvec_hyperv|ksys_read.0x|vfs_read.0x|tick_sched_timer.0x|sysvec_hyperv_stimer| __hrtimer_run_queues.0x|Sending NMI from CPU|RIP: 0010:_hv_pcifront_read_config|NMI backtrace for cpu|R13: ffff|nmi_trigger_cpumask_backtrace|tick_sched_do_timer|_hv_pcifront_read_config|nmi_trigger_cpumask_backtrace|rcu_dump_cpu_stacks|lapic_can_unplug_cpu|trigger_load_balance|_raw_spin_unlock_irqrestore|pci_user_read_config_dword|secondary_startup_64_no_verify|rcu_sched_clock_irq.cold|handle_softirqs|hv_pcifront_read_config|Creating login session for kordy|end_repeat_nmi|rcu_sched_clock_irq.cold|hv_balloon: Max. dynamic memory size:|nmi_cpu_backtrace.cold|nmi_cpu_backtrace_handler|default_do_nmi|Received client request to flush runtime journal|cpu_startup_entry|try_to_wake_up.0x|RBP: ffff.*ffff|  <NMI>|  </NMI>|FS-Cache: Duplicate cookie detected|FS:  00007.* GS:ffff|RIP: 0010:default_idle|RAX: 000000000.* RBX: ffff|WARNING: /etc/resolv.conf updating disabled in /etc/wsl.conf|FS-Cache: O-cookie d=0000000|FS-Cache: N-cookie c=0000|FS-Cache: O-cookie c=00|FS-Cache: N-cookie d=000|clocksource: Switched to clocksource tsc|FS-Cache: .-key=.10.|Attached SCSI disk|EXT4-fs .sd..: mounted filesystem with ordered data mode. Opts|Attached scsi generic sg2 type 0'

  echo && echo "* $PROG: syslog log:"
  egrep -v 'run-parts --report /etc/cron.hourly|Finished Ubuntu Advantage Timer for running repeated jobs|Starting Ubuntu Advantage Timer for running repeated jobs|ua-timer.service: Succeeded|Finished Message of the Day|motd-news.service: Succeeded|apt-daily.service: Succeeded|Finished Daily apt download activities|Starting Daily apt download activities|run-parts --report /etc/cron.daily|just raised the bar for easy, resilient and secure K8s cluster|Strictly confined Kubernetes makes edge and IoT secure|engage/secure-kubernetes-at-the-edge|Starting Message of the Day|Finished Daily apt upgrade and clean activities|packagekit.service: Succeeded|apt-daily-upgrade.service: Succeeded.|Starting Daily apt upgrade and clean activities|Finished Update the local ESM caches|esm-cache.service: Succeeded|apt-news.service: Succeeded|Finished Update APT News|Finished Daily man-db regeneration|logrotate.service: Succeeded|Finished Rotate log files|man-db.service: Succeeded|Starting Update APT News|Starting Update the local ESM caches|.system. Reloaded configuration|systemd.1.: Reloading.|CMD .test -e /run/systemd/system .. SERVICE_MODE=1 /sbin/e2scrub_all -A -r|Configuration file /run/systemd/system/netplan-ovs-cleanup.service is marked world-inaccessible. This has no effect as configuration data is accessible|snap.chromium.chromedriver-.*: Succeeded|systemd-timedated.service: Succeeded|mnt-Scripts.mount: Succeeded|mnt-Movies.mount: Succeeded|/etc/resolv.conf updating disabled in /etc/wsl.conf' /var/log/syslog
fi

# EOF
