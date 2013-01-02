TestTracker
===========

Track Perl module and test relationships so you can guess what are the best tests to run.

Building the Ubuntu Lucid Package
=================================

These notes are a work in progress and specific to my environment.

    dzil release
    V=0.004 # e.g.
    mv TestTracker-$V.tar.gz ../
    rm -rf TestTracker-$V
    git tag -a -m '' v$V

    # import the dist using git-buildpackage
    git checkout ubuntu-lucid
    git-import-orig ../TestTracker-$V.tar.gz

    # update the changelog
    git-dch
    git add debian/changelog
    git commit -m 'updated changelog'
    git tag -a -m '' $V-1 # e.g.

    # build package
    ssh vmpool39
    cd ~/git-buildpackage/TestTracker
    git pull -ff-only
    git-buildpackage -us -uc -S
    rm -rf ~/sbuild/build/*
    cd ~/git-buildpackage
    sbuild --source --dist=lucid-amd64 --arch-all libtesttracker-perl_$V-1.dsc
    rsync -av --delete /home/vmuser/sbuild/build/ nnutter@linus43:~/pkg/
    tgi-dput ~/pkg/libtesttracker-perl_$V-1*.changes
