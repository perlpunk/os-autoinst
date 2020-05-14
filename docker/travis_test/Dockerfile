#!BuildTag: os-autoinst_dev
FROM opensuse/leap:15.1

# Define environment variable
ENV NAME openQA test environment
ENV LANG en_US.UTF-8

RUN zypper ar -f -G 'http://download.opensuse.org/repositories/devel:/openQA:/Leap:/15.1/openSUSE_Leap_15.1' devel_openqa

RUN zypper in -y -C \
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

RUN zypper in -y -C \
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

RUN echo \
       chromedriver \
       optipng \
       postgresql-devel \
       postgresql-server \
       python3-base \
       python3-future \
       python3-requests \
       python3-setuptools \
       python3-yamllint \
       'rubygem(sass)' \
       sqlite3 \
       'perl(Archive::Extract)' \
       'perl(BSD::Resource)' \
       'perl(CSS::Minifier::XS)' \
       'perl(Carp::Always)' \
       'perl(Class::Accessor::Fast)' \
       'perl(Config)' \
       'perl(Config::IniFiles)' \
       'perl(Config::Tiny)' \
       'perl(Cwd)' \
       'perl(DBD::Pg)' \
       'perl(DBD::SQLite)' \
       'perl(DBIx::Class)' \
       'perl(DBIx::Class::DeploymentHandler)' \
       'perl(DBIx::Class::DynamicDefault)' \
       'perl(DBIx::Class::OptimisticLocking)' \
       'perl(DBIx::Class::Schema::Config)' \
       'perl(Data::Dump)' \
       'perl(Data::Dumper)' \
       'perl(Digest::MD5) >= 2.55' \
       'perl(Data::OptList)' \
       'perl(DateTime::Format::Pg)' \
       'perl(DateTime::Format::SQLite)' \
       'perl(ExtUtils::MakeMaker) >= 7.12' \
       'perl(File::Copy::Recursive)' \
       'perl(IO::Socket::SSL)' \
       'perl(JSON::XS)' \
       'perl(JavaScript::Minifier::XS)' \
       'perl(LWP::Protocol::https)' \
       'perl(Minion) >= 10.0' \
       'perl(Module::CPANfile)' \
       'perl(Module::Pluggable)' \
       'perl(Mojo::Pg)' \
       'perl(Mojo::RabbitMQ::Client)' \
       'perl(Mojo::SQLite)' \
       'perl(Minion::Backend::SQLite)' \
       'perl(Mojolicious)' \
       'perl(Mojolicious::Plugin::AssetPack)' \
       'perl(Mojolicious::Plugin::RenderFile)' \
       'perl(JSON::Validator)' \
       'perl(YAML::PP) >= 0.020' \
       'perl(YAML::XS) >= 0.67' \
       'perl(Net::OpenID::Consumer)' \
       'perl(Net::SNMP)' \
       'perl(Perl::Tidy)' \
       'perl(Pod::POM)' \
       'perl(Pod::Spell)' \
       'perl(SQL::SplitStatement)' \
       'perl(SQL::Translator)' \
       'perl(Selenium::Remote::Driver)' \
       'perl(Sort::Versions)' \
       'perl(Test::Compile)' \
       'perl(Test::Fatal)' \
       'perl(Socket::MsgHdr)' \
       'perl(Text::Diff)' \
       'perl(CommonMark)' \
       'perl(Time::ParseDate)' \
       'perl(XSLoader) >= 0.24' \
       perl-Archive-Extract \
       perl-Test-Simple \
       'perl(aliased)' \
    && true


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
