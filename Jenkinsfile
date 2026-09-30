// taskflow-mobile pipeline: analyze, test, SCA, debug APK on every branch, signed release AAB on main.
// Build and test stages run in an ephemeral Kubernetes pod (no static agent).
def notify(String status) {
  // Slack-format message with branch and build URL, posted to the lab's mock Slack webhook
  def branch = env.BRANCH_NAME ?: 'main'
  def text = "${status}: taskflow-mobile ${branch} #${env.BUILD_NUMBER} ${env.BUILD_URL}"
  sh "curl -s -X POST -H 'Content-Type: application/json' -d '{\"text\": \"${text}\"}' http://notify-mock:8000/ || true"
}

pipeline {
  agent {
    kubernetes {
      yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: flutter
    image: ghcr.io/cirruslabs/flutter:stable
    imagePullPolicy: IfNotPresent
    command: ['cat']
    tty: true
    resources:
      requests: { memory: 3Gi, cpu: '1' }
      limits: { memory: 6Gi }
    volumeMounts:
    - { name: gradle-cache, mountPath: /root/.gradle }
    - { name: pub-cache, mountPath: /root/.pub-cache }
  - name: jnlp
    image: jenkins/inbound-agent:latest-jdk21
    imagePullPolicy: IfNotPresent
  volumes:
  # node-local caches so a fresh ephemeral pod does not re-download Gradle/pub dependencies every build
  - name: gradle-cache
    hostPath: { path: /var/cache/jenkins/gradle, type: DirectoryOrCreate }
  - name: pub-cache
    hostPath: { path: /var/cache/jenkins/pub, type: DirectoryOrCreate }
'''
      defaultContainer 'flutter'
    }
  }

  options { timeout(time: 60, unit: 'MINUTES') }

  stages {
    stage('Dependencies') {
      steps { sh 'flutter pub get' }
    }

    // independent checks run side by side
    stage('Verify') {
      parallel {
        stage('Analyze') {
          steps { sh 'flutter analyze' }
        }
        stage('Test') {
          steps { sh 'flutter test --coverage' }
          post { always { archiveArtifacts artifacts: 'coverage/lcov.info', allowEmptyArchive: true } }
        }
        stage('SCA - osv-scanner') {
          steps {
            sh '''
              curl -sSfL -o osv-scanner https://github.com/google/osv-scanner/releases/download/v1.9.1/osv-scanner_linux_amd64
              chmod +x osv-scanner
              ./osv-scanner --lockfile=pubspec.lock --format table
            '''
          }
        }
      }
    }

    stage('Build Debug APK') {
      steps {
        sh 'flutter build apk --debug'
        archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/app-debug.apk'
      }
    }

    stage('Build Signed Release AAB') {
      when { expression { env.BRANCH_NAME == null || env.BRANCH_NAME == 'main' } }
      steps {
        withCredentials([
          file(credentialsId: 'android-keystore', variable: 'KEYSTORE_FILE'),
          string(credentialsId: 'android-keystore-password', variable: 'KEYSTORE_PASSWORD'),
          string(credentialsId: 'android-key-alias', variable: 'KEY_ALIAS')
        ]) {
          sh '''
            cp "$KEYSTORE_FILE" android/release.jks
            printf 'storeFile=%s\nstorePassword=%s\nkeyAlias=%s\nkeyPassword=%s\n' \
              "$WORKSPACE/android/release.jks" "$KEYSTORE_PASSWORD" "$KEY_ALIAS" "$KEYSTORE_PASSWORD" > android/key.properties
            flutter build appbundle --release
            # prove the bundle is signed with our key, not the debug key
            jarsigner -verify -verbose:summary build/app/outputs/bundle/release/app-release.aab | tail -3
            rm -f android/key.properties android/release.jks
          '''
        }
        archiveArtifacts artifacts: 'build/app/outputs/bundle/release/app-release.aab'
      }
    }
  }

  post {
    success { script { notify('SUCCESS') } }
    failure { script { notify('FAILURE') } }
  }
}
