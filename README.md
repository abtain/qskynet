QSKYNET
=======

By Daniel Quellhorst (dan@abtain.com)


Summary
-------

QSKYNET is a simple way to get a ruby on rails production environment running on 
ubuntu 10.10.

I tend to use RVM on OSX. If you use rvm, you don't need run sudo when installing
gems.

QSKYNET follows [Readme Driven Development](http://tom.preston-werner.com/2010/08/23/readme-driven-development.html)


Installation
------------

Step 1: Install QSKYNET

    $ git clone git@github.com:abtain/qskynet.git

Step 2: SSH into remote system.
    $ ssh quellhorst@10.0.0.5

Step 3: Setup Ruby environment
    $ sudo apt-get install curl git-core build-essential zlib1g-dev libssl-dev libreadline5-dev -y
    $ bash < <( curl http://rvm.beginrescueend.com/releases/rvm-install-head )
    $ echo 'if [[ -s "$HOME/.rvm/scripts/rvm" ]]  ; then source "$HOME/.rvm/scripts/rvm" ; fi' >> ~/.bashrc
    $ # test new terminal with `rvm notes` see if there is output
    $ rvm install 1.9.2
    $ rvm --default ruby-1.9.2
    $ # can test with ruby -v


Static Assets
-------------

Some files are stored in S3 like dotfiles and scripts to bootstrap the
installation. q3.abtain.com is used in the example here and you are
free to use this.

You can also setup your own static assets server on S3. You need to
create a new bucket with the hostname and setup a cname dns entry
pointing your hostname to 's3.amazonaws.com.'

Static assets are synced up with the rake task
    rake deploy:static


Contribute
----------

If you'd like to hack on QSKYNET, start by forking my repo on GitHub:

    http://github.com/abtain/qskynet

To get all of the dependencies, run bundle install.

The best way to get your changes merged back into core is as follows:

1. Clone down your fork
1. Create a topic branch to contain your change
1. Hack away
1. Add tests and make sure everything still passes by running `rake`
1. If you are adding new functionality, document it in the README.md
1. Do not change the version number, I will do that on my end
1. If necessary, rebase your commits into logical chunks, without errors
1. Push the branch up to GitHub
1. Send me (quellhorst) a pull request for your branch


Copyright
---------

Copyright (c) 2010 Daniel Quellhorst. See LICENSE for details.
