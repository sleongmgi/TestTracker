TestTracker
===========

Track Perl module and test relationships so you can guess what are the best tests to run.

Building the Ubuntu Lucid Package
=================================

1.  Build a docker image using the Dockerfile provided below.

    ```bash
    FROM jmmills/plenv:latest 
    MAINTAINER = Shin Leong <sleong@wustl.edu>
    RUN apt-get update && apt-get install -y libssl-dev
    RUN cpanm -n CPAN
    RUN cpanm -n Dist::Zilla
    RUN /usr/bin/cpan App::cpanminus
    RUN ln -s /usr/local/bin/cpanm /usr/bin/cpanm
    RUN /usr/bin/cpanm -n Sub::Override
    RUN /usr/bin/cpanm -n DBI
    RUN /usr/bin/cpanm -n IPC::Run
    RUN /usr/bin/cpanm -n YAML
    RUN /usr/bin/cpanm -n DBD::SQLite
    RUN cpanm -n Sub::Override
    RUN cpanm -n DBI
    RUN cpanm -n IPC::Run
    RUN cpanm -n YAML
    RUN cpanm -n DBD::SQLite
    RUN apt-get install -y git-buildpackage
    RUN apt-get install -y dh-make-perl
    RUN mkdir /project
    RUN chmod -R 0777 /.cpanm
    RUN cpanm -n Dist::Zilla
    RUN chmod -R 0777 /.plenv
    RUN mkdir /.dzil && chmod 0777 /.dzil
    RUN mkdir /.dh-make-perl && chmod -R 0777 /.dh-make-perl
    RUN mkdir /.gnupg && chmod 0777 /.gnupg
    RUN echo "#/bin/env bash\n\
    # \$0 <user id> <user name> <email> <package version>\n\
    # Example,\n\
    #    . build.sh \"sleong\" \"Shin Leong\" sleong@wustl.edu 0.039\n\
    if [[ \$# -ne 4 ]]; then\n\
        echo -e \"\\\\n\\\\\n\
    Syntax:\\\\n\\\\\n\
    \\\\n\\\\\n\
    \$0 <unix_login> <user name> <email> <version>\\\\n\\\\\n\
    \\\\n\\\\\n\
    Example,\\\\n\\\\\n\
       \$0 \\\"sleong\\\" \\\"Shin Leong\\\" sleong@wustl.edu 0.039\\\\n\\\\\n\
    \"\n\
        exit;\n\
    fi\n\
    unix_login=\$1\n\
    user_name=\$2\n\
    email=\$3\n\
    version=\$4\n\
    \n\
    useradd -ms /bin/bash -p 123456 -c \"\$user_name\" \$unix_login\n\
    \n\
    echo -e \"[%User]\\\\n\\\\\n\
    name  = \$user_name\\\\n\\\\\n\
    email = \$email\\\\n\\\\\n\
    \\\\n\\\\\n\
    [%Rights]\\\\n\\\\\n\
    license_class    = Perl_5\\\\n\\\\\n\
    copyright_holder = \$user_name\\\\n\\\\\n\
    \" > /.dzil/config.ini\n\
    \n\
    git config --global user.email \$email\n\
    git config --global user.name \"\$user_name\"\n\
    echo -e \"cd /home/\$unix_login && git clone https://github.com/genome/TestTracker.git\\\\n\\\\\n\
    cd /home/\$unix_login/TestTracker && git checkout -b ubuntu-lucid origin/ubuntu-lucid && dzil authordeps --missing | cpanm\\\\n\\\\\n\
    rm -rf debian Makefile.PL README LICENSE META.yml MANIFEST\\\\n\\\\\n\
    V=\$version dzil build\\\\n\\\\\n\
    cp TestTracker-\$version.tar.gz libtesttracker-perl_\$version.orig.tar.gz\\\\n\\\\\n\
    dh-make-perl --email \"\$email\" TestTracker-\$version\\\\n\\\\\n\
    cd TestTracker-\$version\\\\n\\\\\n\
    perl -p -i -e 's/unstable/lucid-genome-development/' debian/changelog\\\\n\\\\\n\
    gpg --import /project/my_pgp.key\\\\n\\\\\n\
    debuild\\\\n\\\\\n\
    cp -r ../libtesttracker-perl* /project/\\\\n\\\\\n\
    \" > /home/\$unix_login/build_debian_package.sh\n\
    sudo -u \$unix_login bash -l /home/\$unix_login/build_debian_package.sh\n\
    cp -r /home/\$unix_login/TestTracker/libtesttracker-perl* /project/\n" > /usr/local/bin/build_test_tracker_debian_package.sh
    CMD bash -l "/usr/local/bin/build_test_tracker_debian_package.sh"
    #
    #To run this docker image to build the libtesttracker-perl debian module,
    #you will use the following command.  Provided you have you pgp key in
    #the directory /my_directory_path.  The b94385fedf1b is my docker image
    #id.  For you case, you will replace the b94385fedf1b image id with
    #your docker image id.
    #
    # docker run -it -v /my_directory_path:/project b94385fedf1b
    # /usr/local/bin/build_test_tracker_debian_package.sh  "sleong" "Shin
    # Leong" sleong@wustl.edu 0.039
    ```
 
2.  To run this docker dockerfile to build a __libtesttracker-perl__ debian package,
    you will use the following command.  Provided you have you __pgp__ key in
    the directory __/my_directory_path__.  The __b94385fedf1b__ is my docker image
    id.  For you case, you will replace the __b94385fedf1b__ image id with
    your docker image id.  In addition, the result __libtesttracker-perl*.deb__
    package will be copied to __/my_directory_path__. 

    ```bash
    docker run -it -v /my_directory_path:/project b94385fedf1b\
        /usr/local/bin/build_test_tracker_debian_package.sh\
        <unix login> <user name> <email> <version>
    ```

    Example,

    ```bash
    docker run -it -v /my_directory_path:/project b94385fedf1b\
        /usr/local/bin/build_test_tracker_debian_package.sh\
        "sleong" "Shin Leong" sleong@wustl.edu 0.039
    ```

3.  Test package locally.
 
    ```bash
    dpkg -i libtesttracker-perl_$PKG_VERSION*.deb
    ```

4.  Push package to repo. __You need to add your pgp key to the debian repository server__.

    ```bash
    dput lucid-genome-development libtesttracker-perl_$PKG_VERSION*.changes
    ```

# SCHEMA

For Postgres, assuming a `test_tracker_admin` owns the database and a `test_tracker` user for running TestTracker:

    CREATE TABLE test_tracker.test (
      id SERIAL,
      name text,
      duration integer,
      PRIMARY KEY (id)
    );
    CREATE TABLE test_tracker.module (
      id SERIAL,
      name text,
      PRIMARY KEY (id)
    );
    CREATE TABLE test_tracker.module_test (
      module_id integer,
      test_id integer,
      FOREIGN KEY (module_id) REFERENCES test_tracker.module(id),
      FOREIGN KEY (test_id) REFERENCES test_tracker.test(id)
    );

    CREATE INDEX idx_test_tracker_module_name ON test_tracker.module ("name");
    CREATE INDEX idx_test_tracker_test_name ON test_tracker.test ("name");
    CREATE INDEX idx_test_tracker_test_duration ON test_tracker.test ("duration");
    CREATE INDEX idx_test_tracker_module_test_module_id ON test_tracker.module_test ("module_id");
    CREATE INDEX idx_test_tracker_module_test_test_id ON test_tracker.module_test ("test_id");

    GRANT USAGE ON SCHEMA test_tracker TO test_tracker;
    GRANT USAGE ON ALL SEQUENCES IN SCHEMA test_tracker TO test_tracker;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA test_tracker TO test_tracker;
