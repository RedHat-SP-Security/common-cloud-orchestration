#!/bin/bash
# Copyright 2024.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
. /usr/share/beakerlib/beakerlib.sh || exit 1


#TESTING PURPOSES, SHOULD BE SET IN RECIPE MATRIX
#INDEX_OCP_VER=1

rlJournalStart
    rlPhaseStartTest "Get and Set version of Openshift Client"
        ARRAY_OCP_VERSIONS=()
        # Explanation:
        # - curl -s: Fetch the content of the URL silently (without progress meter)
        # - grep -oP '(?<=<span class="name">)[^<]+': Extract the text within the <span class="name"> tags
        # - grep -v '^4\.9\.': Exclude versions starting with '4.9.'
        # - sort -V: Sort the versions in natural order
        # - awk -F. '{print $1"."$2"."$3}': Extract the major.minor.patch version
        # - sort -u -t. -k1,2: Get unique major.minor versions with the highest patch version
        # - for loop: Iterate over each unique version and echo it
        #workaround to not grep 4.9 versions
        CRC_VERSIONS_OUT=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/crc/bundles/openshift/ | grep -oP '(?<=<span class="name">)[^<]+' | grep -v '^4\.9\.' | sort -V)
        CRC_VERSIONS_OUT=$(echo "$CRC_VERSIONS_OUT" | awk -F. '{print $1"."$2"."$3}' | sort -u -t. -k1,2)
        TESTABLE_VERSIONS=$(echo "$CRC_VERSIONS_OUT" | tail -n 4)
        # Use a for loop to read each line and store it in the array
        for line in $TESTABLE_VERSIONS; do
            ARRAY_OCP_VERSIONS+=("$line")
        done
        rlLogInfo "=========List of supported versions========="
        # Print the array to verify
        for ARRAY_OCP_VERSIONS in "${ARRAY_OCP_VERSIONS[@]}"; do
            rlRun "echo ${ARRAY_OCP_VERSIONS}"
        done
        rlLogInfo "INDEX WHICH WILL BE USED FOR OCP VERSION: $INDEX_OCP_VER"
        rlLogInfo "============================================"
        OCP_VERSION="${ARRAY_OCP_VERSIONS[$INDEX_OCP_VER]}"
        rlLogInfo "VERSION OF OCP, WHICH WILL BE INSTALLED: $OCP_VERSION"
        #For another shell sessions, where will be OCP cluster installed
        cat <<EOF > /etc/profile.d/ocp_ver_init.sh
#!/bin/bash
export OCP_VERSION=${OCP_VERSION}
EOF
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f /usr/local/bin/oc-mirror"
    rlPhaseEnd


rlJournalEnd