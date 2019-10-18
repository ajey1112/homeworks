#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# TBD
oc new-project ${GUID}-jenkins --display-name "${GUID} Shared Jenkins"
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true
oc set resources dc jenkins --limits=memory=2Gi,cpu=2 --requests=memory=1Gi,cpu=500m

# Create custom agent container image with skopeo
# TBD
oc new-build -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11 USER root\nRUN yum -y install skopeo && yum clean all USER 1001' --name=jenkins-agent-appdev -n ${GUID}-jenkins

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
# TBD
echo "
apiVersion: v1
items:
- kind: "BuildConfig"
  apiVersion: "v1"
  metadata:
    name: "pipeline-demo"
  spec:
    triggers:
          - github:
              secret: 5Mlic4Le
            type: GitHub
          - generic:
              secret: FiArdDBH
            type: Generic
    strategy:
      type: "JenkinsPipeline"
      jenkinsPipelineStrategy:
        jenkinsfile: |
                          node {
                              stage ("Build")
                                    echo '*** Build Starting ***'
                                    openshiftBuild bldCfg: 'cotd2', buildName: '', checkForTriggeredDeployments: 'false', commitID: '', namespace: '', showBuildLogs: 'true', verbose: 'true'
                                    openshiftVerifyBuild bldCfg: 'cotd2', checkForTriggeredDeployments: 'false', namespace: '', verbose: 'false'
                                    echo '*** Build Complete ***'
                              stage ("Deploy and Verify in Development Env")
                                    echo '*** Deployment Starting ***'
                                    openshiftDeploy depCfg: 'cotd2', namespace: '', verbose: 'false', waitTime: ''
                                    openshiftVerifyDeployment authToken: '', depCfg: 'cotd2', namespace: '', replicaCount: '1', verbose: 'false', verifyReplicaCount: 'false', waitTime: ''
                                    echo '*** Deployment Complete ***'
                               }
kind: List
metadata: {}" | oc create -f - -n ${GUID}-jenkins


# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
