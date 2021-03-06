FROM ubuntu:18.04

LABEL maintainer="tan.quach@birchwoodlangham.com"

ARG password
ARG user=user

ENV CT_VERSION=2.4.0 \
  GO_VERSION=1.14.1 \
  SBT_VERSION=1.3.9 \
  PROTOC_VERSION=3.11.4 \
  HELM_VERSION=2.16.5 \
  IDEA_VERSION=2019.3.4 \
  TERM=xterm-256color \
  CODE_SERVER_VERSION=3.0.2 \
  GOLANGCI_LINT_VERSION=1.24.0

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
  apt-get -y upgrade && \
  apt-get -y install apt-utils && \
  apt-get -y install dialog git vim software-properties-common debconf-utils wget curl apt-transport-https bzip2 iputils-ping telnet net-tools iproute2

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --fix-missing libxext-dev libxrender-dev libxslt1.1 \
  libxtst-dev libgtk2.0-0 libcanberra-gtk-module libxss1 libxkbfile1 \
  gconf2 gconf-service libnotify4 libnss3 gvfs-bin xdg-utils 

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --fix-missing sudo zsh fonts-powerline \
  openjdk-11-jdk go-dep build-essential locales apt-transport-https ca-certificates gnupg-agent \
  software-properties-common httpie unzip gosu git-flow

RUN locale-gen en_US.UTF-8 && \
  fc-cache -f

# Setup user
RUN  useradd -d /home/${user} -m -U ${user} -G sudo -s /usr/bin/zsh 

# Allow the user to run sudo commands without requiring a password
RUN echo ${user}' ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Install Go globally and link to /usr/lib/go for compatibility with Arch host
RUN wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
  tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
  rm go${GO_VERSION}.linux-amd64.tar.gz && \
  ln -s /usr/local/go /usr/lib/go

# Install SBT and Scala
RUN DEBIAN_FRONTEND=noninteractive && \
  echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list && \
  curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add && \
  sudo apt-get update && \
  sudo apt-get install sbt

# Install Docker 
RUN curl https://get.docker.com | bash && \ 
  apt-get -y install docker-compose && \
  usermod -aG docker ${user}

# Install protoc
RUN PROTOC_ZIP=protoc-${PROTOC_VERSION}-linux-x86_64.zip &&\
  curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/$PROTOC_ZIP  &&\
  unzip -o $PROTOC_ZIP -d /usr/local bin/protoc  &&\
  rm -f $PROTOC_ZIP

# Install Kubernetes
RUN DEBIAN_FRONTEND=noninteractive && \
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
  echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list && \
  apt-get update && \
  apt-get install -y kubectl

# Install Helm
RUN wget https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
  tar xzf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
  mv linux-amd64/helm /usr/local/bin/ && \
  rm -f helm-v${HELM_VERSION}-linux-amd64.tar.gz &&\
  rm -fr linux-amd64

# Install Nodejs and Yarn
RUN DEBIAN_FRONTEND=noninteractive && \
  curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
  curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  apt-get update && \
  apt-get install -y nodejs && \
  apt-get install yarn

# Install Helm chart testing
RUN mkdir /ct && cd /ct && \ 
  curl -Lo chart-testing_${CT_VERSION}_linux_amd64.tar.gz https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}/chart-testing_${CT_VERSION}_linux_amd64.tar.gz  && \
  tar xzf chart-testing_${CT_VERSION}_linux_amd64.tar.gz  && \
  chmod +x ct && sudo mv ct /usr/local/bin/  && \
  mv etc /etc/ct && \
  cd / && rm -fr /ct

# Install IntelliJ idea
RUN mkdir -p /opt/idea && \
  wget https://download.jetbrains.com/idea/ideaIU-${IDEA_VERSION}-no-jbr.tar.gz && \
  tar -C /opt/idea -zxf ideaIU-${IDEA_VERSION}-no-jbr.tar.gz --strip-components=1 && \
  rm ideaIU-${IDEA_VERSION}-no-jbr.tar.gz && \
  ln -s /opt/idea/bin/idea.sh /usr/local/bin/idea.sh

# Install Postman
RUN wget https://dl.pstmn.io/download/latest/linux64 -O Postman-linux.tar.gz && \
  tar -C /opt -xf Postman-linux.tar.gz && \
  ln -s /opt/Postman/Postman /usr/local/bin/Postman && \
  rm Postman-linux.tar.gz

# Clean up apt
RUN apt-get autoremove -y -qq && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Install visual studio code server
RUN wget https://github.com/cdr/code-server/releases/download/${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-x86_64.tar.gz && \
  tar -zxf code-server-${CODE_SERVER_VERSION}-linux-x86_64.tar.gz --transform 's/code-server-.*-linux-x86_64/code-server/' && \
  rm -f code-server-${CODE_SERVER_VERSION}-linux-x86_64.tar.gz

# Install the vscode plugins
RUN mkdir -p /code-server/extensions && \
  mkdir -p /code-server/user-data/User && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension shan.code-settings-sync && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension ms-vscode.go --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension grapecity.gc-excelviewer --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension eamodio.gitlens --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension ckolkman.vscode-postgres --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension mechatroner.rainbow-csv --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension andyyaldoo.vscode-json --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension zxh404.vscode-proto3 --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension dotjoshjohnson.xml --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension redhat.vscode-yaml --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension donjayamanne.python-extension-pack --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension nodesource.vscode-for-node-js-development-pack --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension piotrpalarz.vscode-gitignore-generator --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension bungcip.better-toml --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension coenraads.bracket-pair-colorizer-2 --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension vadimcn.vscode-lldb --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension serayuzgur.crates --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension batisteo.vscode-django --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension ms-azuretools.vscode-docker --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension p1c2u.docker-compose --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension felipecaputo.git-project-manager --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension premparihar.gotestexplorer --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension oderwat.indent-rainbow --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension wholroyd.jinja --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension magicstack.magicpython --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension sdras.night-owl --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension fabiospampinato.vscode-projects-plus --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension fabiospampinato.vscode-projects-plus-todo-plus --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension ms-python.python --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension rust-lang.rust --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension hdevalke.rust-test-lens --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension polypus74.trusty-rusty-snippets --force && \
  /code-server/code-server --extensions-dir /code-server/extensions --install-extension redhat.vscode-xml --force

# change ownership of the code-server to the container's user
RUN chown -R ${user}:${user} /code-server

# Now that we have done all the installations at a root leve we need, we will switch to the user
# context and continue installing user level applications and configuraions
USER ${user}
WORKDIR /home/${user}

# Install Oh My Zsh
RUN curl -Lo install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh && \
  sh install.sh --unattended && \
  rm install.sh

RUN git clone https://github.com/zplug/zplug .zplug

ENV GOPATH=/home/${user}/go
ENV GOROOT=/usr/lib/go
ENV CARGO_PATH=/home/${user}/.cargo
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin:$CARGO_PATH/bin

# Set up Rust in the user environment    
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
  /home/${user}/.cargo/bin/rustup component add clippy llvm-tools-preview rls rust-analysis rustfmt rust-src

# Install Miniconda for Python environments
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
  sh Miniconda3-latest-Linux-x86_64.sh -b && \
  rm Miniconda3-latest-Linux-x86_64.sh

# Add the go tools required by the vscode.go plugin
RUN go get -u -v github.com/ramya-rao-a/go-outline  && \
  go get -u -v github.com/acroca/go-symbols  && \
  go get -u -v github.com/mdempsky/gocode  && \
  go get -u -v github.com/rogpeppe/godef  && \
  go get -u -v golang.org/x/tools/cmd/godoc  && \
  go get -u -v github.com/zmb3/gogetdoc  && \
  go get -u -v golang.org/x/lint/golint  && \
  go get -u -v github.com/fatih/gomodifytags  && \
  go get -u -v golang.org/x/tools/cmd/gorename  && \
  go get -u -v sourcegraph.com/sqs/goreturns  && \
  go get -u -v golang.org/x/tools/cmd/goimports  && \
  go get -u -v github.com/cweill/gotests/...  && \
  go get -u -v golang.org/x/tools/cmd/guru  && \
  go get -u -v github.com/josharian/impl  && \
  go get -u -v github.com/haya14busa/goplay/cmd/goplay  && \
  go get -u -v github.com/uudashr/gopkgs/cmd/gopkgs  && \
  go get -u -v github.com/davidrjenni/reftools/cmd/fillstruct  && \
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v${GOLANGCI_LINT_VERSION} && \
  GO111MODULE=on go get golang.org/x/tools/gopls@latest && \
  go get -u -v github.com/go-delve/delve/cmd/dlv && \
  go get -u -v github.com/golang/protobuf/protoc-gen-go && \
  go get -u honnef.co/go/tools/... && \
  go get -u github.com/mgechev/revive

# Use this one to install the plugins etc.
COPY fonts /home/${user}/.local/share/.fonts

COPY zshrc /home/${user}/.zshrc
COPY p10k.zsh /home/${user}/.p10k.zsh
COPY Xdefaults /home/${user}/.Xdefaults

RUN sudo chown -R ${user}:${user} . && \
  fc-cache -f && \
  /usr/bin/zsh -c 'source .zshrc'

COPY entrypoint.sh /entrypoint.sh

VOLUME [ "/code-server/extensions", "/code-server/user-data/User" ]

ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ "/code-server/code-server", "--auth", "none", "--disable-ssh", "--user-data-dir", "/code-server/user-data", "--host", "0.0.0.0", "--extensions-dir", "/code-server/extensions" ]
