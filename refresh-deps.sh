#!/bin/bash

set -x

DEPS=/tmp/deps.txt
NEWDEPS=/tmp/new-deps.txt

rpm -qa --qf "%{NAME}-%{VERSION}\n" | sort > $DEPS
time zypper refresh

time zypper install -y -C \
       glibc-i18ndata \
       glibc-locale \
       automake \
       curl \
       fftw3-devel \
       gcc \
       gcc-c++ \
       git \
       gzip \
       libsndfile-devel \
       libssh2-1 \
       libssh2-devel \
       libtheora-devel \
       libtool \
       make \
       opencv-devel \
       patch \
       qemu \
       qemu-tools \
       qemu-kvm \
       tar \
       which \
       xorg-x11-fonts \
       perl \
       ShellCheck \
       sudo \
       aspell-spell \
       aspell-en \
       systemd-sysvinit \
       systemd libudev1 tack \
       gmp-devel \
       libexpat-devel \
       libxml2-devel \
   && true

time zypper install -y -C \
       'perl(Archive::Extract)' \
       'perl(Class::Accessor)' \
       'perl(Cpanel::JSON::XS)' \
       'perl(Crypt::DES)' \
       'perl(Devel::Cover)' \
       'perl(Devel::Cover::Report::Codecov)' \
       'perl(Exception::Class)' \
       'perl(File::Touch)' \
       'perl(IO::Scalar)' \
       'perl(IPC::Run)' \
       'perl(IPC::System::Simple)' \
       'perl(Mojo::IOLoop::ReadWriteProcess)' \
       'perl(Mojo::JSON)' \
       'perl(Net::DBus)' \
       'perl(Net::SSH2)' \
       'perl(Perl::Critic)' \
       'perl(Perl::Critic::Freenode)' \
       'perl(Pod::Coverage)' \
       'perl(Socket::MsgHdr)' \
       'perl(Test::Exception)' \
       'perl(Test::Fatal)' \
       'perl(Test::MockModule)' \
       'perl(Test::MockObject)' \
       'perl(Test::Mock::Time)' \
       'perl(Test::Output)' \
       'perl(Test::Pod)' \
       'perl(Test::Strict)' \
       'perl(Test::Warnings)' \
       'perl(Try::Tiny)' \
       'perl(XML::LibXML)' \
       'perl(XML::SemanticDiff)' \
  && true

time zypper install -y -C \
       'perl(YAML::PP)' \
  && true

rpm -qa --qf "%{NAME}-%{VERSION}\n" | sort > $NEWDEPS

diff /tmp/deps.txt /tmp/new-deps.txt
