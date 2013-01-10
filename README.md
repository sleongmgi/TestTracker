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
    git-dch -N $PKG_VERSION
    git commit -m "Updated changelog for $PKG_VERSION." debian/changelog
    git tag -a -m "" $DISTRO/$PKG_VERSION
    git push --all
    git push --tags

    # build package
    ssh vmpool39
    cd ~/git-buildpackage/TestTracker
    git pull --ff-only
    git-buildpackage -us -uc -S
    rm -rf ~/sbuild/build/*
    cd ~/git-buildpackage
    sbuild --source --dist=lucid-amd64 --arch-all libtesttracker-perl_$PKG_VERSION.dsc
    rsync -av --delete /home/vmuser/sbuild/build/ nnutter@linus43:~/pkg/
    tgi-dput ~/pkg/libtesttracker-perl_$PKG_VERSION*.changes
