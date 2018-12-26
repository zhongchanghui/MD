#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /tests/kernel/storage/mdadm/trim-support
#   Description: test the function trim support.
#   Author: Xiao Ni <xni@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2011 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

# Include Storage related environment
. /mnt/tests/kernel/storage/mdadm/include/include.sh

function Stop_Raid (){
	tok mdadm --stop "$MD_RAID"
	if [ $? -ne 0 ]; then
		tlog "FAIL: fail to stop md raid $MD_RAID."
		exit 1
	fi
}

function runtest (){

	devlist=''
	disk_num=8
	#disk size M
	disk_size=3000
	cn=2048
	info=`uname -r| grep -o s390`
	if [ -n "$info" ]; then
		disk_size=2048
		cn=1024
	fi

	get_disks $disk_num $disk_size
	devlist=$RETURN_STR

#Change for journal support testing
	if [ "$JOURNAL_SUPPORT" = "1" ]; then
		journal_disk=`echo $devlist | cut -d ' ' -f 1`
		journal_disk="/dev/"$journal_disk
		firstdisk=`echo $devlist | cut -d ' ' -f 2`
		firstdisk="/dev/"$firstdisk
		RAID_LIST="4-j"
#		RAID_LIST="1 4 5 6 4-j 5-j 6-j 10"
	else
		firstdisk=`echo $devlist | cut -d ' ' -f 1`
		firstdisk="/dev/"$firstdisk
		RAID_LIST="1 5"
#		RAID_LIST="1 4 5 6 10"
	fi

	for level in $RAID_LIST; do

		RETURN_STR=''
		MD_RAID=''
		MD_DEV_LIST=''
		raid_num=4
		bitmap=1
		spare_num=0
		cnt=2

		if [[ $level =~ "j" ]]; then
			MD_Create_RAID_Journal ${level:0:1} "$devlist" $raid_num $bitmap $spare_num
		else
			MD_Create_RAID $level "$devlist" $raid_num $bitmap $spare_num
		fi

		if [ $? -ne 0 ];then
			tlog "FAIL: Failed to create md raid $RETURN_STR"
			break
		else
			tlog "INFO: Successfully created md raid $RETURN_STR"
		fi

		MD_RAID=$RETURN_STR

		MD_Get_State_RAID $MD_RAID

		state=$RETURN_STR

		while [[ $state != "active" && $state != "clean" ]]; do
			sleep 10
			MD_Get_State_RAID $MD_RAID
			state=$RETURN_STR
		done

		MD_Save_RAID

		tok "cat /etc/mdadm.conf"
		tok mdadm -D $MD_RAID
		trun "cat /proc/mdstat"
		tok "mdadm -D $MD_RAID"
		tlog "mdadm --wait $MD_RAID"
		mdadm --wait $MD_RAID
		tok "mdadm -D $MD_RAID"
	done

	if [ $? -ne 0 ];then
		exit 1
	fi
}

tlog "running $0"
trun "rpm -q mdadm || yum install -y mdadm"
trun "uname -a"
runtest

tend


