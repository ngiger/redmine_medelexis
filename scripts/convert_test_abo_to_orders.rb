#!/usr/bin/env ruby
dir = File.expand_path('../../lib', __FILE__)
$: << dir unless $:.index(dir)
require 'medelexis_helpers'
RedmineMedelexis. convertExpiredTrial2License

