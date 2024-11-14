#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/attestation-operator/Setup/installing_operator
#   Description: Basic installation tests for attestation-operator
#   Author: Patrik Koncity <pkoncity@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2024 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart
    rlPhaseStartSetup
        rlRun 'rlImport "./ocpop-lib"' || rlDie "cannot import ocpop lib"
        # Define variables
        OC_VERSION="latest"
        OC_URL="https://mirror.openshift.com/pub/openshift-v4/clients/oc/${OC_VERSION}/linux/oc.tar.gz"
        INSTALL_DIR="/usr/local/bin"
        # Download the oc binary
        rlRun "curl -L ${OC_URL} -o /tmp/oc.tar.gz" 0 "Downloading oc binary..."
        # Extract the archive
        rlRun "tar -xvzf /tmp/oc.tar.gz -C /tmp" 0 "Extracting oc binary..."
        # Move the oc binary to the installation directory
        rlRun "mv /tmp/oc ${INSTALL_DIR}" 0 "Installing oc binary..."
        rlRun "rm /tmp/oc.tar.gz" 0 "Cleaning up..."
        # Verify the installation
        rlRun "oc version" 0 "Verifying oc installation..."
        rlRun "oc status" 1
        #provide as conditional
        if [ -n "$DECODED_KUBECONFIG_CONTENT" ]; then
            rlRun "mkdir -p /root/.kube"
            rlRun "echo \"$DECODED_KUBECONFIG_CONTENT\" > ~/.kube/config"
        fi
        export KUBECONFIG=~/.kube/config
        #oc client should be now logged into provisioned cluster
        rlRun "oc status" 0 "Check if oc cli is logged into provisioned cluster"
    rlPhaseEnd
rlJournalEnd