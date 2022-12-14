FROM debian:bullseye-slim

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG UPGRADE_PACKAGES="false"

ENV APP_TMP_DATA=/tmp

COPY library-scripts/*.sh /tmp/library-scripts/
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && /bin/bash /tmp/library-scripts/common-debian.sh "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
  && /bin/bash /tmp/library-scripts/fish-debian.sh "${USERNAME}" \
  && /bin/bash /tmp/library-scripts/sshd-debian.sh "2222" "${USERNAME}" "true" "root" \
  #
  # ****************************************************************************
  # * TODO: Add any additional OS packages you want included in the definition *
  # * here. We want to do this before cleanup to keep the "layer" small.       *
  # ****************************************************************************
  && apt-get -y install --no-install-recommends build-essential bzip2 default-jre gnupg2 systemd systemd-sysv zlib1g-dev zlib1g libreadline-dev libssl-dev vim \
  #
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts

RUN echo  "StreamLocalBindUnlink yes" >> /etc/ssh/sshd_config && \
  systemctl --global mask gpg-agent.service \
  gpg-agent.socket gpg-agent-ssh.socket \
  gpg-agent-extra.socket gpg-agent-browser.socket && \
  systemctl enable ssh

# Set up default Fish config.
RUN su ${USERNAME} -c "fish --command 'cp /usr/share/fish/config.fish ~/.config/fish/'"

# Configure default Git editor.
RUN su ${USERNAME} -c "echo 'set -Ux GIT_EDITOR vim' >> ~/.config/fish/config.fish"

# Install rbenv.
RUN su ${USERNAME} -c "git clone --depth=1 \
  -c core.eol=lf \
  -c core.autocrlf=false \
  -c fsck.zeroPaddedFilemode=ignore \
  -c fetch.fsck.zeroPaddedFilemode=ignore \
  -c receive.fsck.zeroPaddedFilemode=ignore \
  https://github.com/rbenv/rbenv.git ~/.rbenv"

# Add rbenv to Fish user PATH.
RUN su ${USERNAME} -c "echo 'set -Ux fish_user_paths ~/.rbenv/bin $fish_user_paths' >> ~/.config/fish/config.fish"
RUN su ${USERNAME} -c "echo 'status --is-interactive; and rbenv init - | source' >> ~/.config/fish/config.fish"

# Install rbenv ruby-build plugin.
RUN su ${USERNAME} -c "mkdir -p ~/.rbenv/bin/plugins"
RUN su ${USERNAME} -c "git clone --depth=1 \
  -c core.eol=lf \
  -c core.autocrlf=false \
  -c fsck.zeroPaddedFilemode=ignore \
  -c fetch.fsck.zeroPaddedFilemode=ignore \
  -c receive.fsck.zeroPaddedFilemode=ignore \
  https://github.com/rbenv/ruby-build.git ~/.rbenv/bin/plugins/ruby-build"
RUN su ${USERNAME} -c "sudo ~/.rbenv/bin/plugins/ruby-build/install.sh"

# Install Fisher and plugins.
RUN su ${USERNAME} -c "fish --command 'curl -sL https://git.io/fisher | source && fisher install jorgebucaran/{fisher,nvm.fish}'"

# ENV Variables required by Jekyll.
ENV LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en \
  TZ=Etc/UTC \
  LC_ALL=en_US.UTF-8 \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US

USER ${USERNAME}
ENTRYPOINT ["/usr/local/share/ssh-init.sh"]
CMD ["sleep", "infinity"]
