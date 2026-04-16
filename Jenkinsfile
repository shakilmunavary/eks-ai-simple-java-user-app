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
                git url: 'https://github.com/shakilmunavary/eks-ai-simple-java-user-app.git', branch: 'aws_deops_ai_test'
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
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                    string(credentialsId: 'GITHUB_FINE_GRAINED_TOKEN', variable: 'GITHUB_TOKEN')
                ]) {
                    sh '''
                        echo "🔐 Updating kubeconfig for EKS cluster..."
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} --kubeconfig ${KUBECONFIG_PATH}
                        
                        # Create namespace if it doesn't exist
                        kubectl get namespace "${KUBE_NAMESPACE}" > /dev/null 2>&1 || kubectl create namespace "${KUBE_NAMESPACE}"
                        
                        # Create/update GitHub secret from Jenkins credential
                        echo "🔑 Creating GitHub secret from Jenkins credentials..."
                        kubectl delete secret github-secret -n ${KUBE_NAMESPACE} --ignore-not-found
                        kubectl create secret generic github-secret \
                            --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
                            -n ${KUBE_NAMESPACE}
                        
                        # Deploy application
                        kubectl apply -f ${KUBE_MANIFEST}
                        
                        # Restart deployment to pick up new secret
                        kubectl rollout restart deployment eks-ai-deployment -n ${KUBE_NAMESPACE}
                        
                        sleep 10
                        kubectl get svc -n ${KUBE_NAMESPACE}
                        echo "✅ Deployment complete"
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
