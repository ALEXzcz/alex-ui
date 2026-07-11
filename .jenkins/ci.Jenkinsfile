pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')              // 超时时间
        timestamps()                                    // 日志可观测
        disableConcurrentBuilds()                       // 防并发污染
        buildDiscarder(logRotator(numToKeepStr: '20'))  // 保留最近20次构建
        skipDefaultCheckout()                           // 阻止 checkout scm 自动拉取代码
    }
    environment {
        NODE_OPTIONS = "--max-old-space-size=384"
        REGISTRY_HOST = "crpi-tdbcyhugv30sskjj.cn-guangzhou.personal.cr.aliyuncs.com"
        REGISTRY_REPO = "alex_zcz/alex-ui"
        REGISTRY_CREDENTIALS_ID = "docker-registry-cred"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Resolve Branch Strategy') {
            steps {
                script {
                    def deprecatedLongLivedBranches = ['master', 'release', 'develop']
                    if (deprecatedLongLivedBranches.contains(env.BRANCH_NAME)) {
                        error "当前 CI 已切换为 GitHub Flow，长期分支只保留 main，禁止继续使用 ${env.BRANCH_NAME}"
                    }

                    env.IS_MAIN_BRANCH = (env.BRANCH_NAME == 'main') ? 'true' : 'false'
                    env.IS_PULL_REQUEST = env.CHANGE_ID ? 'true' : 'false'
                    env.BRANCH_KIND = env.IS_MAIN_BRANCH == 'true' ? 'main' : (env.IS_PULL_REQUEST == 'true' ? 'pull-request' : 'short-lived-branch')
                }
            }
        }

        stage("Build Context") {
            steps {
                script {
                    env.BUILD_TS = sh(script: "date +%Y%m%d%H%M%S", returnStdout: true).trim()
                    env.GIT_SHORT_SHA = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.TRACE_TAG = "${env.BUILD_TS}-${env.GIT_SHORT_SHA}"
                    env.SAFE_BRANCH_NAME = env.BRANCH_NAME.replaceAll(/[^A-Za-z0-9_.-]/, '-')
                    env.LOCAL_IMAGE = env.IS_MAIN_BRANCH == 'true' ? "alex-ui-ci:${env.SAFE_BRANCH_NAME}-${env.BUILD_NUMBER}-${env.GIT_SHORT_SHA}" : ''
                    env.IMAGE_FULL = env.IS_MAIN_BRANCH == 'true' ? "${env.REGISTRY_HOST}/${env.REGISTRY_REPO}:${env.TRACE_TAG}" : ''
                    echo """
                    ========== GitHub Flow CI 构建信息 ==========
                    分支: ${env.BRANCH_NAME}
                    分支类型: ${env.BRANCH_KIND}
                    Pull Request: ${env.CHANGE_ID ?: '否'}
                    构建号: ${env.BUILD_NUMBER}
                    构建时间戳: ${env.BUILD_TS}
                    本地验证镜像: ${env.LOCAL_IMAGE ?: '仅 main 分支构建'}
                    发布镜像: ${env.IMAGE_FULL ?: '仅 main 分支推送'}
                    镜像仓库: ${env.REGISTRY_HOST}/${env.REGISTRY_REPO}
                    仓库凭据ID: ${env.REGISTRY_CREDENTIALS_ID}
                    ============================================
                    """
                }
            }
        }

        stage('Verify') {
            steps {
                sh 'npm ci'
                sh 'npm run build'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'dist/**', fingerprint: true
                }
            }
        }

        stage('Build Runtime Image') {
            when {
                expression { env.IS_MAIN_BRANCH == 'true' }
            }
            steps {
                sh '''
                    set -e
                    test -d dist
                    docker build -t "$LOCAL_IMAGE" .
                    docker tag "$LOCAL_IMAGE" "$IMAGE_FULL"
                '''
            }
        }

        stage('Push Release Image') {
            when {
                expression { env.IS_MAIN_BRANCH == 'true' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: env.REGISTRY_CREDENTIALS_ID, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    sh '''
                        set -e
                        printenv | grep -i proxy || true
                        echo "$REG_PASS" | docker login "$REGISTRY_HOST" -u "$REG_USER" --password-stdin
                        docker push "$IMAGE_FULL"
                        docker logout "$REGISTRY_HOST"
                    '''
                }
            }
        }

    }

    post {
        always {
            sh '''
                docker rmi "$LOCAL_IMAGE" >/dev/null 2>&1 || true
                if [ -n "$IMAGE_FULL" ]; then
                    docker rmi "$IMAGE_FULL" >/dev/null 2>&1 || true
                fi
            '''
        }
        success {
            script {
                if (env.IS_MAIN_BRANCH == 'true') {
                    echo "CI 成功: main -> 镜像 ${env.IMAGE_FULL}"
                } else {
                    echo "CI 成功: ${env.BRANCH_NAME} -> 已完成分支前端校验，未构建发布镜像"
                }
            }
        }
        failure {
            echo "CI 失败，请检查日志"
        }
    }
}
