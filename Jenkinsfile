pipeline {
    agent any

    environment {
        IMAGE_NAME = "shakilahamed/eks-ai-simple-java-user-app"
        IMAGE_TAG = "latest"
        KUBE_NAMESPACE = "eks-ai"
        DEPLOYMENT_NAME = "eks-ai"
        KUBE_MANIFEST = "k8/eks-ai.yaml"
        AWS_REGION = "us-west-2"
        EKS_CLUSTER_NAME = "ai-eks-cluster"
        KUBECONFIG_PATH = "/var/lib/jenkins/.kube/config"
    }

    stages {
        stage('Checkout Source') {
            steps {
                git url: 'https://github.com/shakilmunavary/eks-ai-simple-java-user-app.git', branch: 'main'
            }
        }

        stage('Docker Cleanup') {
            steps {
                script {
                    echo "🧹 Cleaning up Docker containers, images, and build cache..."

                    sh '''
                        docker ps -q | xargs -r docker stop
                        docker ps -aq | xargs -r docker rm
                        docker images -q | xargs -r docker rmi -f
                        docker builder prune -f
                        docker volume prune -f
                    '''

                    echo "✅ Docker cleanup complete."
                }
            }
        }

        stage('Build Java App') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build --no-cache -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    sh '''
                        echo $PASSWORD | docker login -u $USERNAME --password-stdin
                        docker push shakilahamed/eks-ai-simple-java-user-app:latest
                    '''
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        echo "🔐 Updating kubeconfig for EKS cluster..."
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} --kubeconfig ${KUBECONFIG_PATH}
                        kubectl delete -f ${KUBE_MANIFEST} 
                        kubectl apply -f ${KUBE_MANIFEST} --validate=false
                        kubectl get svc -n ${KUBE_NAMESPACE}
                        echo "✅ Kubeconfig updated"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Simple Application deployed successfully. Check AI dashboard for diagnostics."
        }
        failure {
            echo "❌ Pipeline failed. Investigate logs and AI feedback."
        }
    }
}
