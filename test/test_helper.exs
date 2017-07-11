Redix.command! elem(Redix.start_link("redis://localhost/15"), 1), ~w(FLUSHDB)

Code.require_file("test/support/extra_asserts.exs")
ExUnit.start()
