# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG

ARG GO_IMAGE_NAME
ARG GO_IMAGE_TAG
FROM ${GO_IMAGE_NAME}:${GO_IMAGE_TAG} AS builder

ARG LIBRESPEED_GO_VERSION

COPY scripts/start-librespeed-go.sh /scripts/
COPY patches /patches

# hadolint ignore=DL4006,SC3009
RUN \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    && homelab install git patch \
    && mkdir -p /root/librespeed-go-build \
    # Download librespeed-go repo. \
    && homelab download-git-repo \
        https://github.com/librespeed/speedtest-go \
        ${LIBRESPEED_GO_VERSION:?} \
        /root/librespeed-go-build \
    && pushd /root/librespeed-go-build \
    # Apply the patches. \
    && (find /patches -iname *.diff -print0 | sort -z | xargs -0 -r -n 1 patch -p2 -i) \
    # Build librespeed-go. \
    && go mod tidy \
    && CGO_ENABLED=0 GOOS=linux go build -a -ldflags "-w -s" -trimpath -o librespeed-go . \
    && popd \
    # Copy the build artifacts. \
    && mkdir -p /output/{bin,scripts,assets,configs} \
    && cp /root/librespeed-go-build/librespeed-go /output/bin \
    && cp /root/librespeed-go-build/web/assets/{*.html,*.js} /output/assets \
    && cp /root/librespeed-go-build/settings.toml /output/configs \
    && cp /scripts/* /output/scripts

FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG LIBRESPEED_GO_VERSION

# hadolint ignore=SC3009
RUN --mount=type=bind,target=/librespeed-go-build,from=builder,source=/output \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    && mkdir -p /opt/librespeed-go-${LIBRESPEED_GO_VERSION:?}/bin /data/librespeed-go/{assets,assets-default,config,data} \
    && cp /librespeed-go-build/bin/librespeed-go /opt/librespeed-go-${LIBRESPEED_GO_VERSION:?}/bin \
    && cp /librespeed-go-build/assets/*.html /data/librespeed-go/assets-default/ \
    && cp /librespeed-go-build/assets/*.js /data/librespeed-go/assets/ \
    && cp /librespeed-go-build/configs/settings.toml /data/librespeed-go/config/settings-default.toml \
    # Use the right assets path in the default settings file. \
    && sed -i 's#^assets_path=""$#assets_path="/data/librespeed-go/assets"#' /data/librespeed-go/config/settings-default.toml \
    && ln -sf /opt/librespeed-go-${LIBRESPEED_GO_VERSION:?} /opt/librespeed-go \
    && ln -sf /opt/librespeed-go/bin/librespeed-go /opt/bin/librespeed-go \
    # Copy the start-librespeed-go.sh script. \
    && cp /librespeed-go-build/scripts/start-librespeed-go.sh /opt/librespeed-go/ \
    && ln -sf /opt/librespeed-go/start-librespeed-go.sh /opt/bin/start-librespeed-go \
    # Set up the permissions. \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} \
        /opt/librespeed-go-${LIBRESPEED_GO_VERSION:?} \
        /opt/librespeed-go \
        /opt/bin/{librespeed-go,start-librespeed-go} \
        /data/librespeed-go \
    # Clean up. \
    && homelab cleanup

# Expose the port used by librespeed go speedtest.
EXPOSE 8989

HEALTHCHECK \
    --start-period=15s --interval=30s --timeout=3s \
    CMD homelab healthcheck-service https://localhost:8989/

ENV USER=${USER_NAME}
USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-librespeed-go"]
STOPSIGNAL SIGTERM
