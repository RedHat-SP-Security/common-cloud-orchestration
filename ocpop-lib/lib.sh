#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Description: Common cloud orchestration library for operator test suites
#   Authors: Sergio Arroutbi <sarroutb@redhat.com>
#            Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc.
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
#   library-prefix = ocpop
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Directory where the lib is located.
ocpopLibDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export ocpopLibDir

# Timeout durations in seconds
EXECUTION_MODE=
TO_WGET_CONNECTION=10 #seconds
export TO_WGET_CONNECTION
ADV_PATH="adv"

#Set up in tests
TO_POD_START=120 #seconds
TO_POD_STOP=120 #seconds
TO_SERVICE_START=120 #seconds
TO_SERVICE_STOP=120 #seconds

# Default OpenShift client (kubectl)
OC_DEFAULT_CLIENT="kubectl"

# Operator configuration
[ -n "$OPERATOR_NAME" ] || OPERATOR_NAME="unknown-helm-based-operator"
[ -n "${HELM_IMAGE_VERSION}" ] || HELM_IMAGE_VERSION="oci://quay.io/sec-eng-special/unknown-helm-image"

# Additional configurations
test -z "${VERSION}" && VERSION="latest"
test -z "${DISABLE_HELM_INSTALL_TESTS}" && DISABLE_HELM_INSTALL_TESTS="0"
test -z "${DISABLE_HELM_UNINSTALL_TESTS}" && DISABLE_HELM_UNINSTALL_TESTS="0"
test -n "${DOWNSTREAM_IMAGE_VERSION}" && {
    test -z "${OPERATOR_NAMESPACE}" && OPERATOR_NAMESPACE="openshift-operators"
}
[ -n "$OPERATOR_NAMESPACE" ] || OPERATOR_NAMESPACE="default"

# Required setup for script, installing required packages
if [ -z "${TEST_OC_CLIENT}" ];
then
    OC_CLIENT="${OC_DEFAULT_CLIENT}"
else
    OC_CLIENT="${TEST_OC_CLIENT}"
fi

# Test can runs on different types of clusters.
if [ -z "${TEST_EXTERNAL_CLUSTER_MODE}" ];
then
    if [ -n "${TEST_CRC_MODE}" ];
    then
        EXECUTION_MODE="CRC"
    else
        EXECUTION_MODE="MINIKUBE"
    fi
else
        EXECUTION_MODE="CLUSTER"
fi

# Internal temporary directory
export __INTERNAL_ocpopTmpDir
[ -n "$__INTERNAL_ocpopTmpDir" ] || __INTERNAL_ocpopTmpDir="/var/tmp/ocpopLib"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head2 ocpopLogVerbose

Log a verbose message if the V or VERBOSE variable is set.

    ocpopLogVerbose

=over

=back

Returns 0.

=cut

ocpopLogVerbose() {
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        rlLog "${1}"
    fi
}

true <<'=cut'
=pod

=head2 ocpopCommandVerbose

Execute a command in verbose mode if the V or VERBOSE variable is set.

    ocpopCommandVerbose

=over

=back

Returns 0.

=cut

ocpopCommandVerbose() {
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        $*
    fi
}

true <<'=cut'
=pod

=head2 ocpopDumpDate

Log the current date.

    ocpopDumpDate

=over

=back

Returns 0.

=cut

ocpopDumpDate() {
    rlLog "DATE:$(date)"
}

true <<'=cut'
=pod

=head2 ocpopDumpInfo

Log various system information about hostname, version of OS, version of images and etc.

    ocpopDumpInfo

=over

=back

Returns 0.

=cut

ocpopDumpInfo() {
    rlLog "HOSTNAME:$(hostname)"
    rlLog "RELEASE:$(cat /etc/redhat-release)"
    test -n "${DOWNSTREAM_IMAGE_VERSION}" && {
        rlLog "DOWNSTREAM_IMAGE_VERSION:${DOWNSTREAM_IMAGE_VERSION}"
    } || rlLog "IMAGE_VERSION:${IMAGE_VERSION}"
    rlLog "OPERATOR NAMESPACE:${OPERATOR_NAMESPACE}"
    #TANG LIB ADD
    rlLog "DISABLE_BUNDLE_INSTALL_TESTS:${DISABLE_BUNDLE_INSTALL_TESTS}"
    rlLog "DISABLE_HELM_INSTALL_TESTS:${DISABLE_HELM_INSTALL_TESTS}"
    rlLog "OC_CLIENT:${OC_CLIENT}"
    #TANG LIB ADD
    rlLog "RUN_BUNDLE_PARAMS:${RUN_BUNDLE_PARAMS}"
    rlLog "EXECUTION_MODE:${EXECUTION_MODE}"
    rlLog "ID:$(id)"
    rlLog "WHOAMI:$(whoami)"
    rlLog "vvvvvvvvv IP vvvvvvvvvv"
    ip a | grep 'inet '
    rlLog "^^^^^^^^^ IP ^^^^^^^^^^"
}

true <<'=cut'
=pod

=head2 ocpopMinikubeInfo

Log Minikube-specific information.

    ocpopMinikubeInfo

=over

=back

Returns 0.

=cut

ocpopMinikubeInfo() {
    rlLog "MINIKUBE IP:$(minikube ip)"
    rlLog "vvvvvvvvvvvv MINIKUBE STATUS vvvvvvvvvvvv"
    minikube status
    rlLog "^^^^^^^^^^^^ MINIKUBE STATUS ^^^^^^^^^^^^"
    rlLog "vvvvvvvvvvvv MINIKUBE SERVICE LIST vvvvvvvvvvvv"
    minikube service list
    rlLog "^^^^^^^^^^^^ MINIKUBE SERVICE LIST ^^^^^^^^^^^^"
}

true <<'=cut'
=pod

=head2 ocpopCheckClusterStatus

Check the status of the OpenShift cluster.

    ocpopCheckClusterStatus

=over

=back

Returns 0 if the cluster is up and running otherwise non-exit code.

=cut

ocpopCheckClusterStatus() {
    if [ "${EXECUTION_MODE}" == "CRC" ];
    then
        rlRun "crc status | grep OpenShift | awk -F ':' '{print $2}' | awk '{print $1}' | grep -i Running" 0 "Checking Code Ready Containers up and running"
    elif [ "${EXECUTION_MODE}" == "MINIKUBE" ];
    then
        rlRun "minikube status" 0 "Checking Minikube status"
    else
        if [ "${OC_CLIENT}" != "oc" ];
        then
            return 0
        fi
        rlRun "${OC_CLIENT} status" 0 "Checking cluster status"
    fi
    return $?
}

true <<'=cut'
=pod

=head2 ocpopCheckAtLeastPodAmount

Check if the number of pods in a namespace is at least the expected amount.

    ocpopCheckAtLeastPodAmount expected iterations namespace

=over

=item

    expected - Expected pod amount.

=item

    iterations - Number of iterations to checking state.

=item

    namespace - Namespace where is pod.

=back

Returns 0 when the check was successful, 1 otherwise.

=cut

ocpopCheckAtLeastPodAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        POD_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get pods | grep -v "^NAME" -c)
        ocpopLogVerbose "POD AMOUNT:${POD_AMOUNT} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
        if [ ${POD_AMOUNT} -ge ${expected} ]; then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopCheckPodAmount

Check if the number of pods in a namespace is the expected amount.

    ocpopCheckPodAmount expected iterations namespace

=over

=item

    expected - Expected pod amount.

=item

    iterations - Number of iterations to check state before failing.

=item

    namespace - Namespace where pod runs.

=back

Returns 0 when the check was successful, 1 otherwise.

=cut

ocpopCheckPodAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        POD_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get pods | grep -v "^NAME" -c)
        ocpopLogVerbose "POD AMOUNT:${POD_AMOUNT} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
        if [ ${POD_AMOUNT} -eq ${expected} ]; then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopCheckPodKilled

Checks if a pod is killed.

    ocpopCheckPodKilled pod_name namespace iterations

=over

=item

    pod_name - Name of pod.

=item

    namespace - Namespace where is pod.

=item

    iterations - Number of iterations to checking state.

=back

Returns 0 when  is verifyied successful termination of pod, 1 otherwise.

=cut

ocpopCheckPodKilled() {
    local pod_name=$1
    local namespace=$2
    local iterations=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
            "${OC_CLIENT}" -n "${namespace}" get pod "${pod_name}"
        else
            "${OC_CLIENT}" -n "${namespace}" get pod "${pod_name}" 2>/dev/null 1>/dev/null
        fi
        if [ $? -ne 0 ]; then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopCheckPodState

Checks if a pod is in the expected state.

    ocpopCheckPodState expected iterations namespace podname error_state

=over

=item

    expected - Expected pod state.

=item

    iterations - Number of iterations to checking state.

=item

    namespace - Namespace where is pod.

=item

    podname - Name of pod.

=item

    error_state - Error state of pod.

=back

Returns 0 when check in expected state, 1 otherwise.

=cut

ocpopCheckPodState() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local podname=$4
    local error_state=$5
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      pod_status=$("${OC_CLIENT}" -n "${namespace}" get pod "${podname}" | grep -v "^NAME" | awk '{print $3}')
      ocpopLogVerbose "POD STATUS:${pod_status} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
      if [ "${pod_status}" == "${expected}" ]; then
        return 0
      elif [ "${pod_status}" == "${error_state}" ]; then
        return 1
      fi
      counter=$((counter+1))
      sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopCheckPodStateAndContinues

Checks if a pod is in the expected state and continues to be in that state.

    ocpopCheckPodStateAndContinues expected iterations namespace podname

=over

=item

    expected - Expected pod state.

=item

    iterations - Number of iterations to check pod state without changes.

=item

    namespace - Namespace where pod runs.

=item

    podname - Name of pod.

=back

Returns 0 when check in expected state, 1 otherwise.

=cut

ocpopCheckPodStateAndContinues() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local podname=$4
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      pod_status=$("${OC_CLIENT}" -n "${namespace}" get pod "${podname}" | grep -v "^NAME" | awk '{print $3}')
      ocpopLogVerbose "POD STATUS:${pod_status} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
      if [ "${pod_status}" != "${expected}" ]; then
        return 1
      fi
      counter=$((counter+1))
      sleep 1
    done
    return 0
}

true <<'=cut'
=pod

=head2 ocpopCheckServiceAmount

Checks if the number of services in a namespace is equal to the expected amount.

    ocpopCheckServiceAmount expected iterations namespace

=over

=item

    expected - Expected service amount.

=item

    iterations - Number of iterations for checking service amount.

=item

    namespace - Namespace where is pod.

=back

Returns 0 when check is successful, 1 otherwise.

=cut


ocpopCheckServiceAmount() {
    local expected=$1
    local iterations=$2
    local namespace=$3
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        SERVICE_AMOUNT=$("${OC_CLIENT}" -n "${namespace}" get services | grep -v "^NAME" -c)
        ocpopLogVerbose "SERVICE AMOUNT:${SERVICE_AMOUNT} EXPECTED:${expected} COUNTER:${counter}/${iterations}"
        if [ ${SERVICE_AMOUNT} -eq ${expected} ]; then
            return 0
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopCheckServiceUp

Checks if a service is up.

    ocpopCheckServiceUp service_ip_host service_ip_port iterations

=over

=item

    service_ip_host - Service IP host.

=item

    service_ip_port - Service IP port.

=item

    iterations - Number of iterations in seconds for checking if service is up.

=back

Returns 0 when service is up, 1 otherwise.

=cut

ocpopCheckServiceUp() {
    local service_ip_host=$1
    local service_ip_port=$2
    local iterations=$3
    local counter
    local http_service="http://${service_ip_host}:${service_ip_port}/adv"
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
        if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
            wget -O /dev/null -o /dev/null --timeout=${TO_WGET_CONNECTION} ${http_service}
        else
            wget -O /dev/null -o /dev/null --timeout=${TO_WGET_CONNECTION} ${http_service} 2>/dev/null 1>/dev/null
        fi
        if [ $? -eq 0 ]; then
            return 0
        fi
        counter=$((counter+1))
        ocpopLogVerbose "WAITING SERVICE:${http_service} UP, COUNTER:${counter}/${iterations}"
        sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopGetPodNameWithPartialName

Gets the full pod name with a partial name.

    ocpopGetPodNameWithPartialName partial_name namespace iterations

=over

=item

    partial_name - Partial Name of pod.

=item

    namespace - Namespace where are Pods.

=item

    iterations - Number of iterations in seconds for get pod.

=back

Returns 0 when the get pod was successful, 1 otherwise.

=cut

ocpopGetPodNameWithPartialName() {
    local partial_name=$1
    local namespace=$2
    local iterations=$3
    local tail_position=$4
    test -z "${tail_position}" && tail_position=1
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      local pod_line
      pod_line=$("${OC_CLIENT}" -n "${namespace}" get pods | grep -v "^NAME" | grep "${partial_name}" | tail -${tail_position} | head -1)
      ocpopLogVerbose "POD LINE:[${pod_line}] POD NAME:[${partial_name}] COUNTER:[${counter}/${iterations}]"
      if [ "${pod_line}" != "" ]; then
          echo "${pod_line}" | awk '{print $1}'
          ocpopLogVerbose "FOUND POD name:[$(echo ${pod_line} | awk '{print $1}')] POD NAME:[${partial_name}] COUNTER:[${counter}/${iterations}]"
          return 0
      else
          counter=$((counter+1))
          sleep 1
      fi
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopGetServiceNameWithPrefix

Gets the full service name with a prefix.

    ocpopGetServiceNameWithPrefix partial_name namespace iterations tail_position

=over

=item

    partial_name - Partial Name of pod.

=item

    namespace - Namespace where are services.

=item

    iterations - Number of iterations in seconds for get service.

=back

Returns 0 when get service was successful, 1 otherwise.

=cut


ocpopGetServiceNameWithPrefix() {
    local prefix=$1
    local namespace=$2
    local iterations=$3
    local tail_position=$4
    test -z "${tail_position}" && tail_position=1
    local counter
    counter=0
    while [ ${counter} -lt ${iterations} ];
    do
      local service_name
      service_name=$("${OC_CLIENT}" -n "${namespace}" get services | grep -v "^NAME" | grep "${prefix}" | tail -${tail_position} | head -1)
      ocpopLogVerbose "SERVICE NAME:[${service_name}] COUNTER:[${counter}/${iterations}]"
      if [ "${service_name}" != "" ]; then
          ocpopLogVerbose "FOUND SERVICE name:[$(echo ${service_name} | awk '{print $1}')] POD PREFIX:[${prefix}] COUNTER:[${counter}/${iterations}]"
          echo "${service_name}" | awk '{print $1}'
          return 0
      else
          counter=$((counter+1))
          sleep 1
      fi
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopGetServiceIp

 Gets the IP address/host of a service.

    ocpopGetServiceIp service_name namespace iterations

=over

=item

    service_name - Name of service.

=item

    namespace - Namespace where are services.

=item

    iterations - Number of iterations in seconds for get service IP.

=back

Returns 0 when getting service ip was successful, 1 otherwise.

=cut

ocpopGetServiceIp() {
    local service_name=$1
    local namespace=$2
    local iterations=$3
    counter=0
    ocpopLogVerbose "Getting SERVICE:[${service_name}](Namespace:[${namespace}]) IP/HOST ..."
    if [ ${EXECUTION_MODE} == "CRC" ];
    then
        local crc_service_ip
        crc_service_ip=$(crc ip)
        ocpopLogVerbose "CRC MODE, SERVICE IP/HOST:[${crc_service_ip}]"
        echo "${crc_service_ip}"
        return 0
    elif [ ${EXECUTION_MODE} == "MINIKUBE" ];
    then
        local minikube_service_ip
        minikube_service_ip=$(minikube ip)
        ocpopLogVerbose "MINIKUBE MODE, SERVICE IP/HOST:[${minikube_service_ip}]"
        echo "${minikube_service_ip}"
        return 0
    fi
    while [ ${counter} -lt ${iterations} ];
    do
        local service_ip
        service_ip=$("${OC_CLIENT}" -n "${namespace}" describe service "${service_name}" | grep -i "LoadBalancer Ingress:" | awk -F ':' '{print $2}' | tr -d ' ')
        ocpopLogVerbose "SERVICE IP/HOST:[${service_ip}](Namespace:[${namespace}])"
        if [ -n "${service_ip}" ] && [ "${service_ip}" != "<pending>" ];
        then
            echo "${service_ip}"
            return 0
        else
            ocpopLogVerbose "PENDING OR EMPTY IP/HOST:[${service_ip}], COUNTER[${counter}/${iterations}]"
        fi
        counter=$((counter+1))
        sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopGetServicePort

Gets the port of a service.


    ocpopGetServicePort service_name namespace

=over

=item

    service_name - Name of service.

=item

    namespace - Namespace where are services.

=back

Returns 0 when getting service port was successful, 1 otherwise.


=cut

ocpopGetServicePort() {
    local service_name=$1
    local namespace=$2
    local service_port
    ocpopLogVerbose "Getting SERVICE:[${service_name}](Namespace:[${namespace}]) PORT ..."
    if [ ${EXECUTION_MODE} == "CLUSTER" ];
    then
        service_port=$("${OC_CLIENT}" -n "${namespace}" get service "${service_name}" | grep -v ^NAME | awk '{print $5}' | awk -F ':' '{print $1}')
    else
        service_port=$("${OC_CLIENT}" -n "${namespace}" get service "${service_name}" | grep -v ^NAME | awk '{print $5}' | awk -F ':' '{print $2}' | awk -F '/' '{print $1}')
    fi
    result=$?
    ocpopLogVerbose "SERVICE PORT:[${service_port}](Namespace:[${namespace}])"
    echo "${service_port}"
    return ${result}
}

true <<'=cut'
=pod

=head2 ocpopServiceAdv

Performs a service advertisement.

    ocpopServiceAdv ip port

=over

=item

    ip - IP address of service.

=item

    port - Port of service.

=back

Returns 0.

=cut

ocpopServiceAdv() {
    ip=$1
    port=$2
    URL="http://${ip}:${port}/${ADV_PATH}"
    local file
    file=$(mktemp)
    ### wget
    COMMAND="wget ${URL} --timeout=${TO_WGET_CONNECTION} -O ${file} -o /dev/null"
    ocpopLogVerbose "CONNECTION_COMMAND:[${COMMAND}]"
    ${COMMAND}
    wget_res=$?
    ocpopLogVerbose "WGET RESULT:$(cat ${file})"
    JSON_ADV=$(cat "${file}")
    ocpopLogVerbose "CONNECTION_COMMAND:[${COMMAND}],RESULT:[${wget_res}],JSON_ADV:[${JSON_ADV}])"
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        jq . -M -a < "${file}"
    else
        jq . -M -a < "${file}" 2>/dev/null
    fi
    jq_res=$?
    rm "${file}"
    return $((wget_res+jq_res))
}

true <<'=cut'
=pod

=head2 ocpopServiceAdvCompare

Comparing a service advertisement.

    ocpopServiceAdvCompare ip port ip2 port2

=over

=item

    ip - IP address of service.

=item

    port - Port of service.

=item

    ip - IP address of service.

=back

Returns 0.

=cut

ocpopServiceAdvCompare() {
    local ip=$1
    local port=$2
    local ip2=$3
    local port2=$4
    local url
    url="http://${ip}:${port}/${ADV_PATH}"
    local url2
    url2="http://${ip2}:${port2}/${ADV_PATH}"
    local jq_equal=1
    local file1
    local file2
    file1=$(mktemp)
    file2=$(mktemp)
    local jq_json_file1
    local jq_json_file2
    jq_json_file1=$(mktemp)
    jq_json_file2=$(mktemp)
    local command1
    command1="wget ${url} --timeout=${TO_WGET_CONNECTION} -O ${file1} -o /dev/null"
    local command2
    command2="wget ${url2} --timeout=${TO_WGET_CONNECTION} -O ${file2} -o /dev/null"
    ocpopLogVerbose "CONNECTION_COMMAND:[${command1}]"
    ocpopLogVerbose "CONNECTION_COMMAND:[${command2}]"
    ${command1}
    wget_res1=$?
    ${command2}
    wget_res2=$?
    ocpopLogVerbose "CONNECTION_COMMAND:[${command1}],RESULT:[${wget_res1}],json_adv:[$(cat ${file1})]"
    ocpopLogVerbose "CONNECTION_COMMAND:[${command2}],RESULT:[${wget_res2}],json_adv:[$(cat ${file2})]"
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        jq . -M -a < "${file1}" 2>&1 | tee "${jq_json_file1}"
    else
        jq . -M -a < "${file1}" > "${jq_json_file1}"
    fi
    jq_res1=$?
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ]; then
        jq . -M -a < "${file2}" 2>&1 | tee "${jq_json_file2}"
    else
        jq . -M -a < "${file2}" > "${jq_json_file2}"
    fi
    jq_res2=$?
    rlAssertDiffer "${jq_json_file1}" "${jq_json_file2}"
    jq_equal=$?
    rm "${jq_json_file1}" "${jq_json_file2}"
    return $((wget_res1+wget_res2+jq_res1+jq_res2+jq_equal))
}

true <<'=cut'
=pod

=head2 ocpopCheckStatusRunningReplicas

Checking status of running pod replicas.

    ocpopCheckStatusRunningReplicas expected namespace iterations pod_name

=over

=item

    expected - Expected state of pod.

=item

    namespace - Namespace where are services.

=item

    Iterations - Number of provided iterations.

=item

    pod_name - Name of pod.

=back

Returns 0.

=cut

ocpopCheckStatusRunningReplicas() {
    local counter
    counter=0
    local expected=$1
    local namespace=$2
    local iterations=$3
    local pod_name=$4
    while [ ${counter} -lt ${iterations} ];
    do
      local running
      #generalize tangserver
      running=$("${OC_CLIENT}" -n "${namespace}" get "${pod_name}" -o json | jq '.items[0].status.running | length')
      ocpopLogVerbose "Status Running Replicas: Expected:[${expected}], Running:[${running}]"
      if [ ${expected} -eq ${running} ];
      then
          return 0
      fi
      counter=$((counter+1))
      sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopCheckStatusReadyReplicas

Checking status of  status ready pod replicas.

    ocpopCheckStatusReadyReplicas expected namespace iterations pod_name

=over

=item

    expected - Expected state of pod.

=item

    namespace - Namespace where are services.

=item

    Iterations - Number of provided iterations.

=item

    pod_name - Name of pod.

=back

Returns 0.

=cut

ocpopCheckStatusReadyReplicas() {
    local counter
    counter=0
    local expected=$1
    local namespace=$2
    local iterations=$3
    local pod_name=$4
    while [ ${counter} -lt ${iterations} ];
    do
      local ready
      #generalize tangserver
      ready=$("${OC_CLIENT}" -n "${namespace}" get "${pod_name}" -o json | jq '.items[0].status.ready | length')
      ocpopLogVerbose "Status Ready Replicas: Expected:[${expected}], Ready:[${ready}]"
      if [ ${expected} -eq ${ready} ];
      then
          return 0
      fi
      counter=$((counter+1))
      sleep 1
    done
    return 1
}

true <<'=cut'
=pod

=head2 ocpopGetPodCpuRequest

Checking cpu status of required pod.

    ocpopGetPodCpuRequest pod_name namespace

=over

=item

    pod_name - Expected state of pod.

=item

    namespace - Namespace where are services.

=back

Returns 0.

=cut

ocpopGetPodCpuRequest() {
    local pod_name=$1
    local namespace=$2
    ocpopLogVerbose "Getting POD:[${pod_name}](Namespace:[${namespace}]) CPU Request ..."
    local cpu
    cpu=$("${OC_CLIENT}" -n "${namespace}" describe pod "${pod_name}" | grep -i Requests -A2 | grep 'cpu' | awk -F ":" '{print $2}' | tr -d ' ' | tr -d "[A-Z,a-z]")
    ocpopLogVerbose "CPU REQUEST COMMAND:["${OC_CLIENT}" -n "${namespace}" describe pod ${pod_name} | grep -i Requests -A2 | grep 'cpu' | awk -F ':' '{print $2}' | tr -d ' ' | tr -d \"[A-Z,a-z]\""
    ocpopLogVerbose "POD:[${pod_name}](Namespace:[${namespace}]) CPU Request:[${cpu}]"
    echo "${cpu}"
}

true <<'=cut'
=pod

=head2 ocpopGetPodMemRequest

Checking memory status of required pod.

    ocpopGetPodMemRequest pod_name namespace

=over

=item

    pod_name - Name of pod.

=item

    namespace - Namespace where are services.

=back

Returns 0.

=cut

ocpopGetPodMemRequest() {
    local pod_name=$1
    local namespace=$2
    ocpopLogVerbose "Getting POD:[${pod_name}](Namespace:[${namespace}]) MEM Request ..."
    local mem
    mem=$("${OC_CLIENT}" -n "${namespace}" describe pod "${pod_name}" | grep -i Requests -A2 | grep 'memory' | awk -F ":" '{print $2}' | tr -d ' ')
    local unit
    unit="${mem: -1}"
    local mult
    mult=1
    case "${unit}" in
        K|k)
            mult=1024
            ;;
        M|m)
            mult=$((1024*1024))
            ;;
        G|g)
            mult=$((1024*1024*1024))
            ;;
        T|t)
            mult=$((1024*1024*1024*1024))
            ;;
        *)
            mult=1
            ;;
    esac
    ocpopLogVerbose "MEM REQUEST COMMAND:["${OC_CLIENT}" -n "${namespace}" describe pod ${pod_name} | grep -i Requests -A2 | grep 'memory' | awk -F ':' '{print $2}' | tr -d ' '"
    ocpopLogVerbose "POD:[${pod_name}](Namespace:[${namespace}]) MEM Request With Unit:[${mem}] Unit:[${unit}] Mult:[${mult}]"
    local mem_no_unit
    mem_no_unit="${mem/${unit}/}"
    local mult_mem
    mult_mem=$((mem_no_unit*mult))
    ocpopLogVerbose "POD:[${pod_name}](Namespace:[${namespace}]) MEM Request:[${mult_mem}] Unit:[${unit}] Mult:[${mult}]"
    echo "${mult_mem}"
}

true <<'=cut'
=pod

=head2 ocpopHelmOperatorInstall

Installs a Helm operator.

    ocpopHelmOperatorInstall

=over

=back

Returns 0.

=cut

ocpopHelmOperatorInstall() {
    if [ "${DISABLE_HELM_INSTALL_TESTS}" == "1" ];
    then
      rlLog "User asked to not install/uninstall by using DISABLE_HELM_INSTALL_TESTS=1"
      return 0
    fi
    "${OC_CLIENT}" get namespace "${OPERATOR_NAMESPACE}" 2>/dev/null || "${OC_CLIENT}" create namespace "${OPERATOR_NAMESPACE}"
    rlRun "helm install --namespace ${OPERATOR_NAMESPACE} ${OPERATOR_NAME} ${HELM_IMAGE_VERSION}"
}

true <<'=cut'
=pod

=head2 ocpopInitialHelmClean

Cleans up Helm resources during initial setup.

    ocpopInitialHelmClean

=over

=back

Returns 0.

=cut

ocpopInitialHelmClean() {
    if [ "${DISABLE_HELM_INSTALL_TESTS}" == "1" ];
    then
      rlLog "User asked to not install/uninstall by using DISABLE_HELM_INSTALL_TESTS=1"
      return 0
    fi
    # This can fail in case no attestation operator is already running. If running, it cleans it
    helm uninstall ${OPERATOR_NAME} --namespace ${OPERATOR_NAMESPACE} 2>/dev/null
    return 0
}

true <<'=cut'
=pod

=head2 ocpopCleanHelmDistro

 Uninstalls Helm resources if its specified.

    ocpopCleanHelmDistro

=over

=back

Returns 0.

=cut

ocpopCleanHelmDistro() {
    if [ "${DISABLE_HELM_INSTALL_TESTS}" == "1" ];
    then
      rlLog "User asked to not install/uninstall by using DISABLE_HELM_INSTALL_TESTS=1"
      return 0
    fi
    if [ "${DISABLE_HELM_UNINSTALL_TESTS}" == "1" ];
    then
      rlLog "User asked to not uninstall by using DISABLE_HELM_UNINSTALL_TESTS=1"
      return 0
    fi
    rlRun "helm uninstall ${OPERATOR_NAME} --namespace ${OPERATOR_NAMESPACE}"
    return 0
}

true <<'=cut'
=pod

=head2 ocpopDumpOpenShiftClientStatus

Dumps OpenShift client status.

    ocpopDumpOpenShiftClientStatus

=over

=back

Returns 0.

=cut

ocpopDumpOpenShiftClientStatus() {
    if [ "${EXECUTION_MODE}" == "MINIKUBE" ];
    then
	return 0
    fi
    if [ "${OC_CLIENT}" != "oc" ];
    then
	return 0
    fi
    if [ "${V}" == "1" ] || [ "${VERBOSE}" == "1" ];
    then
        "${OC_CLIENT}" status
    else
        "${OC_CLIENT}" status 2>/dev/null 1>/dev/null
    fi
    return 0
}

true <<'=cut'
=pod

=head2 ocpopInstallHelm

Installs Helm.

    ocpopInstallHelm

=over

=back

Returns 0 when the start was successful, 1 otherwise.

=cut

ocpopInstallHelm() {
    local tmp_dir=$(mktemp -d)
    pushd "${tmp_dir}"
    ARCH=$(case $(uname -m) in x86_64) echo -n amd64 ;; aarch64) echo -n arm64 ;; *) echo -n "$(uname -m)" ;; esac)
    OS=$(uname | awk '{print tolower($0)}')
    #download latest helm
    LATEST_RELEASE_TAG=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r '.tag_name')
    RELEASE_URL="https://get.helm.sh/helm-${LATEST_RELEASE_TAG}-${OS}-${ARCH}.tar.gz"
    TAR_FILE="helm-${LATEST_RELEASE_TAG}-${OS}-${ARCH}.tar.gz"
    rlRun "curl -LO ${RELEASE_URL}"
    rlRun "tar -xzf ${TAR_FILE}"
    rlRun "mv ${OS}-${ARCH}/helm /usr/local/bin/helm"
    popd || return 1
    return 0
}

true <<'=cut'
=pod

=head2 ocpopGetVersion

Gets the version of the image.

    ocpopGetVersion

=over

=back

Returns 0.

=cut

ocpopGetVersion() {
    if [ -n "${DOWNSTREAM_IMAGE_VERSION}" ];
    then
        echo "${DOWNSTREAM_IMAGE_VERSION}"
    else
        echo "${IMAGE_VERSION}"
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

ocpopLibraryLoaded() {

    ### Install required packages for script functions
    local PACKAGES=(git podman jq)
    echo -e "\nInstall packages required by the script functions when missing."
    rpm -q "${PACKAGES[@]}" || yum -y install "${PACKAGES[@]}"
    #creating tmp dir for data
    mkdir -p /var/tmp/ocpopLib && chmod 777 /var/tmp/ocpopLib

    if [ -n "$__INTERNAL_ocpopTmpDir" ]; then
        rlLogDebug "Library common-cloud-orchestration/ocpop-lib loaded."
        return 0
    else
        rlLogError "Failed loading library common-cloud-orchestration/ocpop-lib."
        return 1
    fi

}
