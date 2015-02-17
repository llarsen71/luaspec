require 'luaspec'

-- Each test set starts with a describe item when hold a function.
-- All luaspec test functions should recieve _ENV as a parameter.
-- This stores and global values that are set so that the can be
-- used in functions that follow.
describe['a luapec test file'] = function(_ENV)
  before = function(_ENV)
    local is_local = true
    var = 1
    tbl = {1,2,3,4, a=10, tbl={4,5,6, b=12}}
  end

  -- The global variables set in begin should be available in this function
  it['should allow persistent globals in begin'] = function(_ENV)
    expect(var).should_not_be(nil)
    expect(tbl).should_not_be(nil)
  end
  
  -- local variables should not be preserved.
  it['should not preserve local variables'] = function(_ENV)
    expect(is_local).should_be(nil)
  end
  
  -- Should be able to compare simple local variables
  it['should allow comparison of simple values'] = function(_ENV)
    expect(var).should_be(1)
  end
  
  -- Should allow comparison of tables
  it['should allow comparison of tables'] = function(_ENV)
    -- At present, keys not in the should_be table are ignored.
    -- In other words extra values don't make this incompatible.
    -- Maybe should implement a strict mode.
    expect(tbl).should_be({1,2,3, tbl={4,5,6, b=12}})
  end  
end

spec:report(true)