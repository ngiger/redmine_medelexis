#!/usr/bin/env ruby
# encoding: utf-8
# run it using: bundle exec ruby script/rails runner plugins/redmine_medelexis/scripts/create_invoices.rb
dir = File.expand_path('../../lib', __FILE__)
$: << dir unless $:.index(dir)
Invoice.find(1)
require 'invoice_helpers'
Invoice.find(1)
RedmineMedelexis.startInvoicing(DateTime.now.end_of_year.to_date, BigDecimal.new('0.05'))
