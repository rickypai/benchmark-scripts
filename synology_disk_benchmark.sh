#!/usr/bin/env bash

# =======================================================================================
#
# A simple script to test Synology NAS disk speed with hdparm, dd and fio.
#
# How to use:
#
# sudo ./synology_disk_benchmark.sh
#
# Optionally save the output file with tee:
#
# sudo ./synology_disk_benchmark.sh 2>&1 | tee output.log
#
# =======================================================================================

# get the device of the current volume
volume=$(dirname "$PWD")
device=$(df $volume | tail -1 | awk '{ print $1 }')

echo "Running with device=${device}"
echo "Script version: $(git rev-parse HEAD)"
echo "hdparm version: $(hdparm -V)"
echo "dd version: $(dd --version | grep dd)"
echo "fio version: $(fio --version)"

./synology_system_info.sh

echo

# record the commands run
set -o xtrace

function cleanup {
	rm -f test
}

function clear_cache {
	sync
	echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
}

# runs a command 5 times with cache cleared
# example: `5times echo hi`
function 5times {
	for i in {1..5}; do
		$*
	done
}

function dd_read_tests {
	# read from test file, read 1 GiB each time, read 2 times, total read 2 GiB
	clear_cache && dd if=test of=/dev/null bs=1G count=2

	echo

	# read from test file, read 128 MiB each time, read 8 times, total read 1 GiB
	clear_cache && dd if=test of=/dev/null bs=128M count=8

	echo

	# read from test file, read 1 MiB each time, read 1024 times, total read 1 GiB
	clear_cache && dd if=test of=/dev/null bs=1M count=1024

	echo

	# read from test file, read 128 KiB each time, read 1024 times, total read 128 MiB
	clear_cache && dd if=test of=/dev/null bs=128k count=1024

	echo

	# read from test file, read 4 KiB each time, read 1024 times, total read 4 MiB
	clear_cache && dd if=test of=/dev/null bs=4k count=1024

	echo

	# read from test file, read 512 bytes each time, read 1024 times, total read 512 KiB
	clear_cache && dd if=test of=/dev/null bs=512 count=1024
}

function dd_write_tests {
	# write 0 to test file, write 1 GiB each time, write 2 times, total write 2 GiB
	clear_cache && dd if=/dev/zero of=test bs=1G count=2 oflag=dsync

	echo

	# write 0 to test file, write 128 MiB each time, write 8 times, total write 1 GiB
	clear_cache && dd if=/dev/zero of=test bs=128M count=8 oflag=dsync

	echo

	# write 0 to test file, write 1 MiB each time, write 1024 times, total write 1 GiB
	clear_cache && dd if=/dev/zero of=test bs=1M count=1024 oflag=dsync

	echo

	# write 0 to test file, write 128 KiB each time, write 1024 times, total write 128 MiB
	clear_cache && dd if=/dev/zero of=test bs=128k count=1024 oflag=dsync

	echo

	# write 0 to test file, write 4 KiB each time, write 1024 times, total write 4 MiB
	clear_cache && dd if=/dev/zero of=test bs=4k count=1024 oflag=dsync

	echo

	# write 0 to test file, write 512 bytes each time, write 1024 times, total write 512 KiB
	clear_cache && dd if=/dev/zero of=test bs=512 count=1024 oflag=dsync
}

function hdparm_read_timings {
	clear_cache

	# test read/cached read timings
	sudo hdparm -Tt $device
}

cleanup

if df | awk '{print $1}' | grep $(pwd); then
	# if drive, do read timings
	5times hdparm_read_timings
fi


echo

# create a 1 GiB test file with random data (it can take minutes)
time openssl rand -out test $(echo 1G | numfmt --from=iec)

echo

5times dd_read_tests

echo

5times dd_write_tests

echo

clear_cache

# run fio tests
fio xfio.conf

cleanup
