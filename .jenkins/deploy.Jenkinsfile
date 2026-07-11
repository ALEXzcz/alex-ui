def serverConfig = [
    "test": [
        ip: "47.119.185.39",
        user: "alex",
        cred: "aliyun-server-ssh-key",
        appHome: "/home/alex/alex-ui",
        appPort: "80",
        containerPort: "80",
        appNetwork: "network",
        containerName: "alex-ui-nginx"
    ],
    "prod": [
        ip: "47.119.185.39",
        user: "alex",
        cred: "aliyun-server-ssh-key",
        appHome: "/home/alex/alex-ui",
        appPort: "80",
        containerPort: "80",
        appNetwork: "network",
        containerName: "alex-ui-nginx"
    ]
]

pipeline {
    agent none

    options {
        timeout(time: 30, unit: 'MINUTES')              // 超时时间
        timestamps()                                    // 日志可观测
        disableConcurrentBuilds()                       // 防并发污染
        buildDiscarder(logRotator(numToKeepStr: '20'))  // 保留最近20次构建
        skipDefaultCheckout()                           // 阻止 checkout scm 自动拉取代码
    }

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['test', 'prod'], description: '部署环境')
        string(name: 'IMAGE_TAG', defaultValue: '', description: '要部署的镜像标签(main 分支 CI 产出)')
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
                script {
                    if (!params.IMAGE_TAG?.trim()) {
                        error 'IMAGE_TAG 不能为空'
                    }
                    def cfg = serverConfig[params.DEPLOY_ENV]
                    if (cfg == null) {
                        error "未知环境: ${params.DEPLOY_ENV}"
                    }
                    env.SOURCE_IMAGE_TAG = params.IMAGE_TAG.trim()
                    env.SOURCE_IMAGE_FULL = "${env.REGISTRY_HOST}/${env.REGISTRY_REPO}:${env.SOURCE_IMAGE_TAG}"
                    env.DEPLOY_IMAGE_FULL = env.SOURCE_IMAGE_FULL
                    env.DEPLOY_IP = cfg.ip
                    env.DEPLOY_USER = cfg.user
                    env.DEPLOY_CRED = cfg.cred
                    env.DEPLOY_HOME = cfg.appHome
                    env.DEPLOY_APP_PORT = cfg.appPort
                    env.DEPLOY_CONTAINER_PORT = cfg.containerPort
                    env.DEPLOY_NETWORK = cfg.appNetwork
                    env.DEPLOY_CONTAINER_NAME = cfg.containerName
                }
            }
        }

        stage('Release Context') {
            agent any
            steps {
                script {
                    echo """
                    ========== GitHub Flow CD 发布信息 ==========
                    部署环境: ${params.DEPLOY_ENV}
                    镜像标签: ${env.SOURCE_IMAGE_TAG}
                    部署镜像: ${env.DEPLOY_IMAGE_FULL}
                    服务器 IP: ${env.DEPLOY_IP}
                    SSH 用户: ${env.DEPLOY_USER}
                    部署目录: ${env.DEPLOY_HOME}
                    容器名称: ${env.DEPLOY_CONTAINER_NAME}
                    服务端口: ${env.DEPLOY_APP_PORT}
                    容器端口: ${env.DEPLOY_CONTAINER_PORT}
                    容器网络: ${env.DEPLOY_NETWORK}
                    制品来源: main 分支 CI
                    ==================================
                    """
                }
            }
        }

        stage('Deploy') {
            agent any
            steps {
                checkout scm
                script {
                    withCredentials([usernamePassword(credentialsId: env.REGISTRY_CREDENTIALS_ID, usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                        sshagent([env.DEPLOY_CRED]) {
                            sh """
                                set -e
                                test -f "${WORKSPACE}/docker-compose.yml"
                                ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "mkdir -p ${env.DEPLOY_HOME}"
                                scp "${WORKSPACE}/docker-compose.yml" ${env.DEPLOY_USER}@${env.DEPLOY_IP}:${env.DEPLOY_HOME}/docker-compose.yml
                                ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "printf '%s\n' \
                                'APP_IMAGE=${env.DEPLOY_IMAGE_FULL}' \
                                'CONTAINER_NAME=${env.DEPLOY_CONTAINER_NAME}' \
                                'APP_PORT=${env.DEPLOY_APP_PORT}' \
                                'CONTAINER_PORT=${env.DEPLOY_CONTAINER_PORT}' \
                                'APP_NETWORK=${env.DEPLOY_NETWORK}' \
                                > ${env.DEPLOY_HOME}/.env"
                                printf '%s' "\$REG_PASS" | ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "docker login ${env.REGISTRY_HOST} -u \"\$REG_USER\" --password-stdin"
                                ssh ${env.DEPLOY_USER}@${env.DEPLOY_IP} "
                                    set -e
                                    cd ${env.DEPLOY_HOME}
                                    docker compose pull
                                    docker compose up -d
                                    docker compose ps
                                    docker logout ${env.REGISTRY_HOST} >/dev/null 2>&1 || true
                                "
                            """
                        }
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
