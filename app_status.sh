#!/bin/bash

# Get process status in process.cfg

# Define Variables
HOME_DIR="/home/robert/task_manager"
CONFIG_FILE="process.cfg"
this_pid=$$

if [ ! -e $HOME_DIR/$CONFIG_FILE ];then
    echo "$CONFIG_FILE is not exist"
    exit 1
fi


function get_all_group() {
     GROUP_LIST=`sed -n '/^\[GROUP\]/,/^\[.*\]/p' $HOME_DIR/$CONFIG_FILE | egrep -v "(^$|\[.*\]|^#)"`
     echo $GROUP_LIST
}

function get_all_process() {
    for group in `get_all_group`;do
        PROCESS_LIST=`sed -n "/^\[${group}\]/,/\[.*\]/p" $HOME_DIR/$CONFIG_FILE | egrep -v "(^$|\[.*\]|^#)" `
        echo $PROCESS_LIST
    done
}

function get_process_pid_by_name() {
    # return 1 if the number of parameters is not 1
    if [ $# -ne 1 ];then
        return 1
    else
        pids=`ps -ef | grep $1 | grep -v grep | grep -v $0 | awk '{print $2}'`
        echo ${pids}
    fi

}

function get_process_info_by_pid() {
    # 根据pid搜索进程是否在运行
    if [ `ps -ef | awk -v pid=$1 '$2==pid{print}' | wc -l ` -eq 1 ];then
        p_status="RUNNING"
    else
        p_status="STOPPED"
    fi
    
    p_cpu=`ps aux |awk -v pid=$1 '$2==pid{print $3}'`
    # mem utilization rate
    p_mem=`ps aux | awk -v pid=$1 '$2==pid{print $4}'`
    # 获取进程的启动时间
    p_start_time=`ps -p $1 -o lstart | egrep -v "STARTED"`
}

function printf_process_info_by_pid() {
    process_info=`get_process_info_by_pid $1`
    # printf "%-10s%-%-10s-%-10s-%-10s" $process_info
    printf "%-10s %-10s %-10s %-10s" $process_info
}

function printf_process_info_by_name() {
    pids=`get_process_pid_by_name $1`
    for pid in $pids;do
        printf_process_info_by_pid $pid
    done
}

function is_group_in_config() {
    # 判断组是否在GROUP中,如果在则返回1
    if [ $# -ne 1 ];then
        echo "the num of parameter must be 1"
        return 1
    fi
    
    declare -i flag=1
    for group in `get_all_group`;do
        if [ "$group" == "$1" ];then
            flag=0
        fi
    done
    
    return $flag
}

function is_process_in_config() {
    # 判断一个进程是否在config中
    # 接收参数 进程名
    for p_name in `get_all_process`;do
        if [ "$p_name" == "$1" ];then
            return 
        fi
    done
    echo "$1 is not exist in $HOME_DIR/$CONFIG_FILE"
    return 1 
}

function get_all_process_by_group() {
    is_group_in_config $1
    if [ $? -eq 0 ];then
        p_list=`sed -n "/^\[$1\]/,/\[.*\]/p" $HOME_DIR/$CONFIG_FILE | egrep -v "(^\[.*\]|^#|^$)"`   
        echo $p_list
    else
        echo "GroupName $1 is not in $HOME_DIR/$CONFIG_FILE"
    fi
}

function get_group_by_process_name() {
    is_process_in_config $1
    if [ $? -eq 0 ];then
        for group in `get_all_group`;do
            for p_name in `get_all_process_by_group $group`;do
                if [ "$p_name" == $1 ];then
                    echo $group
                fi
            done
        done
    else
        echo "$1 is not exist in $HOME_DIR/$CONFIG_FILE"
        exit 1
    fi

}

function format_print() {
    # 接收两个参数
    # $1 --> p_name
    # $2 --> g_name
    # 判断进程是否在运行中
    status=`ps -ef | grep $1 | grep -v grep | grep -v $this_pid | wc -l` 
    if [  $status -gt 0 ];then
        pids=`get_process_pid_by_name $1`
        for pid in $pids;do
            get_process_info_by_pid $pid
            awk -v p_name=$1 -v g_name=$2 -v p_status=$p_status -v p_cpu=$p_cpu \
                -v p_mem=$p_mem -v p_start_time="$p_start_time" -v pid=$pid\
                'BEGIN{printf "%-10s%-10s%-10s%-10s%-5s%-5s%-15s\n",p_name,g_name,p_status,pid,p_cpu,p_mem,p_start_time}' 
        done
    else
        awk -v p_name=$1 -v g_name=$2 'BEGIN{printf "%-10s%-10s%-10s%-10s%-5s%-5s%-15s\n",p_name,g_name,"NULL","NULL","NULL","NULL","NULL"}'
    fi
}

awk 'BEGIN{printf "%-10s%-10s%-10s%-10s%-5s%-5s%-15s\n","PROCESS","GROUP","STATUS","PID","CPU","MEM","STARTED"}'

if [ $# -gt 0 ];then
    if [ "$1" == "-g" ];then
        shift
        for group_name in $@;do
            for p_name in `get_all_process_by_group $group_name`;do
                format_print $p_name $group_name
            done
        done
    else
        for p_name in $@;do
            group_name=`get_group_by_process_name $p_name`
            format_print $p_name $group_name
        done
    fi
else
    for group_name in `get_all_group`;do
        for p_name in `get_all_process_by_group $group_name`;do
            format_print $p_name $group_name
        done
    done
fi
