pipeline {
  agent any
  // 需要在 Jenkins 全局工具里配置 Docker CLI，名称与这里一致
  tools { dockerTool 'docker-tool' }

  parameters {
    string(name: 'EXTRA_TAGS', defaultValue: '', description: '额外 tags，逗号分隔，如: 1.2.0,stable')
    booleanParam(name: 'PUSH_LATEST', defaultValue: true, description: '同时推送 :latest')
    booleanParam(name: 'NOCACHE', defaultValue: false, description: '构建时禁用缓存 (--no-cache)')
    string(name: 'DOCKERFILE', defaultValue: 'Dockerfile', description: 'Dockerfile 路径')
    // 如需自定义远端 dind，可放开这个参数
    string(name: 'DOCKER_SERVER', defaultValue: 'tcp://192.168.5.24:22375', description: '远端 Docker daemon')
  }

  environment {
    REGISTRY       = "registry.lan.canye365.cn"
    IMAGE          = "registry.lan.canye365.cn/iris-gallery"
    DOCKER_SERVER  = "tcp://192.168.5.24:22375"
  }

  options {
    timestamps()
    ansiColor('xterm')
    timeout(time: 60, unit: 'MINUTES')
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build & Push (via remote dind)') {
      steps {
        script {
          // 计算版本号：<shortSha>-<buildNum>
          def gitSha = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          def imageTag = "${gitSha}-${env.BUILD_NUMBER}"

          // 组织 tags
          def allTags = ["${env.IMAGE}:${imageTag}"]
          if (params.PUSH_LATEST) {
            allTags << "${env.IMAGE}:latest"
          }
          if (params.EXTRA_TAGS?.trim()) {
            params.EXTRA_TAGS.split(',').collect { it.trim() }.findAll { it }.each { t ->
              allTags << "${env.IMAGE}:${t}"
            }
          }

          // 连接远端 Docker daemon，并在需要时登录私有仓库
          docker.withServer(env.DOCKER_SERVER) {
            // 如果仓库启用了鉴权，这里把 null 换成 Jenkins 凭据ID，如 'registry-cred'
            docker.withRegistry("https://${env.REGISTRY}", null) {
              // 构建命令：多 tag + 可选 no-cache + 自定义 Dockerfile
              def tagArgs = allTags.collect { "-t ${it}" }.join(' ')
              def noCache = params.NOCACHE ? "--no-cache" : ""

              sh """
                set -e
                docker version
                echo "[+] Building: ${allTags.join(', ')}"
                docker build ${noCache} ${tagArgs} -f ${params.DOCKERFILE} .
              """

              // 逐个 push
              allTags.each { t ->
                sh """
                  set -e
                  echo "[+] Pushing: ${t}"
                  docker push ${t}
                """
              }

              // 打印主版本（imageTag）的 digest（方便后续定位）
              sh """
                echo "[+] RepoDigests for ${env.IMAGE}:${imageTag}:"
                docker inspect --format='{{json .RepoDigests}}' ${env.IMAGE}:${imageTag} || true
              """
            }
          }

          // 便于下个 stage / post 使用
          env.BUILT_TAG = imageTag
          env.ALL_TAGS = allTags.join(' ')
        }
      }
    }
  }

  post {
    success {
      echo "✅ Pushed: ${env.ALL_TAGS}"
    }
    failure {
      echo "❌ 构建或推送失败，请查看日志。"
    }
  }
}
