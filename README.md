TestTracker
===========

Track Perl module and test relationships so you can guess what are the best tests to run.

Building the Ubuntu Lucid Package
=================================

These notes are a work in progress and specific to my environment. PSEUDO CODE:

    SRC_VERSION="0.006"
    PKG_VERSION="$SRC_VERSION-1"
    DISTRO="ubuntu-lucid"

    dzil release
    rm -rf TestTracker-$SRC_VERSION # Removed "temp" directory...
    mv TestTracker-$SRC_VERSION.tar.gz /tmp/
    git tag -a -m '' v$SRC_VERSION # If you don't upload the release we still need to tag...

    # import the dist using git-buildpackage
    git checkout $DISTRO
    git-import-orig /tmp/TestTracker-$SRC_VERSION.tar.gz
    rm -f /tmp/TestTracker-$SRC_VERSION.tar.gz

    # update the changelog
    dch -v $PKG_VERSION
    git commit -m "Updated changelog for $PKG_VERSION." debian/changelog
    git tag -a -m "" $DISTRO/$PKG_VERSION
    git push --all
    git push --tags

    # build package
    ssh vmpool39
    PKG_VERSION=$PKG_VERSION
    cd ~/git-buildpackage/TestTracker
    git pull --ff-only
    git-buildpackage -us -uc -S
    rm -rf ~/sbuild/build/*
    cd ..
    sbuild --source --dist=lucid-amd64 --arch-all libtesttracker-perl_$PKG_VERSION.dsc
    rsync -av --delete /home/vmuser/sbuild/build/ nnutter@linus43:~/pkg/
    logout

    # Test package locally.
    dpkg -i ~/pkg/libtesttracker-perl_$PKG_VERSION*.deb

    # Push package to repo.
    cd ~/pkg
    tgi-dput libtesttracker-perl_$PKG_VERSION*.changes

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
