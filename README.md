# redmine_medelexis

Build status on tracis-ci: [https://travis-ci.org/ngiger/redmine_medelexis.svg?branch=master](https://travis-ci.org/ngiger/redmine_medelexis)

A few goodies for the Medelexis MIS

* admin-users see the api_key of all users
* hooks are called after create/editing service tickets

## TODO

* Scripts for the hooks

## installation

### requirements

With redmine 3.2.7 you need ruby < 2.3. In Debian Stretch we have Ruby 2.3.3. Therefore I had to install rbenv and the following packages to be
able to build ruby 2.2.7

* gcc-6 autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev
* libssl1.0-dev libffi-dev

Then use the following commands

    cd /path/to/redmine/plugins
    git clone git`github.com:ngiger/redmine_medelexis.github
    service restart redmine
    [09:51:04] Marco Descher: Für Admin user https://mis.foo.org/mustermann/license.xml
    [09:52:15] Marco Descher:  https://mis.foo.org/my/license - list of all service tickets
    [09:52:23] Marco Descher:  https://mis.foo.org/my/license.xml - encrypted and signed license
    [09:52:35] Marco Descher: https://mis.foo.org/mustermann/license - list of all service tickets
    [09:52:42] Marco Descher: https://mis.foo.org/mustermann/license.xml -encrypted and signed license

Im logger IP-Adresse des Aufrufes abspeichern.

## configuration

Under http://foo.org/settings/plugin/redmine_medelexis you can add more debugging (to the default system logger) and to keep the temporary license files.

## Installation from scratch for development

Get the needed zip files. Used versions are found under https://mis.foo.org/admin/info
* rails-4.2.7.1
* redmine 3.2.7.stable
* redmine_access_filters         0.0.1
* redmine_checklists             3.1.6
* redmine_contacts               4.1.1
* redmine_contacts_helpdesk      3.0.8
* redmine_contacts_invoices      4.1.6
* redmine_medelexis              0.2.1
* redmine_products               2.0.4
* redmineup_tags                 2.0.0

Afterwards execute and verify these steps (assuming a bash shell). Using ruby 1.9.3p547 was fine for me. Ruby 2.1.2 had some problems

    git clone https://github.com/redmine/redmine redmine-3.4
    cd redmine-3.4
    git checkout 3.4-stable
    export RAILS_ENV=development
    cd plugins
    unzip /path/to/zipfiles/redmine_checklists-3_1_14-pro.zip
    unzip /path/to/zipfiles/redmine_contacts_invoices-4_1_7-pro.zip
    unzip /path/to/zipfiles/redmine_products-2_0_6-pro.zip
    unzip /path/to/zipfiles/redmine_contacts_helpdesk-4_0_2-pro.zip
    unzip /path/to/zipfiles/redmine_crm-4_2_3-pro.zip
    unzip /path/to/zipfiles/redmineup_tags-2_0_4-light.zip
    git clone https://github.com/abahgat/redmine_didyoumean
    git clone https://github.com/syntacticvexation/redmine_favourite_projects
    cd redmine_favourite_projects; git checkout redmine3.4-compatible; cd ..
    git clone https://github.com/joaopedrotaveira/redmine_mylyn_connector
    git clone https://github.com/tleish/redmine_revision_branches
    git clone https://www.redmineup.com/pages/plugins/tags redmineup_tags
    git clone https://github.com/foton/redmine_watcher_groups
    git clone https://github.com/xelkano/redmine_xapian
    git clone git@github.com:paginagmbh/redmine_silencer.git redmine_silencer
    cd ..
    rm plugins/redmine_didyoumean/Gemfile.lock
    # unset mysql version in plugins/redmine_didyoumean/Gemfile
    bundle exec rake tmp:cache:clear
    bundle install
    export RAILS_ENV=development
    # bundle exec rake generate_secret_token # only once
    # bundle exec rake db:create
    bundle exec rake db:migrate
    bundle exec rake generate_secret_token
    # bundle exec rake redmine:plugins NAME=redmine_access_filters
    bundle exec rake redmine:plugins:migrate
    bundle exec rake tmp:cache:clear

## Creating a dump from the production server

`bundle exec rake RAILS_ENV=production db:data:dump` # creates db/data.yml

## development: Loading a dump

Copy the yaml dump to db/data.yml. You must manually remove in from db/data.yml the following items
* color (twice in deal_statuses)
* remove auth_sources and access_filters (LDAP)
* remove taggings ???

Now you can load it using `bundle exec rake RAILS_ENV=development db:data:load`, which will use db/data.yml

Afterwards you may examine the data as following

    export RAILS_ENV=development
    bundle exec ruby bin/rails console
    irb(main)> Project.all.first

## Reset admin login, password and skip ldap

    bundle exec ruby bin/rails runner \
    "user = User.where(admin: true).first; user.login='test_admin'; user.auth_source = nil; \
    user.email_address = EmailAddress.all.first unless user.email_address; \
    user.password = user.password_confirmation = 'test_password'; user.save!"


If you know the login of you might also use something like `:conditions => {:login => "myLogin"}`

## Start rails for development

`export RAILS_ENV=development; bundle exec ruby bin/rails server webrick --port=30001`

## Running the tests

Now you should be able to login under
To run the tests, you must rake all plugins (as above) with RAILS_ENV=test. Then you may use calls like
* `bundle exec rake redmine:plugins:test NAME=redmine_medelexis`, which runs the test for all installed plugins.

Prepare for running tests (assuming a bash shell) for redmine_medelexis-plugins using

    export RAILS_ENV test
    bundle exec rake db:migrate
    bundle exec rake redmine:plugins NAME=redmine_contacts

and load the same plugins as above. Now you should able to login (as a admin-user) test_admin with the password test_password

Run tests

* `export RAILS_ENV=test`
* `bundle exec rake redmine:plugins:test NAME=redmine_medelexis` # runs all tests
* `bundle exec ruby bin/rails runner plugins/redmine_medelexis/test/functional/license_test.rb` # runs a single test

## Scripts for the production server

### convert_test_abo_to_orders

The script scripts/convert_test_abo_to_orders.rb converts all open 'TRIAL' issues older than 1 month into 'LICENSED'. It should be run daily with a cron scripts. E.g. `/etc/cron.daily/onvert_test_abo_to_orders.sh` could have the following content.

    #!/bin/bash
    cd /path/to/redmine/checkout && bundle exec ruby bin/rails runner plugins/redmine_medelexis/scripts/convert_test_abo_to_orders.rb

It will add the log entries like this to a log file in the current directory name like <fqdn>.log

> Aug 11 20:28:11 host user: redmine_medelexis: issue_to_licensed took 1 second for ids 20,21,22

It bundles all changes into a single transaction which includes the system log output, therefore we should be able to trust it.

### create_invoices (alpha)

The script scripts/create_invoices.rb creates 6 (test) invoices using the last day of this year.

bc. bundle exec ruby bin/rails runner plugins/redmine_medelexis/scripts/create_invoices.rb

## Using docker

See "doc":https://github.com/docker-library/docs/tree/master/redmine and "code":https://github.com/docker-library/redmine. Has no so old redmine. There adapted its Dockerfile.template.

    docker build -t ngiger/redmine .
    docker run --detached -p 3000:3000 --env REDMINE_NO_DB_MIGRATE=1 -v /opt/src/redmine-medelexis/data2:/usr/src/redmine/files ngiger/redmine

# Deployment

Auf mis.medelexis.ch läuft anfangs Dezember immer noch ruby 1.9.1.

## 2018.12.12

Alles von srv/services/mis-redmine-beta auf /home/ngiger/mis-redmine-beta kopiert und dort folgende Anpassungen gemacht.

* Im top Gemfile: nokogiri wie folgt definieren: gem "nokogiri", (RUBY_VERSION >= "2.1" ? "~> 1.7.2" : "~> 1.6.8"), :source => 'https://rubygems.org'$
* Im plugins/redmine_medelexis/Gemfile debugger wie folgt definieren: gem (RUBY_VERSION >= "2.0" ? 'pry-byebug' : 'debugger')
* Zum Starten muss man export RAILS_ENV=production; bundle exec ruby1.9.3 bin/rails server RAILS_ENV=production aufrufen

