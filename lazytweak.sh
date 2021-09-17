!/system/bin/sh
#=======================================#
#VARIABLES===============================#
LOG=/sdcard/Android/lazy.log
LPM="/sys/module/lpm_levels/parameters"
LMK="/sys/module/lowmemorykiller/parameters"
ST_TOP="/dev/stune/top-app"
ST_FORE="/dev/stune/foreground"
ST_BACK="/dev/stune/background"
ST_RT="/dev/stune/rt"
ST_GLOBAL="/dev/stune/"
CSET="/dev/cpuset"
VM="/proc/sys/vm"
NET="/proc/sys/net"
FS="/proc/sys/fs"
KERNEL="/proc/sys/kernel"
DBG="/sys/kernel/debug"
BOOST="sys/module/cpu_boost/parameters"
RAM=$(free -m | awk '/RAM:/{print $2}')
MODE=$(cat /sdcard/mode.txt)
CPUS=`grep -c processor /proc/cpuinfo`
#=======================================#
#=======================================#

stop thermal-engine

stop perfd

###############################
rm $LOG

# Log in white and continue (unnecessary)
kmsg() {
	echo -e "[i] $@" >> $LOG
	echo -e "[i] $@"
}

ctl() {
	# Bail out if file does not exist
	[[ ! -f "$1" ]] && return 1

	# Fetch the current key value
	local curval=`cat "$1" 2> /dev/null`
	
	# Make file writable in case it is not already
	chmod +w "$1" 2> /dev/null

	# Write the new value and bail if there's an error
	if ! echo "$2" > "$1" 2> /dev/null
	then
		kmsg "Failed: $1 → $2"
		return 1
	fi

	# Log the success
	kmsg "$1 $curval → $2"
}

vibrate_cmode() {
if [ -e /sys/class/leds/vibrator/duration ] &&  [ -e /sys/class/leds/vibrator/activate ];then
	echo 400 > /sys/class/leds/vibrator/duration && echo 1 > /sys/class/leds/vibrator/activate
fi
}

# Check for root permissions and bail if not granted
if [[ "$(id -u)" -ne 0 ]]
then
	kmsg "No root permissions. Exiting."
	exit 1
fi

# Log the date and time for records sake
kmsg "Time of execution: $(date)"

# Sync to data in the rare case a device crashes
sync

# Kernel
ctl $KERNEL/sched_migration_cost_ns 15000000
ctl $KERNEL/sched_rt_runtime_us -1
ctl $KERNEL/perf_cpu_time_max_percent 5
ctl $KERNEL/sched_autogroup_enabled 0
ctl $KERNEL/sched_child_runs_first 0
ctl $KERNEL/sched_tunable_scaling 0
ctl $KERNEL/sched_schedstats 0
ctl $KERNEL/sched_min_task_util_for_boost_colocation 0
ctl $KERNEL/sched_initial_task_util 0
ctl $KERNEL/sched_sync_hint_enable 0
ctl $KERNEL/sched_boost 0
ctl $KERNEL/sched_nr_migrate 4
ctl $KERNEL/sched_rr_timeslice_ms 7
ctl $KERNEL/sched_time_avg_ms 5
ctl $KERNEL/sched_rt_runtime_us -1
ctl $KERNEL/perf_event_max_sample_rate 10000
ctl $KERNEL/sched_walt_rotate_big_tasks 1
ctl $KERNEL/printk_devkmsg off


# Scheduler features
if [[ -f "$DBG/sched_features" ]]
then
	ctl $DBG/sched_features NEXT_BUDDY
	ctl $DBG/sched_features TTWU_QUEUE
	ctl $DBG/sched_features NO_GENTLE_FAIR_SLEEPERS
	ctl $DBG/sched_features NO_WAKEUP_PREEMPTION
	ctl $DBG/sched_features NO_HRTICK
	ctl $DBG/sched_features NO_DOUBLE_TICK
	ctl $DBG/sched_features SIS_AVG_CPU
	ctl $DBG/sched_features NO_RT_PUSH_IPI
	ctl $DBG/sched_features NO_ATTACH_AGE_LOAD
fi

# Disable compat logging
ctl $KERNEL/compat-log 0

# Disable Kernel panic/s
ctl $KERNEL/panic 0
ctl $KERNEL/softlockup_panic 0
ctl $KERNEL/panic_on_oops 0

# Balanced CPUSET for efficiency
ctl $CSET/foreground/cpus "0-6"
ctl $CSET/background/cpus "0-3"
ctl $CSET/restricted/cpus "0-3"

for i in $KERNEL/sched_domain/cpu*/domain*/
do
ctl "${i}busy_factor" 0
ctl "${i}cache_nice_tries" 4
ctl "${i}busy_idx" 3
ctl "${i}idle_idx" 2
ctl "${i}newidle_idx" 2
ctl "${i}forkexec_idx" 1
ctl "${i}max_interval" 7
ctl "${i}min_interval" 1
done

RAM=$(free -m | awk '/Mem:/{print $2}')

# Disable panic on OOM situations.
ctl $VM/panic_on_oom 0

# File grace Period
ctl $FS/lease-break-time 10

#vm
ctl $VM/oom_kill_allocating_task 0
ctl $VM/block_dump 0
ctl $VM/page-cluster 0
ctl $VM/overcommit_memory 1
ctl $VM/compact_unevictable_allowed 1
ctl $VM/reap_mem_on_sigkill 1
ctl $VM/compact_memory 1
ctl $VM/oom_dump_tasks 0
ctl $VM/stat_interval 10
ctl $VM/swappiness 100
ctl $FS/lease-break-time 5
ctl $FS/dir-notify-enable 0
ctl $FS/leases-enable 1

ctl /proc/irq/default_smp_affinity 0f

clear_ram() {
ctl $VM/drop_caches 3
sleep 2
ctl $VM/drop_caches 2
sleep 2
ctl $VM/drop_caches 1
sleep 2 
echo "0" > $VM/drop_caches
sleep 2
ctl $VM/drop_caches 3
}

clear_ram

# EXT4 TUNABLES
ext4="/sys/fs/ext4/*"
	for ext4b in $ext4
	do
			 # increase number of inode table blocks that ext4's inode table readahead algorithm will pre-read into the buffer cache
             ctl ${ext4b}/inode_readahead_blks 64
			 ctl $ext4b/mb_group_prealloc 768
		     ctl $ext4b/mb_max_to_scan 0
			 ctl $ext4b/mb_min_to_scan 0
			 ctl $ext4b/extent_max_zeroout_kb 0
			 ctl $ext4b/mb_stream_req 0
			 ctl $ext4b/mb_order2_req 0
 done
 
# Disables snapshot crashdumper 
ctl /sys/class/kgsl/kgsl-3d0/snapshot/snapshot_crashdumper 0

# Same as reap_mem_on_sigkill 
ctl $LMK/oom_reaper 1

# Extra free memory set by system
ctl $VM/extra_free_kbytes $(($RAM * 3))

# Minimum Free memory in kbytes set by system
ctl $VM/min_free_kbytes $(($RAM * 2))

# Adj
ctl $LMK/adj "0,110,250,550,850,1000"

# Flash storages doesn't comes with any back seeking problems, so set this as low as possible for performance;
for i in /sys/block/*/queue/iosched
do
  ctl "$i/back_seek_max" 12582912
  ctl "$i/back_seek_penalty" 1
  ctl "$i/quantum" 4
  ctl "$i/fifo_expire_async" 330
  ctl "$i/fifo_expire_sync" 50
  ctl "$i/group_idle" 0
  ctl "$i/group_idle_us" 0
  ctl "$i/low_latency" 1
  ctl "$i/slice_async" 32
  ctl "$i/slice_async_rq" 4
  ctl "$i/slice_idle" 0
  ctl "$i/slice_idle_us" 0
  ctl "$i/slice_sync" 59
  ctl "$i/target_latency" 100
  ctl "$i/target_latency_us" 100000
done

# Cgroup functions
# $1:task_name $2:cgroup_name $3:"cpuset"/"stune"
change_task_cgroup()
{
# avoid matching grep itself
# ps -Ao pid,args | grep kswapd
# 150 [kswapd0]
# 16490 grep kswapd
local ps_ret
ps_ret="$(ps -Ao pid,args)"
for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
for temp_tid in $(ls "/proc/$temp_pid/task/"); do
echo "$temp_tid" > "/dev/$3/$2/tasks"
done
done
}

# $1:task_name $2:nice(relative to 120)
change_task_nice()
{
# avoid matching grep itself
# ps -Ao pid,args | grep kswapd
# 150 [kswapd0]
# 16490 grep kswapd
local ps_ret
ps_ret="$(ps -Ao pid,args)"
for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
for temp_tid in $(ls "/proc/$temp_pid/task/"); do
renice -n "$2" -p "$temp_tid"
done
done
}
# $1:task_name $2:nice(relative to 120)
change_task_ionice()
{
# avoid matching grep itself
# ps -Ao pid,args | grep kswapd
# 150 [kswapd0]
# 16490 grep kswapd
local ps_ret
ps_ret="$(ps -Ao pid,args)"
for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
for temp_tid in $(ls "/proc/$temp_pid/task/"); do
ionice -c 2 -n "$2" -p "$temp_tid"
done
done
}
# $1:task_name $2:thread_name $3:cgroup_name $4:"cpuset"/"stune"
change_thread_cgroup()
{
    # avoid matching grep itself
    # ps -Ao pid,args | grep kswapd
    # 150 [kswapd0]
    # 16490 grep kswapd
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            if [ "$(grep "$2" /proc/$temp_pid/task/$temp_tid/comm)" != "" ]; then
                echo "$temp_tid" > "/dev/$4/$3/tasks"
            fi
        done
    done
}

# $1:task_name $2:hex_mask(0x00000003 is CPU0 and CPU1)
change_task_affinity()
{
# avoid matching grep itself
# ps -Ao pid,args | grep kswapd
# 150 [kswapd0]
# 16490 grep kswapd
local ps_ret
ps_ret="$(ps -Ao pid,args)"
for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
for temp_tid in $(ls "/proc/$temp_pid/task/"); do
taskset -p "$2" "$temp_tid"
done
done
}


# $1:process_name $2:cgroup_name $3:"cpuset"/"stune"
change_proc_cgroup()
{
    # avoid matching grep itself
    # ps -Ao pid,args | grep kswapd
    # 150 [kswapd0]
    # 16490 grep kswapd
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
        echo $temp_pid > "/dev/$3/$2/cgroup.procs"
    done
}

# $1:task_name $2:thread_name $3:cgroup_name $4:"cpuset"/"stune"
change_thread_cgroup()
{
    # avoid matching grep itself
    # ps -Ao pid,args | grep kswapd
    # 150 [kswapd0]
    # 16490 grep kswapd
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            if [ "$(grep "$2" /proc/$temp_pid/task/$temp_tid/comm)" != "" ]; then
                echo "$temp_tid" > "/dev/$4/$3/tasks"
            fi
        done
    done
}


# cgroup
change_proc_cgroup "system_server" "top-app" "cpuset"
change_proc_cgroup "system_server" "foreground" "stune"
#
change_thread_cgroup "system_server" "android.anim" "top-app" "stune"
change_thread_cgroup "system_server" "android.anim.lf" "top-app" "stune"
change_thread_cgroup "system_server" "android.ui" "top-app" "stune"

# reduce big cluster wakeup, eg. android.hardware.sensors@1.0-service
change_task_affinity "surfaceflinger" "ff"
change_task_affinity "servicemanager" "ff"
change_task_affinity "system_server" "ff"
change_task_affinity "kswapd" "7f"
change_task_affinity "oom_reaper" "7f"
change_task_ionice  "surfaceflinger" "7"
change_task_ionice  "servicemanager" "7"
change_task_ionice  "system_server" "4"

# treat crtc_commit as background, avoid display preemption on big
change_task_cgroup "crtc_commit" "system-background" "cpuset"

# Changing the cgroup of the following PIDs for smoother experience
change_task_cgroup "servicemanager" "top-app" "cpuset"
change_task_cgroup "servicemanager" "foreground" "stune"
change_task_cgroup "android.phone" "top-app" "cpuset"
change_task_cgroup "android.phone" "foreground" "stune"
change_task_cgroup "surfaceflinger" "top-app" "cpuset"
change_task_cgroup "surfaceflinger" "foreground" "stune"
change_task_cgroup "system_server" "top-app" "cpuset"
change_task_cgroup "system_server" "foreground" "stune"

# treat crtc_commit as background, avoid display preemption on big
change_task_cgroup "crtc_commit" "system-background" "cpuset"
change_task_cgroup "android.gms" "system-background" "cpuset"
change_task_cgroup "android.vending" "system-background" "cpuset"
change_task_cgroup "irq" "system-background" "cpuset"
change_task_cgroup "msm_irqbalance" "system-background" "cpuset"
change_task_cgroup "rcu_preempt" "system-background" "cpuset"
change_task_cgroup "deletescape" "system-background" "cpuset"
change_task_cgroup ".android." "system-background" "cpuset"
change_task_cgroup "launcher" "system-background" "cpuset"
change_task_cgroup "trebuchet" "system-background" "cpuset"
change_task_cgroup "com.android.systemui" "system-background" "cpuset"
change_task_cgroup "kswapd" "foreground" "cpuset"
change_task_cgroup "oom_reaper" "foreground" "cpuset"

# reduce big cluster wakeup, eg. android.hardware.sensors@1.0-service
change_task_affinity ".hardware." "3f"
# ...but exclude the fingerprint&camera service for speed
change_task_affinity ".hardware.biometrics.fingerprint" "ff"
change_task_affinity ".hardware.camera.provider" "ff"

# and pin HeapTaskDaemon on LITTLE
change_thread_cgroup "system_server" "HeapTaskDaemon" "background" "cpuset"

# changing priority of system services for less aggressive google services and better services management
change_task_nice "system_server" "-6"
change_task_nice "launcher" "-6"
change_task_nice "trebuchet" "-6"
change_task_nice "deletescape" "-6"
change_task_nice "inputmethod" "-3"
change_task_nice "method" "-3"
change_task_nice "fluid" "-9"
change_task_nice "composer" "-10"
change_task_nice "com.android.phone" "-3"
change_task_nice "crtc_commit" "2"
change_task_nice "com.android" "1"
change_task_nice "android.gms" "1"
change_task_nice "android.vending" "1"
change_task_nice "surfaceflinger" "-20"
change_task_nice "servicemanager" "-10"
change_task_nice "lmkd" "-2"
change_task_nice "oom_reaper" "-2"
change_task_nice "kswapd" "-2"

# SCHEDTUNE SETTINGS 
#BACKGROUND
ctl $ST_BACK/schedtune.boost 0
ctl $ST_BACK/schedtune.colocate 0
ctl $ST_BACK/schedtune.prefer_idle 0
ctl $ST_BACK/schedtune.sched_boost_enabled 0
ctl $ST_BACK/schedtune.sched_boost_no_override 0
#FOREGROUND
ctl $ST_FORE/schedtune.boost 0
ctl $ST_FORE/schedtune.colocate 0
ctl $ST_FORE/schedtune.prefer_idle 0
ctl $ST_FORE/schedtune.sched_boost_enabled 0
ctl $ST_FORE/schedtune.sched_boost_no_override 1
#RT
ctl $ST_RT/schedtune.boost 0
ctl $ST_RT/schedtune.colocate 0
ctl $ST_RT/schedtune.prefer_idle 1
ctl $ST_RT/schedtune.sched_boost_enabled 1
ctl $ST_RT/schedtune.sched_boost_no_override 0
#GLOBAL
ctl $ST_GLOBAL/schedtune.boost 0
ctl $ST_GLOBAL/schedtune.colocate 0
ctl $ST_GLOBAL/schedtune.prefer_idle 0
ctl $ST_GLOBAL/schedtune.sched_boost_enabled 0
ctl $ST_GLOBAL/schedtune.sched_boost_no_override 0

# Reserve 90% IO bandwith for foreground tasks
ctl /dev/blkio/blkio.weight 1000
ctl /dev/blkio/blkio.leaf_weight 1000
ctl /dev/blkio/background/blkio.weight 100
ctl /dev/blkio/background/blkio.leaf_weight 100
ctl $LPM/lpm_prediction N
ctl $LPM/sleep_disabled N
ctl $LPM/bias_hyst 25

# reduce bufferfloat
for i in $(find /sys/class/net -type l); do
  ctl $i/tx_queue_len 100
done

ctl $KERNEL/perf_event_paranoid 0
ctl $KERNEL/kptr_restrict 0

# TCP Congestion Control
for tcp in /proc/sys/net/ipv4/
do
tcp="$(cat "${tcp}tcp_available_congestion_control")"
for sched in bbr bbr2 cubic westwood reno
do
if [[ "$tcp" == *"$sched"* ]]
then
ctl $NET/ipv4/tcp_congestion_control $sched
break
fi
done

# Enable select acknowledgments
ctl $NET/ipv4/tcp_sack 1

# Increase the tcp-time-wait buckets pool size to prevent simple DOS attacks 
ctl $NET/ipv4/tcp_tw_reuse 1

# Turn on window scaling which can enlarge the transfer window:
ctl $NET/ipv4/tcp_window_scaling 1

# Do not cache metrics on closing connections 
ctl $NET/ipv4/tcp_no_metrics_save 1

# Disable SYN cookies
ctl $NET/ipv4/tcp_syncookies 0

# Enable Explicit Congestion Control
ctl $NET/ipv4/tcp_ecn 1

# Enable fast socket open for receiver and sender
ctl $NET/ipv4/tcp_fastopen 3

# Prefer latency
ctl $NET/ipv4/tcp_low_latency 1

done

# Doze battery life profile;

#Disable collective Device administrators
pm disable com.google.android.gms/com.google.android.gms.auth.managed.admin.DeviceAdminReceiver
pm disable com.google.android.gms/com.google.android.gms.mdm.receivers.MdmDeviceAdminReceiver

#Doze Setup Services
pm disable com.google.android.gms/.ads.AdRequestBrokerService
pm disable com.google.android.gms/.ads.identifier.service.AdvertisingIdService
pm disable com.google.android.gms/.ads.social.GcmSchedulerWakeupService
pm disable com.google.android.gms/.analytics.AnalyticsService
pm disable com.google.android.gms/.analytics.service.PlayLogMonitorIntervalService
pm disable com.google.android.gms/.backup.BackupTransportService
pm disable com.google.android.gms/.thunderbird.settings.ThunderbirdSettingInjectorService
pm disable com.google.android.gms/.update.SystemUpdateActivity
pm disable com.google.android.gms/.update.SystemUpdateService
pm disable com.google.android.gms/.update.SystemUpdateService$ActiveReceiver 
pm disable com.google.android.gms/.update.SystemUpdateService$Receiver 
pm disable com.google.android.gms/.update.SystemUpdateService$SecretCodeReceiver
pm disable com.google.android.gsf/.update.SystemUpdateActivity
pm disable com.google.android.gsf/.update.SystemUpdatePanoActivity
pm disable com.google.android.gsf/.update.SystemUpdateService
pm disable com.google.android.gsf/.update.SystemUpdateService$Receiver
pm disable com.google.android.gsf/.update.SystemUpdateService$SecretCodeReceiver

boot_run_once=false
spectrum_mode=$(getprop persist.spectrum.profile)
[ -z "$spectrum_mode" ] && setprop persist.spectrum.profile 0

while true
do
    sleep 3
    if $boot_run_once
    then
        [ "$(getprop persist.spectrum.profile)" == "$spectrum_mode" ] && continue
    else
        boot_run_once=true
    fi
    spectrum_mode=$(getprop persist.spectrum.profile)
    case "$spectrum_mode" in
       # Lazy Profile
        "0") {      	
kmsg "-------------------
	LAZY MODE STARTING ~
	------------------------"
#GPU Tunables
ctl /sys/class/kgsl/kgsl-3d0/devfreq/polling_interval 10
ctl /sys/class/kgsl/kgsl-3d0/idle_timer 72
ctl /sys/class/kgsl/kgsl-3d0/force_clk_on 0
ctl /sys/class/kgsl/kgsl-3d0/thermal_pwrlevel 3
ctl /sys/class/kgsl/kgsl-3d0/force_bus_on 0
ctl /sys/class/kgsl/kgsl-3d0/force_no_nap 0
ctl /sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost 2
ctl /sys/class/kgsl/kgsl-3d0/force_rail_on 0
ctl /sys/class/kgsl/kgsl-3d0/bus_split 1

for i in /sys/devices/system/cpu/cpu*/core_ctl
do
		# Tried to match this value to sched migrations
		ctl "${i}/busy_down_thres" 20
		# Tried to match this value to sched migrations
		ctl "${i}/busy_up_thres" 40
done

for queue in /sys/block/*/queue/
do
	# Choose the first governor available
	avail_scheds=`cat "${queue}scheduler"`
	for sched in cfq noop kyber bfq mq-deadline none
	do
		if [[ "$avail_scheds" == *"$sched"* ]]
		then
			ctl "${queue}scheduler" "$sched"
			break
		fi
	done
	# Disable I/O statistics accounting
	ctl "${queue}iostats" 0
	
	# Do not use I/O as a source of randomness
	ctl "${queue}add_random" 0
	
	# limit nr request for latency
	ctl "${queue}nr_requests" 64
	
	# Reduce read ahead for less overheads
	ctl "${queue}read_ahead_kb" 128
	
	# group task completion
	ctl "${queue}rq_affinity" 1
	ctl "${queue}nomerges" 1
	
done

ctl "$LMK/enable_lmk" "1"
ctl "$LMK/enable_adaptive_lmk" "1"

	
	ctl "$BOOST/input_boost_freq" 0:1600000
	ctl "$BOOST/input_boost_ms" 132
	ctl "$BOOST/sched_boost_on_input" 1
	
	for _ in $(seq 2)
	do

	# Migrate tasks down at this much load
	ctl $KERNEL/sched_downmigrate "30 60"
	ctl $KERNEL/sched_group_downmigrate 100
	ctl $KERNEL/sched_downmigrate_boosted "30 60"
	
	# Migrate tasks up at this much load
	ctl $KERNEL/sched_upmigrate "80 90"
	ctl $KERNEL/sched_group_upmigrate 120
	ctl $KERNEL/sched_upmigrate_boosted "80 90"
	done
	

	for EAS in /sys/devices/system/cpu/cpu*/cpufreq/
	do
	avail_govs=`cat "${EAS}scaling_available_governors"`
	if [[ "$avail_govs" == *"schedutil"* ]]
	then
		_ctl "${EAS}scaling_governor" schedutil
		ctl "${EAS}schedutil/up_rate_limit_us" 2500
		ctl "${EAS}schedutil/down_rate_limit_us" 10000
		ctl "${EAS}schedutil/rate_limit_us" 10000
		ctl "${EAS}schedutil/hispeed_load" 90
		ctl "${EAS}schedutil/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
		ctl "${EAS}schedutil/pl" 1
	elif [[ "$avail_govs" == *"interactive"* ]]
	then
		_ctl "${EAS}scaling_governor" interactive
		ctl "${EAS}interactive/min_sample_time" 10000
		ctl "${EAS}interactive/go_hispeed_load" 90
		ctl "${EAS}interactive/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
	fi
	done
	
	ctl $VM/vfs_cache_pressure 60
	ctl $VM/dirty_background_ratio 10
	ctl $VM/dirty_ratio 30
	ctl $VM/dirty_expire_centisecs 3000
	ctl $VM/dirty_writeback_centisecs 3000
	ctl $VM/extfrag_threshold 750
	
	# Pwrlvl of Adreno GPU (0 is max and 6 is less active)
	ctl /sys/class/kgsl/kgsl-3d0/max_pwrlevel 3
	ctl /sys/class/kgsl/kgsl-3d0/default_pwrlevel 3
	#TOP-APP
	ctl $ST_TOP/schedtune.boost 5
	ctl $ST_TOP/schedtune.colocate 0
	ctl $ST_TOP/schedtune.prefer_idle 1
	ctl $ST_TOP/schedtune.sched_boost_enabled 1
	ctl $ST_TOP/schedtune.sched_boost_no_override 1
	Second=$((($RAM*6/100)*1024/4))
	Hidden=$((($RAM*7/100)*1024/4))
	content=$((($RAM*8/100)*1024/4))
	empty=$((($RAM*9/100)*1024/4))
	
	ctl $LMK/minfree "4096,5120,$Second,$Hidden,$content,$empty"
	kmsg "-------------------
	LAZY MODE ACTIVATED ~
	------------------------"
	# Sucess Message
	kmsg $(date) 
	kmsg "LAZY HAS EXECUTED TASK SUCCESSFULLY. ENJOY!" 
	vibrate_cmode
	};;
# Performance Profile
        "1") {
  rm $LOG        	      	
  kmsg "-------------------
	PERFORMANCE MODE STARTING ~
	------------------------"
#GPU Tunables     	
ctl /sys/class/kgsl/kgsl-3d0/devfreq/polling_interval 36
ctl /sys/class/kgsl/kgsl-3d0/idle_timer 72
ctl /sys/class/kgsl/kgsl-3d0/force_clk_on 0
ctl /sys/class/kgsl/kgsl-3d0/thermal_pwrlevel 3
ctl /sys/class/kgsl/kgsl-3d0/force_bus_on 0
ctl /sys/class/kgsl/kgsl-3d0/force_no_nap 0
ctl /sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost 2
ctl /sys/class/kgsl/kgsl-3d0/force_rail_on 0
ctl /sys/class/kgsl/kgsl-3d0/bus_split 1

for i in /sys/devices/system/cpu/cpu*/core_ctl
do
		# Tried to match this value to sched migrations
		ctl "${i}/busy_down_thres" 10
		# Tried to match this value to sched migrations
		ctl "${i}/busy_up_thres" 20
done

for queue in /sys/block/*/queue/
do
	# Choose the first governor available
	avail_scheds=`cat "${queue}scheduler"`
	for sched in cfq noop kyber bfq mq-deadline none
	do
		if [[ "$avail_scheds" == *"$sched"* ]]
		then
			ctl "${queue}scheduler" "$sched"
			break
		fi
	done
	# Disable I/O statistics accounting
	ctl "${queue}iostats" 0
	
	# Do not use I/O as a source of randomness
	ctl "${queue}add_random" 0
	
	# limit nr request for latency
	ctl "${queue}nr_requests" 64
	
	# Reduce read ahead for less overheads
	ctl "${queue}read_ahead_kb" 16
	
	# Force task completion
	ctl "${queue}rq_affinity" 1
	ctl "${queue}nomerges" 1
	
done

ctl "$LMK/enable_lmk" "0"
ctl "$LMK/enable_adaptive_lmk" "0"

	ctl "$BOOST/input_boost_freq" 0:1600000
	ctl "$BOOST/input_boost_ms" 40
	ctl "$BOOST/sched_boost_on_input" 1
	
	for _ in $(seq 2)
	do

	# Migrate tasks down at this much load
	ctl $KERNEL/sched_downmigrate "60 60"
	ctl $KERNEL/sched_group_downmigrate 60
	ctl $KERNEL/sched_downmigrate_boosted "60 60"
	
	# Migrate tasks up at this much load
	ctl $KERNEL/sched_upmigrate "80 80"
	ctl $KERNEL/sched_group_upmigrate 80
	ctl $KERNEL/sched_upmigrate_boosted "80 80"
	done
	
	for EAS in /sys/devices/system/cpu/cpu*/cpufreq/
	do
	avail_govs=`cat "${EAS}scaling_available_governors"`
	if [[ "$avail_govs" == *"schedutil"* ]]
	then
		_ctl "${EAS}scaling_governor" schedutil
		ctl "${EAS}schedutil/up_rate_limit_us" 5000
		ctl "${EAS}schedutil/down_rate_limit_us" 20000
		ctl "${EAS}schedutil/rate_limit_us" 20000
		ctl "${EAS}schedutil/hispeed_load" 90
		ctl "${EAS}schedutil/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
		ctl "${EAS}schedutil/pl" 1
	elif [[ "$avail_govs" == *"interactive"* ]]
	then
		_ctl "${EAS}scaling_governor" interactive
		ctl "${EAS}interactive/min_sample_time" 20000
		ctl "${EAS}interactive/go_hispeed_load" 90
		ctl "${EAS}interactive/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
	fi
	done
	
	ctl $VM/vfs_cache_pressure 60
	ctl $VM/dirty_background_ratio 10
	ctl $VM/dirty_ratio 30
	ctl $VM/dirty_expire_centisecs 1000
	ctl $VM/dirty_writeback_centisecs 3000
	ctl $VM/extfrag_threshold 600
	
	# Pwrlvl of Adreno GPU (0 is max and 6 is less active)
	ctl /sys/class/kgsl/kgsl-3d0/max_pwrlevel 3
	ctl /sys/class/kgsl/kgsl-3d0/default_pwrlevel 3
	#TOP-APP
	ctl $ST_TOP/schedtune.boost 0
	ctl $ST_TOP/schedtune.colocate 0
	ctl $ST_TOP/schedtune.prefer_idle 0
	ctl $ST_TOP/schedtune.sched_boost_enabled 0
	ctl $ST_TOP/schedtune.sched_boost_no_override 0
	Second=$((($RAM*6/100)*1024/4))
	Hidden=$((($RAM*7/100)*1024/4))
	content=$((($RAM*8/100)*1024/4))
	empty=$((($RAM*9/100)*1024/4))
	
	
	ctl $LMK/minfree "4096,5120,$Second,$Hidden,$content,$empty"
	kmsg "-------------------
	PERFORMANCE/MULTITASKING MODE ACTIVATED ~
	------------------------"
	# Sucess Message
	kmsg $(date) 
	kmsg "LAZY HAS EXECUTED TASK SUCCESSFULLY. ENJOY!" 
	vibrate_cmode
	};;
	# Battery Profile
        "2") {
rm $LOG        	
kmsg "-------------------
	BATTERY MODE STARTING ~
	------------------------"
#GPU Tunables     	
ctl /sys/class/kgsl/kgsl-3d0/devfreq/polling_interval 36
ctl /sys/class/kgsl/kgsl-3d0/idle_timer 72
ctl /sys/class/kgsl/kgsl-3d0/force_clk_on 0
ctl /sys/class/kgsl/kgsl-3d0/thermal_pwrlevel 3
ctl /sys/class/kgsl/kgsl-3d0/force_bus_on 0
ctl /sys/class/kgsl/kgsl-3d0/force_no_nap 0
ctl /sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost 2
ctl /sys/class/kgsl/kgsl-3d0/force_rail_on 0
ctl /sys/class/kgsl/kgsl-3d0/bus_split 1

for i in /sys/devices/system/cpu/cpu*/core_ctl
do
		# Tried to match this value to sched migrations
		ctl "${i}/busy_down_thres" 10
		# Tried to match this value to sched migrations
		ctl "${i}/busy_up_thres" 20
done

for queue in /sys/block/*/queue/
do
	# Choose the first governor available
	avail_scheds=`cat "${queue}scheduler"`
	for sched in cfq noop kyber bfq mq-deadline none
	do
		if [[ "$avail_scheds" == *"$sched"* ]]
		then
			ctl "${queue}scheduler" "$sched"
			break
		fi
	done
	# Disable I/O statistics accounting
	ctl "${queue}iostats" 0
	
	# Do not use I/O as a source of randomness
	ctl "${queue}add_random" 0
	
	# limit nr request for latency
	ctl "${queue}nr_requests" 64
	
	# Reduce read ahead for less overheads
	ctl "${queue}read_ahead_kb" 16
	
	#
	ctl "${queue}rq_affinity" 1
	
	ctl "${queue}nomerges" 2
	
done

ctl "$LMK/enable_lmk" "1"
ctl "$LMK/enable_adaptive_lmk" "1"

	ctl "$BOOST/input_boost_freq" 0:1600000
	ctl "$BOOST/input_boost_ms" 20
	ctl "$BOOST/sched_boost_on_input" 1
	
	for _ in $(seq 2)
	do

	# Migrate tasks down at this much load
	ctl $KERNEL/sched_downmigrate "100 100"
	ctl $KERNEL/sched_group_downmigrate 100
	ctl $KERNEL/sched_downmigrate_boosted "100 100"
	
	# Migrate tasks up at this much load
	ctl $KERNEL/sched_upmigrate "100 100"
	ctl $KERNEL/sched_group_upmigrate 100
	ctl $KERNEL/sched_upmigrate_boosted "100 100"
	done
	
	for EAS in /sys/devices/system/cpu/cpu*/cpufreq/
	do
	avail_govs=`cat "${EAS}scaling_available_governors"`
	if [[ "$avail_govs" == *"schedutil"* ]]
	then
		_ctl "${EAS}scaling_governor" schedutil
		ctl "${EAS}schedutil/up_rate_limit_us" 5000
		ctl "${EAS}schedutil/down_rate_limit_us" 25000
		ctl "${EAS}schedutil/rate_limit_us" 25000
		ctl "${EAS}schedutil/hispeed_load" 90
		ctl "${EAS}schedutil/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
		ctl "${EAS}schedutil/pl" 1
	elif [[ "$avail_govs" == *"interactive"* ]]
	then
		_ctl "${EAS}scaling_governor" interactive
		ctl "${EAS}interactive/min_sample_time" 25000
		ctl "${EAS}interactive/go_hispeed_load" 90
		ctl "${EAS}interactive/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
	fi
	done
	
	ctl $VM/vfs_cache_pressure 50
	ctl $VM/dirty_background_ratio 10
	ctl $VM/dirty_ratio 30
	ctl $VM/dirty_expire_centisecs 3000
	ctl $VM/dirty_writeback_centisecs 3000
	ctl $VM/extfrag_threshold 500
	
	# Pwrlvl of Adreno GPU (0 is max and 6 is less active)
	ctl /sys/class/kgsl/kgsl-3d0/max_pwrlevel 5
	ctl /sys/class/kgsl/kgsl-3d0/default_pwrlevel 5
	
	#TOP-APP
	ctl $ST_TOP/schedtune.boost 0
	ctl $ST_TOP/schedtune.colocate 0
	ctl $ST_TOP/schedtune.prefer_idle 0
	ctl $ST_TOP/schedtune.sched_boost_enabled 0
	ctl $ST_TOP/schedtune.sched_boost_no_override 0
	
	Second=$((($RAM*9/100)*1024/4))
	Hidden=$((($RAM*10/100)*1024/4))
	content=$((($RAM*11/100)*1024/4))
	empty=$((($RAM*12/100)*1024/4))
	
	ctl $LMK/minfree "4096,5120,$Second,$Hidden,$content,$empty"
	kmsg "-------------------
	BATTERY MODE ACTIVATED ~
	------------------------"
	# Sucess Message
	kmsg $(date) 
	kmsg "LAZY HAS EXECUTED TASK SUCCESSFULLY. ENJOY!" 
	vibrate_cmode
	};;
# Gaming Profile
        "3") {
#GPU Tunables
rm $LOG
kmsg "-------------------
	GAMING MODE STARTING ~
	------------------------"
ctl /sys/class/kgsl/kgsl-3d0/devfreq/polling_interval 0
ctl /sys/class/kgsl/kgsl-3d0/idle_timer 1000000
ctl /sys/class/kgsl/kgsl-3d0/force_clk_on 1
ctl /sys/class/kgsl/kgsl-3d0/thermal_pwrlevel 0
ctl /sys/class/kgsl/kgsl-3d0/force_bus_on 1
ctl /sys/class/kgsl/kgsl-3d0/force_no_nap 1
ctl /sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost 3
ctl /sys/class/kgsl/kgsl-3d0/force_rail_on 1
ctl /sys/class/kgsl/kgsl-3d0/bus_split 0

	
for i in /sys/devices/system/cpu/cpu*/core_ctl
do
		# Tried to match this value to sched migrations
		ctl "${i}/busy_down_thres" 10
		# Tried to match this value to sched migrations
		ctl "${i}/busy_up_thres" 20
done

for queue in /sys/block/*/queue/
do
	# Choose the first governor available
	avail_scheds=`cat "${queue}scheduler"`
	for sched in cfq noop kyber bfq mq-deadline none
	do
		if [[ "$avail_scheds" == *"$sched"* ]]
		then
			ctl "${queue}scheduler" "$sched"
			break
		fi
	done
	# Disable I/O statistics accounting
	ctl "${queue}iostats" 0
	
	# Do not use I/O as a source of randomness
	ctl "${queue}add_random" 0
	
	# limit nr request for latency
	ctl "${queue}nr_requests" 512
	
	# Reduce read ahead for less overheads
	ctl "${queue}read_ahead_kb" 1024
	
	# Force task completion
	ctl "${queue}rq_affinity" 2
	ctl "${queue}nomerges" 2
	
done

ctl "$LMK/enable_lmk" "1"
ctl "$LMK/enable_adaptive_lmk" "1"

	
	ctl "$BOOST/input_boost_freq" 0:1600000
	ctl "$BOOST/input_boost_ms" 250
	ctl "$BOOST/sched_boost_on_input" 1
	
	for _ in $(seq 2)
	do

	# Migrate tasks down at this much load
	ctl $KERNEL/sched_downmigrate "30 60"
	ctl $KERNEL/sched_group_downmigrate 60
	ctl $KERNEL/sched_downmigrate_boosted "30 60"
	
	# Migrate tasks up at this much load
	ctl $KERNEL/sched_upmigrate "80 90"
	ctl $KERNEL/sched_group_upmigrate 90
	ctl $KERNEL/sched_upmigrate_boosted "80 90"
	done
	
	for EAS in /sys/devices/system/cpu/cpu*/cpufreq/
	do
	avail_govs=`cat "${EAS}scaling_available_governors"`
	if [[ "$avail_govs" == *"schedutil"* ]]
	then
		_ctl "${EAS}scaling_governor" schedutil
		ctl "${EAS}schedutil/up_rate_limit_us" 1000
		ctl "${EAS}schedutil/down_rate_limit_us" 4000
		ctl "${EAS}schedutil/rate_limit_us" 4000
		ctl "${EAS}schedutil/hispeed_load" 90
		ctl "${EAS}schedutil/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
		ctl "${EAS}schedutil/pl" 1
	elif [[ "$avail_govs" == *"interactive"* ]]
	then
		_ctl "${EAS}scaling_governor" interactive
		ctl "${EAS}interactive/min_sample_time" 4000
		ctl "${EAS}interactive/go_hispeed_load" 90
		ctl "${EAS}interactive/hispeed_freq" `cat "${EAS}cpuinfo_max_freq"`
	fi
	done
	
	ctl $VM/vfs_cache_pressure 120
	ctl $VM/dirty_background_ratio 5
	ctl $VM/dirty_ratio 20
	ctl $VM/dirty_expire_centisecs 1000
	ctl $VM/dirty_writeback_centisecs 500
	ctl $VM/extfrag_threshold 750
	
	# Pwrlvl of Adreno GPU (0 is max and 6 is less active)
	ctl /sys/class/kgsl/kgsl-3d0/max_pwrlevel 0
	ctl /sys/class/kgsl/kgsl-3d0/default_pwrlevel 0
	#TOP-APP
	ctl $ST_TOP/schedtune.boost 5
	ctl $ST_TOP/schedtune.colocate 0
	ctl $ST_TOP/schedtune.prefer_idle 1
	ctl $ST_TOP/schedtune.sched_boost_enabled 1
	ctl $ST_TOP/schedtune.sched_boost_no_override 1
	Second=$((($RAM*7/100)*1024/4))
	Hidden=$((($RAM*8/100)*1024/4))
	content=$((($RAM*9/100)*1024/4))
	empty=$((($RAM*10/100)*1024/4))
	
	ctl $LMK/minfree "4096,5120,$Second,$Hidden,$content,$empty"
	kmsg "-------------------
	GAMING MODE ACTIVATED ~
	------------------------"
	# Sucess Message
	kmsg $(date) 
	kmsg "LAZY HAS EXECUTED TASK SUCCESSFULLY. ENJOY!" 
	vibrate_cmode
};;
esac
done
