# class FakeAdapter < Jennifer::Adapter::Base
#   ZERO = Time::Span::ZERO

#   ABSTRACT_METHODS = %i(
#     sql_generator view_exists? update insert table_exists? foreign_key_exists? index_exists?
#     column_exists? translate_type default_type_size table_column_count with_table_lock schema_processor
#   )

#   {% for method in ABSTRACT_METHODS %}
#     def {{method.id}}(*args, **opts)
#       raise "Abstract {{method.id}}"
#     end
#   {% end %}

#   def self.command_interface
#     raise "Abstract command_interface"
#   end

#   def exec(_query, args = [] of Jennifer::Adapter::Base::ArgsType)
#     logger.debug { regular_query_message(ZERO, _query, args) }
#     DB::ExecResult.new(0i64, -1i64)
#   end

#   def query(_query, args = [] of Jennifer::Adapter::Base::ArgsType)
#     logger.debug { regular_query_message(ZERO, _query, args) }
#     nil
#   end

#   def scalar(_query, args = [] of Jennifer::Adapter::Base::ArgsType)
#     logger.debug { regular_query_message(ZERO, _query, args) }
#     false
#   end

#   private def logger
#     Jennifer::Config.logger
#   end
# end
