FROM              docker.io/redhat/ubi9
RUN               curl -L -o /etc/yum.repos.d/hashi.repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
RUN               curl -o /etc/yum.repos.d/docker.repo https://download.docker.com/linux/rhel/docker-ce.repo
RUN               dnf install libicu make terraform docker-ce-cli unzip -y
RUN               cd /tmp && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf aws*
RUN               curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /bin/kubectl && chmod +x /bin/kubectl
# NODEJS
RUN               dnf module disable nodejs -y && dnf module enable nodejs:22 -y && dnf install nodejs npm -y
# MAVEN
RUN               dnf install maven -y
# HELM
RUN               curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# ARGOCD
RUN               curl -sSL -o /bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x /bin/argocd
# TRIVY
RUN               dnf install https://github.com/aquasecurity/trivy/releases/download/v0.65.0/trivy_0.65.0_Linux-64bit.rpm -y
RUN               useradd github
USER              github
WORKDIR           /home/github
RUN               curl -o actions-runner-linux-x64-2.330.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.330.0/actions-runner-linux-x64-2.330.0.tar.gz && tar xzf ./actions-runner-linux-x64-2.330.0.tar.gz && rm -f actions-runner-linux-x64-2.330.0.tar.gz
RUN               curl -L -o sonar-scanner-cli-7.1.0.4889-linux-x64.zip "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-7.1.0.4889-linux-x64.zip?_gl=1*1aqu2g8*_gcl_au*MTgxMzM0NDY3NC4xNzU0MDA5MTU1*_ga*MTM4MTA5NDI5Ni4xNzU0MDA5MTU1*_ga_9JZ0GZ5TC6*czE3NTQwMDkxNTQkbzEkZzEkdDE3NTQwMDk4NzAkajU5JGwwJGgw" && unzip sonar-scanner-cli-7.1.0.4889-linux-x64.zip && rm -f sonar-scanner-cli-7.1.0.4889-linux-x64.zip
COPY              run.sh /
ENTRYPOINT        ["bash", "/run.sh"]
