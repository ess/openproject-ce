#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module Queries::SqlForField
  private

  # Helper method to generate the WHERE sql for a +field+, +operator+ and a +values+ array
  def sql_for_field(field, operator, values, db_table, db_field, is_custom_filter = false)
    # code expects strings (e.g. for quoting), but ints would work as well: unify them here
    values = values.map(&:to_s)

    sql = ''
    case operator
    when '='
      if values.present?
        if values.include?('-1')
          sql = "#{db_table}.#{db_field} IS NULL OR "
        end

        sql += "#{db_table}.#{db_field} IN (" + values.map { |val| "'#{connection.quote_string(val)}'" }.join(',') + ')'
      else
        # empty set of allowed values produces no result
        sql = '0=1'
      end
    when '!'
      if values.present?
        sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + values.map { |val| "'#{connection.quote_string(val)}'" }.join(',') + '))'
      else
        # empty set of forbidden values allows all results
        sql = '1=1'
      end
    when '!*'
      sql = "#{db_table}.#{db_field} IS NULL"
      sql << " OR #{db_table}.#{db_field} = ''" if is_custom_filter
    when '*'
      sql = "#{db_table}.#{db_field} IS NOT NULL"
      sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
    when '>='
      if is_custom_filter
        sql = "#{db_table}.#{db_field} != '' AND CAST(#{db_table}.#{db_field} AS decimal(60,4)) >= #{values.first.to_f}"
      else
        sql = "#{db_table}.#{db_field} >= #{values.first.to_f}"
      end
    when '<='
      if is_custom_filter
        sql = "#{db_table}.#{db_field} != '' AND CAST(#{db_table}.#{db_field} AS decimal(60,4)) <= #{values.first.to_f}"
      else
        sql = "#{db_table}.#{db_field} <= #{values.first.to_f}"
      end
    when 'o'
      sql = "#{Status.table_name}.is_closed=#{connection.quoted_false}" if field == 'status_id'
    when 'c'
      sql = "#{Status.table_name}.is_closed=#{connection.quoted_true}" if field == 'status_id'
    when '>t-'
      sql = date_range_clause(db_table, db_field, - values.first.to_i, 0)
    when '<t-'
      sql = date_range_clause(db_table, db_field, nil, - values.first.to_i)
    when 't-'
      sql = date_range_clause(db_table, db_field, - values.first.to_i, - values.first.to_i)
    when '>t+'
      sql = date_range_clause(db_table, db_field, values.first.to_i, nil)
    when '<t+'
      sql = date_range_clause(db_table, db_field, 0, values.first.to_i)
    when 't+'
      sql = date_range_clause(db_table, db_field, values.first.to_i, values.first.to_i)
    when 't'
      sql = date_range_clause(db_table, db_field, 0, 0)
    when 'w'
      from = l(:general_first_day_of_week) == '7' ?
      # week starts on sunday
      ((Date.today.cwday == 7) ? Time.now.at_beginning_of_day : Time.now.at_beginning_of_week - 1.day) :
        # week starts on monday (Rails default)
        Time.now.at_beginning_of_week
      sql = "#{db_table}.#{db_field} BETWEEN '%s' AND '%s'" % [connection.quoted_date(from), connection.quoted_date(from + 7.days)]
    when '~'
      sql = "LOWER(#{db_table}.#{db_field}) LIKE '%#{connection.quote_string(values.first.to_s.downcase)}%'"
    when '!~'
      sql = "LOWER(#{db_table}.#{db_field}) NOT LIKE '%#{connection.quote_string(values.first.to_s.downcase)}%'"
    end

    sql
  end

  # Returns a SQL clause for a date or datetime field.
  def date_range_clause(table, field, from, to)
    s = []
    if from
      s << ("#{table}.#{field} > '%s'" % [connection.quoted_date((Date.yesterday + from).to_time.end_of_day)])
    end
    if to
      s << ("#{table}.#{field} <= '%s'" % [connection.quoted_date((Date.today + to).to_time.end_of_day)])
    end
    s.join(' AND ')
  end

  def connection
    self.class.connection
  end
end
