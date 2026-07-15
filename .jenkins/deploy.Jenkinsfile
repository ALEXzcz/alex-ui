def parseEnvFile(String content) {
    def result = [:]
    content.readLines().each { line ->
        def trimmed = line.trim()
        if (!trimmed || trimmed.startsWith('#')) {
            return
        }
        def separatorIndex = trimmed.indexOf('=')
        if (separatorIndex <= 0) {
            return
        }
        def key = trimmed.substring(0, separatorIndex).trim()
        def value = trimmed.substring(separatorIndex + 1).trim()
        result[key] = value
    }
    return result
}

pipeline {
    agent none

    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout()
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['test', 'prod'], description: '部署环境')
        string(name: 'IMAGE_TAG', defaultValue: '', description: '要部署的镜像标签(main 分支 CI 产出)')
        string(name: 'RELEASE_TAG', defaultValue: '', description: '正式发布标签(可选，例如 v1.2.3)')
    }

    environment {
        REGISTRY_HOST = "crpi-tdbcyhugv30sskjj.cn-guangzhou.personal.cr.aliyuncs.com"
        REGISTRY_REPO = "alex_zcz/alex-ui"
        REGISTRY_CREDENTIALS_ID = "docker-registry-cred"
        KEEP_IMAGE_COUNT = "3"
    }

    stages {
        stage('Init') {
            agent any
            steps {
                checkout scm
                script {
                    if (!params.IMAGE_TAG?.trim()) {
                        error 'IMAGE_TAG 不能为空'
                    }

                    def deployEnvFile = "deploy/${params.DEPLOY_ENV}.env"
                    if (!fileExists(deployEnvFile)) {
                        error "环境配置文件不存在: ${deployEnvFile}"
                    }

                    def deployEnvConfig = parseEnvFile(readFile(file: deployEnvFile))
                    env.SOURCE_IMAGE_TAG = params.IMAGE_TAG.trim()
                    env.RELEASE_TAG = params.RELEASE_TAG?.trim() ?: ''
                    env.SOURCE_IMAGE_FULL = "${env.REGISTRY_HOST}/${env.REGISTRY_REPO}:${env.SOURCE_IMAGE_TAG}"
                    env.RELEASE_IMAGE_FULL = env.RELEASE_TAG ? "${env.REGISTRY_HOST}/${env.REGISTRY_REPO}:${env.RELEASE_TAG}" : ''
                    env.DEPLOY_IMAGE_FULL = env.RELEASE_TAG ? env.RELEASE_IMAGE_FULL : env.SOURCE_IMAGE_FULL
                    env.DEPLOY_ENV_FILE = deployEnvFile
                    env.DEPLOY_IP = deployEnvConfig['DEPLOY_HOST'] ?: ''
                    env.DEPLOY_USER = deployEnvConfig['DEPLOY_USER'] ?: ''
                    env.DEPLOY_CRED = deployEnvConfig['DEPLOY_CRED'] ?: ''
                    env.DEPLOY_HOME = deployEnvConfig['DEPLOY_HOME'] ?: ''
                    env.DEPLOY_APP_PORT = deployEnvConfig['APP_PORT'] ?: ''
                    env.DEPLOY_CONTAINER_PORT = deployEnvConfig['CONTAINER_PORT'] ?: ''
                    env.DEPLOY_NETWORK = deployEnvConfig['APP_NETWORK'] ?: ''
                    env.DEPLOY_CONTAINER_NAME = deployEnvConfig['CONTAINER_NAME'] ?: ''

                    if (!env.DEPLOY_IP?.trim()) {
                        error "环境配置缺少 DEPLOY_HOST: ${deployEnvFile}"
                    }
                    if (!env.DEPLOY_USER?.trim()) {
                        error "环境配置缺少 DEPLOY_USER: ${deployEnvFile}"
                    }
                    if (!env.DEPLOY_CRED?.trim()) {
                        error "环境配置缺少 DEPLOY_CRED: ${deployEnvFile}"
                    }
                    if (!env.DEPLOY_HOME?.trim()) {
                        error "环境配置缺少 DEPLOY_HOME: ${deployEnvFile}"
                    }
                    if (!env.DEPLOY_APP_PORT?.trim()) {
                        error "环境配置缺少 APP_PORT: ${deployEnvFile}"
                    }

                    env.DEPLOY_HEALTH_URL = "http://${env.DEPLOY_IP}:${env.DEPLOY_APP_PORT}/alex/"
                    currentBuild.displayName = "#${env.BUILD_NUMBER} ${params.DEPLOY_ENV} ${env.RELEASE_TAG ?: env.SOURCE_IMAGE_TAG}"
                    currentBuild.description = "env=${params.DEPLOY_ENV}, image=${env.DEPLOY_IMAGE_FULL}, host=${env.DEPLOY_IP}, home=${env.DEPLOY_HOME}"
                }
            }
        }

        stage('Release Context') {
            agent any
            steps {
                script {
                    writeFile file: 'deploy-record.properties', text: """
                        DEPLOY_ENV=${params.DEPLOY_ENV}
                        SOURCE_IMAGE_TAG=${env.SOURCE_IMAGE_TAG}
                        RELEASE_TAG=${env.RELEASE_TAG}
                        DEPLOY_IMAGE_FULL=${env.DEPLOY_IMAGE_FULL}
                        DEPLOY_HOST=${env.DEPLOY_IP}
                        DEPLOY_USER=${env.DEPLOY_USER}
                        DEPLOY_HOME=${env.DEPLOY_HOME}
                        APP_PORT=${env.DEPLOY_APP_PORT}
                        CONTAINER_PORT=${env.DEPLOY_CONTAINER_PORT}
                        CONTAINER_NAME=${env.DEPLOY_CONTAINER_NAME}
                        APP_NETWORK=${env.DEPLOY_NETWORK}
                        BUILD_NUMBER=${env.BUILD_NUMBER}
                        BUILD_URL=${env.BUILD_URL}
                        JOB_NAME=${env.JOB_NAME}
                    """.trim() + "\n"

                    echo """
                    ========== GitHub Flow CD 发布信息 ==========
                    部署环境: ${params.DEPLOY_ENV}
                    CI 镜像标签: ${env.SOURCE_IMAGE_TAG}
                    Release 标签: ${env.RELEASE_TAG ?: '未指定'}
                    部署镜像: ${env.DEPLOY_IMAGE_FULL}
                    服务器 IP: ${env.DEPLOY_IP}
                    SSH 用户: ${env.DEPLOY_USER}
                    部署目录: ${env.DEPLOY_HOME}
                    容器名称: ${env.DEPLOY_CONTAINER_NAME}
                    服务端口: ${env.DEPLOY_APP_PORT}
                    容器端口: ${env.DEPLOY_CONTAINER_PORT}
                    容器网络: ${env.DEPLOY_NETWORK}
                    环境文件: ${env.DEPLOY_ENV_FILE}
                    发布模式: ${env.RELEASE_TAG ? '先打 Release Tag，再部署' : '普通部署'}
                    制品来源: main 分支 CI
                    镜像拉取认证: 由部署机本地 docker login 提供
                    ==================================
                    """

                    archiveArtifacts artifacts: 'deploy-record.properties', onlyIfSuccessful: false, allowEmptyArchive: true
                }
            }
        }

        stage('Create Release Tag') {
            when {
                expression { return env.RELEASE_TAG?.trim() }
            }
            agent any
            steps {
                withCredentials([usernamePassword(credentialsId: env.REGISTRY_CREDENTIALS_ID, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    sh '''
                        set -e
                        cleanup() {
                            docker rmi "$RELEASE_IMAGE_FULL" >/dev/null 2>&1 || true
                            docker rmi "$SOURCE_IMAGE_FULL" >/dev/null 2>&1 || true
                        }
                        trap cleanup EXIT
                        echo "$REG_PASS" | docker login "$REGISTRY_HOST" -u "$REG_USER" --password-stdin
                        docker pull "$SOURCE_IMAGE_FULL"
                        docker tag "$SOURCE_IMAGE_FULL" "$RELEASE_IMAGE_FULL"
                        docker push "$RELEASE_IMAGE_FULL"
                        docker logout "$REGISTRY_HOST" || true
                    '''
                }
            }
        }

        stage('Verify Remote Registry Auth') {
            agent any
            steps {
                script {
                    sshagent([env.DEPLOY_CRED]) {
                        sh """
                            ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} '
                                set -e
                                DOCKER_CONFIG_FILE=~/.docker/config.json
                                if [ ! -f "\$DOCKER_CONFIG_FILE" ]; then
                                    echo "远端未发现 Docker 登录配置: ~/.docker/config.json"
                                    echo "请先在部署机执行: docker login ${env.REGISTRY_HOST}"
                                    exit 1
                                fi
                                if ! grep -q "${env.REGISTRY_HOST}" "\$DOCKER_CONFIG_FILE"; then
                                    echo "远端 Docker 已有配置，但未包含当前镜像仓库登录信息"
                                    echo "请先在部署机执行: docker login ${env.REGISTRY_HOST}"
                                    exit 1
                                fi
                                echo "远端镜像仓库认证检查通过"
                            '
                        """
                    }
                }
            }
        }

        stage('Deploy') {
            agent any
            steps {
                checkout scm
                script {
                    sshagent([env.DEPLOY_CRED]) {
                        sh """
                            set -e
                            test -f "${WORKSPACE}/docker-compose.yml"
                            test -f "${WORKSPACE}/${env.DEPLOY_ENV_FILE}"
                            ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "mkdir -p ${env.DEPLOY_HOME}"
                            scp "${WORKSPACE}/docker-compose.yml" ${env.DEPLOY_USER}@${env.DEPLOY_IP}:${env.DEPLOY_HOME}/docker-compose.yml
                            scp "${WORKSPACE}/${env.DEPLOY_ENV_FILE}" ${env.DEPLOY_USER}@${env.DEPLOY_IP}:${env.DEPLOY_HOME}/.env
                            ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "sed -i 's|^APP_IMAGE=.*|APP_IMAGE=${env.DEPLOY_IMAGE_FULL}|' ${env.DEPLOY_HOME}/.env"
                            ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "
                                set -e
                                cd ${env.DEPLOY_HOME}
                                echo '开始拉取镜像...'
                                docker compose pull
                                echo '开始启动容器...'
                                docker compose up -d
                                echo '当前容器状态:'
                                docker compose ps
                            "
                        """
                    }
                }
            }
        }

        stage('Health Check') {
            agent any
            steps {
                script {
                    sshagent([env.DEPLOY_CRED]) {
                        sh """
                            ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "
                                set -e
                                sleep 10
                                if curl -fsS '${env.DEPLOY_HEALTH_URL}' >/dev/null; then
                                    echo '健康检查通过: ${env.DEPLOY_HEALTH_URL}'
                                else
                                    echo '健康检查失败: ${env.DEPLOY_HEALTH_URL}'
                                    cd ${env.DEPLOY_HOME}
                                    docker compose logs --tail=100
                                    exit 1
                                fi
                            "
                        """
                    }
                }
            }
        }

        stage('Cleanup Images') {
            agent any
            steps {
                checkout scm
                script {
                    sshagent([env.DEPLOY_CRED]) {
                        sh """
                            set -e
                            test -f "${WORKSPACE}/.jenkins/scripts/cleanup-images.sh"
                            scp "${WORKSPACE}/.jenkins/scripts/cleanup-images.sh" ${env.DEPLOY_USER}@${env.DEPLOY_IP}:${env.DEPLOY_HOME}/cleanup-images.sh
                            ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "
                                set -e
                                chmod +x ${env.DEPLOY_HOME}/cleanup-images.sh
                                ${env.DEPLOY_HOME}/cleanup-images.sh '${env.REGISTRY_HOST}/${env.REGISTRY_REPO}' '${env.KEEP_IMAGE_COUNT}' '${env.DEPLOY_CONTAINER_NAME}'
                                rm -f ${env.DEPLOY_HOME}/cleanup-images.sh
                            "
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "CD 成功: ${params.DEPLOY_ENV} -> ${env.DEPLOY_IP}, 镜像: ${env.DEPLOY_IMAGE_FULL}"
        }
        failure {
            echo 'CD 失败，请检查日志'
        }
    }
}
