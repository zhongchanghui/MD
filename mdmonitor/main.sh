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
	mkdir /mnt/fortest

	which mkfs.xfs
	if [ $? -eq 0 ]; then
		FILESYS="xfs"
	else
		FILESYS="ext4"
	fi

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

#	tok ./createfile 64 2 "bigfile"
	tok dd if=/dev/urandom of=bigfile bs=1M count=$cn
	if [ $? -ne 0 ]; then
	      tlog "Create bigfile failed becasue $?"
	      exit 1;
	fi
	md5sum bigfile > md5sum1

	#Change for journal support testing
	if [ "$JOURNAL_SUPPORT" = "1" ]; then
		journal_disk=`echo $devlist | cut -d ' ' -f 1`
		journal_disk="/dev/"$journal_disk
		firstdisk=`echo $devlist | cut -d ' ' -f 2`
		firstdisk="/dev/"$firstdisk
		RAID_LIST="1 4 5 6 4-j 5-j 6-j 10"
	else
		firstdisk=`echo $devlist | cut -d ' ' -f 1`
		firstdisk="/dev/"$firstdisk
		RAID_LIST="1 4 5 6 10"
	fi

	for level in $RAID_LIST; do
		
		RETURN_STR=''
		MD_RAID=''
		MD_DEV_LIST=''
		raid_num=7
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
			sleep 5
			MD_Get_State_RAID $MD_RAID
			state=$RETURN_STR
		done

#		tok mkfs -t $FILESYS -f $MD_RAID
		
	 	tlog "mkfs -t $FILESYS -f $MD_RAID" 
	 	(mkfs -t $FILESYS -f $MD_RAID) || (mkfs -t $FILESYS  $MD_RAID)
	

		if [ ! -d /mnt/fortest ]; then
			mkdir /mnt/fortest
		fi
		tok mount -t $FILESYS $MD_RAID /mnt/fortest
		
		MD_Save_RAID
		echo "MAILADDR test@test.com" >> /etc/mdadm.conf
		tok "cat /etc/mdadm.conf"

		cat /etc/mdadm.conf |grep "MAILADDR"

		tok "grep ^Environ /lib/systemd/system/mdmonitor.service |grep mdmonitor"
		if [[ -f "/etc/sysconfig/mdmonitor" ]];then
			tok "rm -rf /etc/sysconfig/mdmonitor"
		fi

		tnot "ls /etc/sysconfig/mdmonitor"

		trun "systemctl status mdmonitor.service"

		tok "systemctl start mdmonitor.service"

		trun "systemctl status mdmonitor.service"


		echo  MDADM_MONITOR_ARGS='--syslog --scan -f --pid-file=/var/run/mdadm/mdadm.pid' > /etc/sysconfig/mdmonitor


		tok "systemctl restart mdmonitor.service"

		trun "systemctl status mdmonitor.service"

		tok "systemctl restart mdmonitor.service"

	

		while [ $cnt -ne 0 ]; do

			tok rm -rf /mnt/fortest/bigfile
			tok cp bigfile /mnt/fortest &
			sleep 5

			tok mdadm $MD_RAID -f $firstdisk
			sleep 5
			tok "dd if=/dev/zero of=/mnt/fortest/1.tar bs=1M count=100"
			trun "cat /proc/mdstat"
			trun mdadm $MD_RAID -r $firstdisk
			rt=$?
			tok "dd if=/mnt/fortest/1.tar of=/dev/null bs=1M count=100"
			rm_num=30
			while [ $rm_num -ne 0 ]; do
				if [ $rt -ne 0 ];then
					sleep 30
					trun mdadm $MD_RAID -r $firstdisk
					rt=$?
					((rm_num--))
				else
					break
				fi
			done
			sleep 60
			tok mdadm $MD_RAID -a $firstdisk

			#wait for cp file operation done
			num=`ps auxf | grep cp | grep bigfile | wc -l`
			while [ $num -ne 0 ]; do
				sleep 10
				num=`ps auxf | grep cp | grep bigfile | wc -l`
			done
			wait
			tlog "cp done"
			
			tok "mdadm -D $MD_RAID"
			

			#remove/add journal disk
			if [[ $level =~ "j" ]]; then
				sync
				tok mdadm -D $MD_RAID
				reco=`cat /proc/mdstat  | grep recovery`
				while [ -n "$reco" ]; do
					sleep 10
					reco=`cat /proc/mdstat  | grep recovery`
				done
				tlog "recovery done"
				tok umount -l $MD_RAID
				tok mdadm $MD_RAID -f $journal_disk
				sleep 5
				trun mdadm $MD_RAID -r $journal_disk
				rt=$?
				rm_num=30
				while [ $rm_num -ne 0 ]; do
					if [ $rt -ne 0 ];then
						sleep 30
						trun mdadm $MD_RAID -r $journal_disk
						rt=$?
						((rm_num--))
					else
						break
					fi
				done
				tok mdadm -o $MD_RAID
				rt=$?
				ro_num=30
				while [ $ro_num -ne 0 ]; do
					if [ $rt -ne 0 ];then
						sleep 30
						tok mdadm -o $MD_RAID
						rt=$?
						((ro_num--))
					else
						break
					fi
				done
				sleep 60
				tok mdadm $MD_RAID --add-journal $journal_disk

				#tok mdadm -I $journal_disk
				tok mount -t $FILESYS $MD_RAID /mnt/fortest
			fi
			tok mdadm -D $MD_RAID
			
			trun "cat /proc/mdstat"
			reco=`cat /proc/mdstat  | grep recovery`
			while [ -n "$reco" ]; do
				sleep 10
				reco=`cat /proc/mdstat  | grep recovery`
			done
			trun "cat /proc/mdstat"
			
			tok "mdadm -D $MD_RAID"
			tlog "mdadm --wait $MD_RAID"
			mdadm --wait $MD_RAID
			tok "mdadm -D $MD_RAID"
			tlog "recovery done"
		
			md5sum /mnt/fortest/bigfile > md5sum2
			tmp1=`awk '{print $1}' ./md5sum1`
			tmp2=`awk '{print $1}' ./md5sum2`
			echo $tmp1 > a
			echo $tmp2 > b
			tok diff a b 
			if [ $? -ne 0 ]; then
				tlog "There are some date interruption, cnt is $cnt" 
			fi

			cnt=$(($cnt-1))
		done

		tok umount $MD_RAID
		MD_Clean_RAID $MD_RAID
	done	
	
	remove_disks "$devlist"
	if [ $? -ne 0 ];then
		exit 1
	fi
}

tlog "running $0"
trun "rpm -q mdadm || yum install -y mdadm"
trun "uname -a"
runtest

tend
