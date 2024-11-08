String PRD_BRANCH_NAME = "main"
String PREPRD_BRANCH_NAME = "uat"
String PRD_ENVIRONMENT_NAME = "prod"

boolean IS_PRD = env.BRANCH_NAME == PRD_BRANCH_NAME
boolean IS_PREPRD = env.BRANCH_NAME == PREPRD_BRANCH_NAME
boolean IS_PRD_OR_PREPRD = IS_PRD || IS_PREPRD

//Get environment name from branch
String ENVIRONMENT_NAME = env.BRANCH_NAME
//Exception for prod since main branch is used
if(IS_PRD){
  ENVIRONMENT_NAME = PRD_ENVIRONMENT_NAME
}

boolean SKIP = false

pipeline {
  agent any

  options {
    buildDiscarder(logRotator(numToKeepStr: '3', artifactNumToKeepStr: '3'))
  }

  stages {

    stage('Prepare') {
      steps {
        script {

          //Map environment to values file
          //If you use branchname with / handle it here (e.g. replace / with -)
          env.VALUES_FILE = "values-" + ENVIRONMENT_NAME + ".yaml"

          //Skip building (helm chart only change) or always build?
          if ( ! containsChangesOutsideChart()){
            SKIP = true
            echo "Skip remaining steps because of no changes out of the helm chart"
          }
          if ( currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause').size() > 0 ){
            SKIP = false
            echo "Execute all steps because of manuel triggered build"
          }
          env.GIT_COMMIT_MSG = sh (script: "git log -1 --pretty=%B ${GIT_COMMIT}", returnStdout: true).trim()
          if (env.GIT_COMMIT_MSG.contains('+semver:')) {
            SKIP = false
            echo "Execute all steps because of version increase"
          }
          if(env.BUILD_NUMBER == '1'){
            echo "Execute all steps because of first build"
            SKIP = false
          }

          dir("liferay") {
            sh "chmod +x gradlew"
            sh "sed -i -e 's/\r\$5//' gradlew"
          }

        }
      }
    }

    stage('Scan Code') {
      when {
        expression { !SKIP }
      }
      parallel {
        stage('Spotbugs') {
          steps {
            dir("liferay") {
              sh "./gradlew spotbugsMain"
            }
          }
        }
        stage('OWASP') {
          steps {
            dir("liferay/modules") {
              //sh "../gradlew dependencyCheckAnalyze"
            }
          }
        }
      }
    }

    stage('Build') {
      when {
        expression { !SKIP }
      }
      steps {
        dir("liferay") {
          script {
            sh "./gradlew dockerDeploy"
            sh "./gradlew createDockerfile"
          }
        }
      }
    }

    stage('Build Images') {
      when {
        expression { !SKIP }
      }
      steps {
        script {
          echo "Preparing with gitversion"
          sh 'gitversion /output buildserver'
          def props = readProperties file: 'gitversion.properties'
          env.BUILD_VERSION = props.GitVersion_MajorMinorPatch
          echo "GitVersion MajorMinorPatch: $BUILD_VERSION"

          if ( !IS_PRD_OR_PREPRD ) {
            env.BUILD_VERSION = env.BUILD_VERSION + "-" + env.BRANCH_NAME + "-" + env.BUILD_NUMBER
            echo "GitVersion MajorMinorPatch + Own Tag: $BUILD_VERSION"
            env.BUILD_VERSION = props.GitVersion_SemVer
            echo "GitVersion SemVer: $BUILD_VERSION"
          }
          echo "Image Tag: $BUILD_VERSION"
          env.REGISTRY = "europe-west3-docker.pkg.dev/lrdevcon24/liferay-devcon24/"
          sh 'docker compose build'
        }
      }
    }

    stage('Scan Images') {
      when {
        expression { !SKIP }
      }
      steps {
        script {
          sh 'curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b .'

          //omitted for time reasons
          //sh './grype ${REGISTRY}devcon24-liferay:$BUILD_VERSION'
          sh './grype ${REGISTRY}devcon24-webserver:$BUILD_VERSION'
        }
      }
    }

    stage('Push Images') {
      when {
        expression { !SKIP }
      }
      steps {
        script {
          withCredentials([file(credentialsId: "gcp_artifact_registry_jsonkey", variable: "JSON_KEY")]) {
            sh 'docker login -u _json_key --password-stdin https://europe-west3-docker.pkg.dev < $JSON_KEY'
            sh 'docker compose push'
          }
        }
      }
    }

    stage('Update values') {
      when {
        expression { !SKIP }
      }
      steps {
        script {
          env.VALUES_FILEPATH = '.helm/env/' + env.VALUES_FILE
          if(fileExists (env.VALUES_FILEPATH) ){
            withCredentials([usernamePassword(credentialsId: "github_token", passwordVariable: "GIT_PASSWORD", usernameVariable: "GIT_USER")]) {
              sh 'git reset --hard HEAD'
              sh 'sed -i "s/imageVersion:.*/imageVersion: $BUILD_VERSION/g" $VALUES_FILEPATH'
              sh 'git add $VALUES_FILEPATH'

              env.CHANGE = sh (script: '[ -z "$(git status --porcelain --untracked-files=no)" ]', returnStatus: true)
              if (CHANGE != "0") {
                sh 'git -c user.name="Jenkins Build User" -c user.email="jenkins@usu.com" commit -m "Set image version \"$BUILD_VERSION\""'
                sh 'git push https://${GIT_USER}:${GIT_PASSWORD}@github.com/usimthral/liferay-devcon24-workshop.git'

                sh 'git tag $BUILD_VERSION HEAD'
                sh 'git push https://${GIT_USER}:${GIT_PASSWORD}@github.com/usimthral/liferay-devcon24-workshop.git $BUILD_VERSION'
              }
            }
          } else {
            echo "Skip update values - file $VALUES_FILEPATH does not exist"
          }
        }
      }
    }

  }

  post {
    always {
      cleanWs()
    }
  }

}

// Helper Functions

@NonCPS
boolean containsChangesOutsideChart(){
  for ( changeLogSet in currentBuild.changeSets){
    for (entry in changeLogSet.getItems()){
      for (path in entry.affectedPaths) {
        println ("Changed file: " +  path )
        if( ! path.startsWith(".helm") ){
          return true
        }
      }
    }
  }
  return false
}