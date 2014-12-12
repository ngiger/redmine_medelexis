#!/usr/bin/env ruby
# encoding: utf-8
# run it using: bundle exec ruby script/rails runner plugins/redmine_medelexis/scripts/create_invoices.rb
dir = File.expand_path('../../lib', __FILE__)
$: << dir unless $:.index(dir)
require 'medelexis_invoices'
MedelexisInvoices.startInvoicing(DateTime.now.end_of_year.to_date, BigDecimal.new('0.05'))
# MedelexisInvoices.invoice_for_project(123, DateTime.now.end_of_year.to_date, BigDecimal.new('0.05'))
