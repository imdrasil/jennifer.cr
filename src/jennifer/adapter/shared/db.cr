abstract class DB::Statement
  protected def around_query_or_exec(args : Enumerable)
    yield
  end
end
