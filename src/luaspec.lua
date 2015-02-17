spec = {
  contexts = {}, passed = 0, failed = 0, pending = 0, current = nil
}

Report = {}
Report.__index = Report
output = decoda_output or print

function Report:new(spec)
  local report = {    
    num_passed = spec.passed,
    num_failed = spec.failed,
    num_pending = spec.pending,
    total = spec.passed + spec.failed + spec.pending,
    results = {}
  }
  
  report.percent = report.num_passed/report.total*100
    
  local contexts = spec.contexts
  
  for index = 1, #contexts do
    report.results[index] = {
      name = contexts[index],      
      spec_results = contexts[contexts[index]]
    }
  end    
  
  return report    
end

function spec:report(verbose)
  local report = Report:new(self)

  if report.num_failed == 0 and not verbose then
    output "all tests passed"
    return
  end
  
  for _, result in pairs(report.results) do
    output(("%s\n================================"):format(result.name))
    
    for description, r in pairs(result.spec_results) do
      local outcome = r.passed and 'pass' or "FAILED"

      if verbose or not (verbose and r.passed) then
        output(("%-70s [ %s ]"):format(" - " .. description, outcome))

        for index, error in pairs(r.errors) do
          output("   ".. index..". Failed expectation : ".. error.message.."\n   "..error.trace)
        end
      end
    end
  end

  local summary = [[
=========  Summary  ============
%s Expectations
Passed : %s, Failed : %s, Success rate : %.2f percent
]]

  output(summary:format(report.total, report.num_passed, report.num_failed, report.percent))
end

function spec:add_results(success, message, trace)
  if self.current.passed then
    self.current.passed = success
  end

  if success then
    self.passed = self.passed + 1
  else
    table.insert(self.current.errors, { message = message, trace = trace })
    self.failed = self.failed + 1
  end
end

function spec:add_context(name)  
  self.contexts[#self.contexts+1] = name
  self.contexts[name] = {}  
end

function spec:add_spec(context_name, spec_name)
  local context = self.contexts[context_name]
  context[spec_name] = { passed = true, errors = {} }
  self.current = context[spec_name]
end

function spec:add_pending_spec(context_name, spec_name, pending_description)
end

--

-- create tables to support pending specifications
local pending = {}

function pending.__newindex() error("You can't set properties on pending") end

function pending.__index(_, key) 
  if key == "description" then 
    return nil 
  else
    error("You can't get properties on pending") 
  end
end

function pending.__call(_, description)
  local o = { description = description}
  setmetatable(o, pending)
  return o
end  

setmetatable(pending, pending)

--

function verifyTable(TBL, expected, key, errors, name)
  key, name, errors = key or '', name or 'TBL', errors or {}
  local i, keys = 0, {}
  local result = true
  for k,v in pairs(expected) do
    local key1 = string.format("%s[%s]", key, k)
    test = function()
      local V = TBL[k]
      local TV, tv = type(V), type(v)
      if TV ~= tv then
        table.insert(errors, string.format("expecting type(%s%s)=%s, not %s",
          name, key1, tostring(tv), tostring(TV)))
        return false
      end
      if TV == 'table' then
        return verifyTable(V, v, key1, errors, name)
      end
      if V ~= v then
        table.insert(errors, string.format("expecting %s%s=%s, not %s",
          name, key1, v, V))
        return false
      end
      return true
    end
    result = test() and result
  end
  return result, errors
end

-- define matchers

matchers = {
  should_be = function(value, expected)
    if type(expected) == "table" then
        if type(value) ~= "table" then
            return false, "expecting " .. tostring(expected).." to be 'table' type"
        end
        result, errors = verifyTable(value, expected)
        if result == false then
            local error =  "\n" .. table.concat(errors, "\n")
            return false, error
        end
    elseif value ~= expected then
      return false, "expecting "..tostring(expected)..", not ".. tostring(value)
    end
    return true
  end;

  should_not_be = function(value, expected)
    if value == expected then
      return false, "should not be "..tostring(value)
    end
    return true
  end;
  
  should_error = function(f)
    if pcall(f) then
      return false, "expecting an error but received none"
    end
    return true
  end;

  should_match = function(value, pattern) 
    if type(value) ~= 'string' then
      return false, "type error, should_match expecting target as string"
    end

    if not string.match(value, pattern) then
      return false, value .. "doesn't match pattern "..pattern
    end
    return true
  end;  
}
 
matchers.should_equal = matchers.should_be

--

-- expect returns an empty table with a 'method missing' metatable
-- which looks up the matcher.  The 'method missing' function
-- runs the matcher and records the result in the current spec
-- and returns the result
local function expect(target)
  return setmetatable({}, { 
    __index = function(_, matcher)
      return function(...)
        local success, message = matchers[matcher](target, ...)
      
        spec:add_results(success, message, debug.traceback())
        
        -- return whether the result was successful
        return success
      end
    end
  })
end


--

Context = {}
Context.__index = Context

-- Only use setfenv for lua 5.1. For lua 5.2 we pass in env to functions and require user to have _ENV as arg.
function SETFENV(fn, env)
  if _ENV == nil then setfenv(fn, env) end
end

function Context:new(context)
  for _, child in ipairs(context.children) do
    child.parent = context
  end
  return setmetatable(context, self)
end

function Context:run_befores(env)
  if self.parent then
    self.parent:run_befores(env)
  end
  if self.before then
    SETFENV(self.before, env)
    self.before(env)
  end
end

function Context:run_afters(env)
  if self.after then
    SETFENV(self.after, env)
    self.after(env)
  end
  if self.parent then
    self.parent:run_afters(env)
  end
end

function Context:run()
  -- run all specs
  for spec_name, spec_func in pairs(self.specs) do
    if getmetatable(spec_func) == pending then
    else
      spec:add_spec(self.name, spec_name)
  
      local mocks = {}
  
      -- setup the environment that the spec is run in, each spec is run in a new environment
      local env = {
        track_error = function(f)
          local status, err = pcall(f)
          return err
        end,
    
        expect = expect,
    
        mock = function(table, key, mock_value)      
          mocks[{ table = table, key = key }] = table[key]  -- store the old value
          table[key] = mock_value or Mock:new()
          return table[key]
        end
      }
      
      setmetatable(env, { __index = _G})

      -- run each spec with proper befores and afters
      self:run_befores(env)
  
      SETFENV(spec_func, env)
      local success, message = pcall(spec_func, env)

      self:run_afters(env)
    
      if not success then
        spec:add_results(false, message, debug.traceback())
      end    
    
      -- restore stored values for mocks
      for key, old_value in pairs(mocks) do
        key.table[key.key] = old_value
      end
    end
  end
  
  for _, child in pairs(self.children) do
    child:run()
  end
end

-- dsl for creating contexts

local function make_it_table()
  -- create and set metatables for 'it'
  local specs = {}
  local it = {}
  setmetatable(it, {
    -- this is called when it is assigned a function (e.g. it["spec name"] = function() ...)
    __newindex = function(_, spec_name, spec_function)
      specs[spec_name] = spec_function
    end
  })
  
  return it, specs
end

local make_describe_table

context_env_defaults = {}

-- create an environment to run a context function in as well as the tables to collect 
-- the subcontexts and specs
local function create_context_env()
  local it, specs = make_it_table()
  local describe, sub_contexts = make_describe_table()

  -- create an environment to run the function in
  local context_env = {
    it = it,
    describe = describe,
    pending = pending
  }
    
  for k,v in pairs(context_env_defaults) do
    context_env[k] = v
  end
  
  return context_env, sub_contexts, specs
end

-- Note: this is declared locally earlier so it is still local
function make_describe_table(auto_run)
  local describe = {}
  local contexts = {}
  local describe_mt = {
    
    -- This function is called when a function is assigned to a describe table 
    -- (e.g. describe["context name"] = function() ...)
    __newindex = function(_, context_name, context_function)
    
      spec:add_context(context_name)

      local context_env, sub_contexts, specs = create_context_env()
      
      -- set the environment
      SETFENV(context_function, context_env)
      
      -- run the context function which collects the data into context_env and sub_contexts
      context_function(context_env)
      
      -- store the describe function in contexts
      contexts[#contexts+1] = Context:new { 
        name = context_name,
        before = context_env.before, 
        after = context_env.after, 
        specs = specs, 
        children = sub_contexts 
      }
      
      if auto_run then
        contexts[#contexts]:run()
      end
    end
  }
  
  setmetatable(describe, describe_mt)
  
  return describe, contexts
end

describe = make_describe_table(true)
