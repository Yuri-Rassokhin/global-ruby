def run!(hub, method, *args)
  caller_context = binding # This is the binding of the caller of auto_run
  hub.run(caller_context, method, *args)
end
