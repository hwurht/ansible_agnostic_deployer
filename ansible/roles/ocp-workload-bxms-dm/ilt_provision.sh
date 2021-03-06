#!/bin/bash

END_PROJECT_NUM=1
START_PROJECT_NUM=1
WORKLOAD="ocp-workload-bxms-dm"
LOG_FILE=/tmp/$WORKLOAD

for var in $@
do
    case "$var" in
        --HOST_GUID=*) HOST_GUID=`echo $var | cut -f2 -d\=` ;;
        --START_PROJECT_NUM=*) START_PROJECT_NUM=`echo $var | cut -f2 -d\=` ;;
        --END_PROJECT_NUM=*) END_PROJECT_NUM=`echo $var | cut -f2 -d\=` ;;
        -h) HELP=true ;;
        -help) HELP=true ;;
    esac
done

function ensurePreReqs() {
    if [ "x$HOST_GUID" == "x" ]; then
            echo -en "must pass parameter: --HOST_GUID=<ocp host GUID> . \n\n"
            help
            exit 1;
    fi

    LOG_FILE=$LOG_FILE-$HOST_GUID-$START_PROJECT_NUM-$END_PROJECT_NUM.log
    echo -en "starting\n\n" > $LOG_FILE

    echo -en "\n\nProvision log file found at: $LOG_FILE\n";
}

function help() {
    echo -en "\n\nOPTIONS:";
    echo -en "\n\t--HOST_GUID=*             REQUIRED: specify GUID of target OCP environment)"
    echo -en "\n\t--START_PROJECT_NUM=*     OPTIONAL: specify # of first OCP project to provision (defult = 1))"
    echo -en "\n\t--END_PROJECT_NUM=*       OPTIONAL: specify # of OCP projects to provision (defualt = 1))"
    echo -en "\n\t-h                        this help manual"
    echo -en "\n\n\nExample:                ./roles/$WORKLOAD/ilt_provision.sh --HOST_GUID=dev39 --START_PROJECT_NUM=1 --END_PROJECT_NUM=1\n\n"
}


function login() {

    echo -en "\nHOST_GUID=$HOST_GUID\n" >> $LOG_FILE
    oc login https://master.$HOST_GUID.openshift.opentlc.com -u opentlc-mgr -p r3dh4t1!
}

function initializeOpenshift() {

    oc create -f https://raw.githubusercontent.com/jboss-container-images/rhdm-7-openshift-image/ose-v1.4.8-1/rhdm70-image-streams.yaml -n openshift
}


function executeLoop() {

    echo -en "\nexecuteLoop() START_PROJECT_NUM = $START_PROJECT_NUM ;  END_PROJECT_NUM=$END_PROJECT_NUM" >> $LOG_FILE

    for (( c=$START_PROJECT_NUM; c<=$END_PROJECT_NUM; c++ ))
    do
        GUID=$c
        OCP_USERNAME=user$c
        executeAnsible
    done
}

function executeAnsible() {
    TARGET_HOST="bastion.$HOST_GUID.openshift.opentlc.com"
    SSH_USERNAME="jbride-redhat.com"
    SSH_PRIVATE_KEY="id_ocp"

    # NOTE:  Ensure you have ssh'd (as $SSH_USERNMAE) into the bastion node of your OCP cluster environment at $TARGET_HOST and logged in using opentlc-mgr account:
    #           oc login https://master.$HOST_GUID.openshift.opentlc.com -u opentlc-mgr


    GUID=$PROJECT_PREFIX$GUID

    echo -en "\n\nexecuteAnsible():  Provisioning project with GUID = $GUID and OCP_USERNAME = $OCP_USERNAME\n" >> $LOG_FILE

    ansible-playbook -i ${TARGET_HOST}, ./configs/ocp-workloads/ocp-workload.yml \
                 -e"ansible_ssh_private_key_file=~/.ssh/${SSH_PRIVATE_KEY}" \
                 -e"ansible_ssh_user=${SSH_USERNAME}" \
                    -e"ANSIBLE_REPO_PATH=`pwd`" \
                    -e"ocp_username=${OCP_USERNAME}" \
                    -e"ocp_workload=${WORKLOAD}" \
                    -e"guid=${GUID}" \
                    -e"ocp_user_needs_quota=true" \
                    -e"ocp_apps_domain=apps.${HOST_GUID}.openshift.opentlc.com" \
                    -e"ACTION=create" >> $LOG_FILE
    if [ $? -ne 0 ];
    then
        echo -en "\n\n*** Error provisioning where GUID = $GUID\n\n " >> $LOG_FILE
        echo -en "\n\n*** Error provisioning where GUID = $GUID\n\n "
        exit 1;
    fi
}

ensurePreReqs
login
initializeOpenshift
executeLoop

