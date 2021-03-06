#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + '/../ext'
$:.unshift File.dirname(__FILE__) + '/../lib'

require 'bundler/setup'
require 'mysql2'
require 'do_mysql'
require 'swift-db-mysql'
require 'benchmark'

dbs = {
  do_mysql: DataObjects::Connection.new("mysql://127.0.0.1/swift_test"),
  mysql2:   Mysql2::Client.new(database: 'swift_test'),
  swift:    Swift::DB::Mysql.new(db: 'swift_test'),
}

sql = {
  drop:   'drop table if exists users',
  create: 'create table users(id integer auto_increment primary key, name text, created_at datetime)',
  insert: 'insert into users(name, created_at) values (?, ?)',
  select: 'select * from users where id > ?',
}

rows = 1000
iter = 100

class Mysql2::Client
  # naive interpolation
  def execute sql, *args
    query sql.chars.inject('') {|a, c| a << (c == '?' ? (v = args.shift).nil? ? 'NULL' : "'%s'" % escape(v.to_s) : c)}
  end
end

module DataObjects
  class Connection
    def query sql, *args
      create_command(sql).execute_reader(*args)
    end
    def execute sql, *args
      create_command(sql).execute_non_query(*args)
    end
  end
end

Benchmark.bm(15) do |bm|
  dbs.each do |name, db|
    db.execute(sql[:drop])
    db.execute(sql[:create])

    bm.report("#{name} insert") do
      rows.times do |n|
        db.execute(sql[:insert], "name #{n}", Time.now.strftime("%FT%T"))
      end
    end

    bm.report("#{name} select") do
      case db
        when DataObjects::Mysql::Connection
          iter.times do
            db.query(sql[:select], 0).entries
          end
        else
          iter.times do
            db.execute(sql[:select], 0).entries
          end
      end
    end
  end
end
