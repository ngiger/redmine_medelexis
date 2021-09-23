# redmine_medelexis

Build status on tracis-ci: [https://travis-ci.org/ngiger/redmine_medelexis.svg?branch=master](https://travis-ci.org/ngiger/redmine_medelexis)

A few goodies for the Medelexis MIS

* admin-users see the api_key of all users
* hooks are called after create/editing service tickets

## TODO

* Scripts for the hooks

## installation

### requirements

## configuration

Under http://foo.org/settings/plugin/redmine_medelexis you can add more debugging (to the default system logger) and to keep the temporary license files.

## Installation from scratch for development

Get the needed zip files. Used versions are found under https://mis.foo.org/admin/info

*  Redmine version                4.1.3.stable
*  Ruby version                   2.5.5-p157 (2019-03-15) [x86_64-linux-gnu]
*  rails                          5.2.6
*  redmine_access_filters         0.0.2
*  redmine_agile                  1.5.4
*  redmine_checklists             3.1.18
*  redmine_contacts               4.3.2
*  redmine_contacts_helpdesk      4.1.10
*  redmine_contacts_invoices      4.2.3
*  redmine_favorite_projects      2.1.1
*  redmine_medelexis              0.2.9
*  redmine_products               2.1.2
*  redmineup_tags                 2.0.8


Afterwards execute and verify these steps (assuming a bash shell). Using ruby 1.9.3p547 was fine for me. Ruby 2.1.2 had some problems

    git clone https://github.com/redmine/redmine redmine-4.1
    cd redmine-4.1
    git checkout 4.1-stable
    export RAILS_ENV=development
    cd plugins
    unzip /path/teo/zipfilesredmine_agile-240720-m.zip
    unzip /path/teo/zipfilesredmine_checklists-3_1_18-pro.zip
    unzip /path/teo/zipfilesredmine_contacts-170820-m.zip
    unzip /path/teo/zipfilesredmine_contacts_helpdesk-4_1_10-pro.zip
    unzip /path/teo/zipfilesredmine_contacts_invoices-4_2_3-pro.zip
    unzip /path/teo/zipfilesredmine_favorite_projects-2_1_1-light.zip
    unzip /path/teo/zipfilesredmine_products-2_1_2-pro.zip
    unzip /path/teo/zipfilesredmineup_tags-2_0_8-light.zip
    git clone https://github.com/ngiger/redmine_medelexis.git
    git clone https://github.com/ngiger/redmine_access_filters.git
    cd ..
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
    # Apply patches_contact_invoices.patch for plugins/redmine_contacts_invoices/
    # lib/redmine_invoices.rb
    # lib/redmine_invoices.rb

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

    mv plugins no_plugins
    bundle exec rake db:migrate  RAILS_ENV=test
    mv no_plugins plugins
    bundle exec rake db:migrate  RAILS_ENV=test
    bundle exec rake redmine:plugins NAME=redmine_medelexis RAILS_ENV=test

and load the same plugins as above. Now you should able to login (as a admin-user) test_admin with the password test_password

Run tests

* bundle exec rake db:drop db:create db:migrate redmine:plugins:migrate redmine:load_default_data RAILS_ENV=test
* `export RAILS_ENV=test`
* `bundle exec rake redmine:plugins:test NAME=redmine_medelexis` # runs all tests
* `bundle exec ruby bin/rails runner plugins/redmine_medelexis/test/functional/license_test.rb RAILS_ENV=test` # runs a single test

## Scripts for the production server

### convert_test_abo_to_orders

The script scripts/convert_test_abo_to_orders.rb converts all open 'TRIAL' issues older than 1 month into 'LICENSED'. It should be run daily with a cron scripts. E.g. `/etc/cron.daily/onvert_test_abo_to_orders.sh` could have the following content.

    #!/bin/bash
    export RAILS_ENV=production
    cd /path/to/redmine/checkout && bundle exec ruby bin/rails runner plugins/redmine_medelexis/scripts/convert_test_abo_to_orders.rb

It will add the log entries like this to a log file in the current directory name like <fqdn>.log

> Aug 11 20:28:11 host user: redmine_medelexis: issue_to_licensed took 1 second for ids 20,21,22

It bundles all changes into a single transaction which includes the system log output, therefore we should be able to trust it.

### create_invoices (alpha)

The script scripts/create_invoices.rb creates 6 (test) invoices using the last day of this year.

bc. bundle exec ruby bin/rails runner plugins/redmine_medelexis/scripts/create_invoices.rb

# Deployment

## 2021.05.25

### PgLoader

Marco updated from the MySQL database to postgres using pgloader and the following snippet

```
LOAD DATABASE
    FROM mysql://redmine:***@mis.medelexis.ch/redmine 
    INTO postgresql://redmine:***@localhost/redmine_medelexis_ch
WITH 
    quote identifiers
CAST 
type int when (= 11 precision) to integer drop typemod,
type varchar when (= 255 precision) to varchar drop typemod,
type int when unsigned to integer drop typemod,
type int with extra auto_increment to serial drop typemod
ALTER schema 'redmine' RENAME TO 'public';
```

### Update from redmine 4.1 to 4.1 for mis

Installation auf me-core mit folgenden Schritten (getestet auf einer jungfräulichen Debian/Buster VM).

We assume that you have a user named debian with UID 1000 and sudo privilges.

But first we have to save the settings for the plugin redmine_contacts manually.
The settings from the old mis for redmine_contacts must be added manually by calling inside the mysql
`select name,value from settings where name like "plugin_redmine_contacts";`


```shell
sudo apt install git rsync postgresql
sudo apt-get build-dep ruby-activemodel rails ruby-sqlite3 libpq-dev
sudo mkdir -p /srv/services/mis-beta.medelexis.ch
sudo 1000 debian /srv/services/mis-beta.medelexis.ch
cd /srv/services/mis-beta.medelexis.ch
  # create initial database
sudo -u postgres psql -tc "create database mis_beta_medelexis_ch encoding 'utf8' template template0;"
sudo -u postgres psql -tc "create user elexis with password 'elexisTest';"
sudo -u postgres psql -tc "create user mis_beta_medelexis_ch with password 'elexisTest';"
sudo -u postgres psql -tc "alter ROLE elexis SUPERUSER;"
  # allow login into database without prompting for password
echo localhost:5432:mis_beta_medelexis_ch:elexis:elexisTest >~/.pgpass
psql -U elexis mis_beta_medelexis_ch --host=localhost --command \\dt
  # get all old files 
rsync -avp mis.medelexis.ch:/srv/services/mis-beta.medelexis.ch/files .
  # import old database copied here
sudo -u postgres pg_restore --dbname=mis_beta_medelexis_ch mis_beta_medelexis_ch.sql
  # Avoid error when logging
  # ActionView::Template::Error (undefined method `with_indifferent_access' for ActionController::Parameters
psql -U elexis mis_beta_medelexis_ch --host=localhost --command "delete from settings where name = 'plugin_redmine_contacts';'"
bundle install
bundle exec rake db:migrate
  # unzip all plugins
  cd plugins
  # copy by hand all plugins into this directory, then
  for aPlugin in *.zip
  do
    echo "Will unzip $aPlugin" 
    unzip $aPlugin
  done
  cd ..
  # migrate the plugins
for aPlugin in plugins/*/
do
  plugin_name=`basename ${aPlugin}`
  echo "Will migrate $plugin_name"
  bundle exec rake redmine:plugins NAME=${plugin_name} RAILS_ENV=production
done
```

The settings from the old mis for redmine_contacts must be added manually.

# Create a mis development environment under nixos

Assure that you have imagemagick and a postgresql server installed on your machine
and that you have created the postgres DB and copied the files.
Edit the config/database.yml correspondingly.

Then:

```
cd /opt/src
git clone https://github.com/redmine/redmine.git
cd redmine
rm -rfv plugins
git clone git@gitlab.medelexis.ch:mdescher/redmine-mis-plugins.git plugins
cd plugins
git clone git@github.com:ngiger/redmine_access_filters.git
git clone git@github.com:ngiger/redmine_access_filters.git
cd ..
ln -s plugins/redmine_medelexis/shell.nix .
nix-shell
[nix-shell] bundle install # generates Gemfile.lock
[nix-shell] bundix         # generates gemset.nix
[nis-shell] bundle exec ruby bin/rails server webrick --port=30001 -e production
```
