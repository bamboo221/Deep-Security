#!/bin/bash

ACTIVATIONURL='dsm://agents.workload.sg-1.cloudone.trendmicro.com:443/'
MANAGERURL='https://workload.sg-1.cloudone.trendmicro.com:443'
CURLOPTIONS='--silent --tlsv1.2'
linuxPlatform='';
isRPM='';

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo You are not running as the root user.  Please try again with root privileges.;
    logger -t You are not running as the root user.  Please try again with root privileges.;
    exit 1;
fi;

if ! type curl >/dev/null 2>&1; then
    echo "Please install CURL before running this script."
    logger -t Please install CURL before running this script
    exit 1
fi

# Detect Linux platform
platform='';  # platform for requesting package
runningPlatform='';   # platform of the running machine
majorVersion='';
platform_detect() {
 isRPM=1
 if !(type lsb_release &>/dev/null); then
    distribution=$(cat /etc/*-release | grep '^NAME' );
    release=$(cat /etc/*-release | grep '^VERSION_ID');
 else
    distribution=$(lsb_release -i | grep 'ID' | grep -v 'n/a');
    release=$(lsb_release -r | grep 'Release' | grep -v 'n/a');
 fi;
 if [ -z "$distribution" ]; then
    distribution=$(cat /etc/*-release);
    release=$(cat /etc/*-release);
 fi;

 releaseVersion=${release//[!0-9.]};
 case $distribution in
     *"Debian"*)
        platform='Debian_'; isRPM=0; runningPlatform=$platform;
        if [[ $releaseVersion =~ ^7.* ]]; then
           majorVersion='7';
        elif [[ $releaseVersion =~ ^8.* ]]; then
           majorVersion='8';
        elif [[ $releaseVersion =~ ^9.* ]]; then
           majorVersion='9';
        elif [[ $releaseVersion =~ ^10.* ]]; then
           majorVersion='10';
        elif [[ $releaseVersion =~ ^11.* ]]; then
           majorVersion='11';
        fi;
        ;;

     *"Ubuntu"*)
        platform='Ubuntu_'; isRPM=0; runningPlatform=$platform;
        if [[ $releaseVersion =~ ([0-9]+)\.(.*) ]]; then
           majorVersion="${BASH_REMATCH[1]}.04";
        fi;
        ;;

     *"SUSE"* | *"SLES"*)
        platform='SuSE_'; runningPlatform=$platform;
        if [[ $releaseVersion =~ ^11.* ]]; then
           majorVersion='11';
        elif [[ $releaseVersion =~ ^12.* ]]; then
           majorVersion='12';
        elif [[ $releaseVersion =~ ^15.* ]]; then
           majorVersion='15';
        fi;
        ;;

     *"Oracle"* | *"EnterpriseEnterpriseServer"*)
        platform='Oracle_OL'; runningPlatform=$platform;
        if [[ $releaseVersion =~ ^5.* ]]; then
           majorVersion='5'
        elif [[ $releaseVersion =~ ^6.* ]]; then
           majorVersion='6';
        elif [[ $releaseVersion =~ ^7.* ]]; then
           majorVersion='7';
        elif [[ $releaseVersion =~ ^8.* ]]; then
           majorVersion='8';
        fi;
        ;;

     *"CentOS"*)
        platform='RedHat_EL'; runningPlatform='CentOS_';
        if [[ $releaseVersion =~ ^5.* ]]; then
           majorVersion='5';
        elif [[ $releaseVersion =~ ^6.* ]]; then
           majorVersion='6';
        elif [[ $releaseVersion =~ ^7.* ]]; then
           majorVersion='7';
        elif [[ $releaseVersion =~ ^8.* ]]; then
           majorVersion='8';
        fi;
        ;;

     *"AlmaLinux"*)
        platform='RedHat_EL'; runningPlatform='AlmaLinux_';
        if [[ $releaseVersion =~ ^8.* ]]; then
           majorVersion='8';
        fi;
        ;;

     *"Rocky"*)
        platform='RedHat_EL'; runningPlatform='Rocky_';
        if [[ $releaseVersion =~ ^8.* ]]; then
           majorVersion='8';
        fi;
        ;;

     *"CloudLinux"*)
        platform='CloudLinux_'; runningPlatform=$platform;
        if [[ $releaseVersion =~ ([0-9]+)\.(.*) ]]; then
           majorVersion="${BASH_REMATCH[1]}";
        fi;
        ;;

     *"Amazon"*)
        platform='amzn'; runningPlatform=$platform;
        if [[ $(uname -r) == *"amzn2022"* ]]; then
           majorVersion='2022';
        elif [[ $(uname -r) == *"amzn2"* ]]; then
           majorVersion='2';
        elif [[ $(uname -r) == *"amzn1"* ]]; then
           majorVersion='1';
        fi;
        ;;

     *"RedHat"* | *"Red Hat"*)
        platform='RedHat_EL'; runningPlatform=$platform;
        if [[ $releaseVersion =~ ^5.* ]]; then
           majorVersion='5';
        elif [[ $releaseVersion =~ ^6.* ]]; then
           majorVersion='6';
        elif [[ $releaseVersion =~ ^7.* ]]; then
           majorVersion='7';
        elif [[ $releaseVersion =~ ^8.* ]]; then
           majorVersion='8';
        elif [[ $releaseVersion =~ ^9.* ]]; then
           majorVersion='9';
        fi;
        ;;

 esac

 if [[ -z "${platform}" ]] || [[ -z "${majorVersion}" ]]; then
    echo Unsupported platform is detected
    logger -t Unsupported platform is detected
    false
 else
    archType='i386'; architecture=$(arch);
    platforms32Bit=("RedHat_EL5", "RedHat_EL6", "Oracle_OL5", "Oracle_OL6", "SuSE_10", "SuSE_11", "CloudLinux_5")
    if [[ ${architecture} == *"x86_64"* ]]; then
       archType='x86_64';
    elif [[ ${architecture} == *"aarch64"* ]]; then
       archType='aarch64';
    fi

    if [[ ${archType} == 'i386' ]] && [[ ! ${platforms32Bit[*]} =~ "${platform}${majorVersion}" ]]; then
       echo Unsupported architecture is detected
       logger -t Unsupported architecture is detected
       exit 1
    fi

    linuxPlatform="${platform}${majorVersion}/${archType}/";
 fi
}

platform_detect
if [[ -z "${linuxPlatform}" ]] || [[ -z "${isRPM}" ]]; then
    echo Unsupported platform is detected
    logger -t Unsupported platform is detected
    exit 1
fi

if [[ ${linuxPlatform} == *"SuSE_15"* ]]; then
    if ! type pidof &> /dev/null || ! type start_daemon &> /dev/null || ! type killproc &> /dev/null; then
        echo Please install sysvinit-tools before running this script
        logger -t Please install sysvinit-tools before running this script
        exit 1
    fi
fi

echo Downloading agent package...
if [[ $isRPM == 1 ]]; then package='agent.rpm'
    else package='agent.deb'
fi
curl -H "Agent-Version-Control: on" -L $MANAGERURL/software/agent/${runningPlatform}${majorVersion}/${archType}/$package?tenantID=7098 -o /tmp/$package $CURLOPTIONS

echo Installing agent package...
rc=1
if [[ $isRPM == 1 && -s /tmp/agent.rpm ]]; then
    output=$(rpm --checksig /tmp/agent.rpm)
    rc=$?
    if [[ ${rc} != 0 ]] || [[ ${output} != *"pgp"* &&  ${output} != *"signatures"* ]]; then
        echo The digital signature on the agent installer is invalid.
        exit 1
    fi
    rpm -ihv /tmp/agent.rpm
    rc=$?
elif [[ -s /tmp/agent.deb ]]; then
    output=$(dpkg-sig --verify /tmp/agent.deb)
    rc=$?
    if [[ ${rc} != 0 ]] || [[ ${output} != *"GOODSIG"* ]] ; then
        echo The digital signature on the agent installer is invalid.
        exit 1
    fi
    dpkg -i /tmp/agent.deb
    rc=$?
else
    echo Failed to download the agent package. Please make sure the package is imported in the Workload Security Manager
    logger -t Failed to download the agent package. Please make sure the package is imported in the Workload Security Manager
    exit 1
fi
if [[ ${rc} != 0 ]]; then
    echo Failed to install the agent package
    logger -t Failed to install the agent package
    exit 1
fi

echo Install the agent package successfully

sleep 15
/opt/ds_agent/dsa_control -r
/opt/ds_agent/dsa_control -a $ACTIVATIONURL "tenantID:FB84FBA1-2067-284B-17DB-FC80AE5C9A46" "token:650CB95F-4D3A-D601-5FBD-8743CAA158B5" "policyid:2"
# /opt/ds_agent/dsa_control -a dsm://agents.workload.sg-1.cloudone.trendmicro.com:443/ "tenantID:FB84FBA1-2067-284B-17DB-FC80AE5C9A46" "token:650CB95F-4D3A-D601-5FBD-8743CAA158B5" "policyid:2"