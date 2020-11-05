#!BuildTag: os-autoinst_dev
FROM opensuse/leap:15.1

# Define environment variable
ENV NAME openQA test environment
ENV LANG en_US.UTF-8
RUN zypper ar -f http://download.opensuse.org/repositories/devel:/openQA:/Leap:/15.1/openSUSE_Leap_15.1 openQA && \
    zypper --gpg-auto-import-keys ref && \
    zypper --non-interactive in ca-certificates-mozilla curl && \
    zypper --non-interactive in --force-resolution openQA-local-db apache2 hostname which w3m


#RUN zypper ar -f -G 'http://download.opensuse.org/repositories/devel:/openQA:/Leap:/15.2/openSUSE_Leap_15.2' devel_openqa


# Comment this out to run on newer docker versions
# Otherwise you'll get:
# This QEMU binary requires the membarrier system call.
# Please upgrade your system to a newer version of Linux

#RUN zypper -n addrepo http://download.opensuse.org/repositories/devel:/openQA:/ci/openSUSE_Leap_15.2 qemu \
#    && zypper -n --gpg-auto-import-keys --no-gpg-checks refresh \
#    && zypper -n in --from qemu qemu qemu-x86 qemu-tools qemu-ipxe qemu-sgabios qemu-seabios

VOLUME ["/sys/fs/cgroup", "/run"]

CMD ["/sbin/init"]

ENV OPENQA_DIR /opt/openqa
ENV NORMAL_USER squamata

RUN echo "$NORMAL_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN useradd -r -d /home/$NORMAL_USER -m -g users --uid=1000 $NORMAL_USER
VOLUME [ "/opt/openqa" ]

# explicitly set user/group IDs

RUN mkdir -p /opt/testing_area
RUN chown -R $NORMAL_USER:users /opt/testing_area

ENTRYPOINT ["/bin/bash"]
WORKDIR $OPENQA_DIR
