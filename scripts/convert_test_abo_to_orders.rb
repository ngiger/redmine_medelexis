#!/usr/bin/env ruby
# run it using: bundle exec ruby script/rails runner plugins/redmine_medelexis/scripts/convert_test_abo_to_orders.rb
dir = File.expand_path('../../lib', __FILE__)
$: << dir unless $:.index(dir)
require 'medelexis_helpers'
RedmineMedelexis. convertExpiredTrial2License

