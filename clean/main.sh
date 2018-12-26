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
    MD_DEVS=''
    md_name=''
    disk=''
    dev=''
    devlist=''
    tag=''
    tok cat /proc/mdstat
    for i in $(tok cat /proc/mdstat |grep "active" |awk '{print $1}');do

            tlog "md_name=/dev/$i"
            md_name="/dev/$i"
	    
	    dev=$(tok mdadm -D $md_name | egrep "spare|aulty|active|inactive" |  awk -F '[ ]' '{print $NF}' | sed 's/\/dev\///g')
	    devlist=$dev

            disk=$(tok mdadm -D $md_name | egrep "spare|faulty|active|inactive" |  awk -F '[ ]' '{print $NF}')
            MD_DEVS=$disk
	    tok echo $devlist
	    tok echo $MD_DEVS
	    tok echo $md_name


	    tlog "Clean $md_name"
            MD_RAID=$md_name
            tok umount $MD_RAID
            MD_Clean_RAID $MD_RAID


    done


            trun lsblk | grep loop*
            tag=$?
            if [ ${tag} -ne  0 ];then
                    local_remove
                    if [ $? -ne 0 ];then
                            tlog "MD clean done"
                    fi
            else
                    remove_disks "$devlist"
                    tlog lsblk | grep loop*
                    if [ $? -ne 0 ];then
                            tlog "disk remove done"
                    fi
            fi

    if [ $? -ne 0 ];then
	    exit 1
    fi


:'
    tlog "Clean $md_name"
            MD_RAID=$md_name
            tok umount $MD_RAID
            MD_Clean_RAID $MD_RAID

	    trun lsblk | grep loop*
	    tag=$?
	    if [ ${tag} -ne  0 ];then
		    local_remove
		    if [ $? -ne 0 ];then
			    tlog "MD clean done"
		    fi
	    else
		    remove_disks "$devlist"
		    tlog lsblk | grep loop*
		    if [ $? -ne 0 ];then
			    tlog "disk remove done"
		    fi
	    fi	    

           if [ $? -ne 0 ];then
		   exit 1
	   fi
'
   }


tlog "running $0"
trun "rpm -q gdisk || yum install -y gdisk"
trun "rpm -q mdadm || yum install -y mdadm"
trun "uname -a"
runtest

tend
