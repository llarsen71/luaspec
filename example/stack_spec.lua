require 'luaspec'
require 'stack'

describe["A Stack"] = function(_ENV)
	before = function(_ENV)
		s = Stack:new()
	end
	
	it["should be empty to start with"] = function(_ENV)
		expect(s:top()).should_be(nil)
	end

	it["should allow items to be pushed"] = function(_ENV)
		s:push(30)
		expect(s:top()).should_be(30)
	end
		
	it["should error when pop is called on an empty stack"] = function(_ENV)
		expect(function() s:pop() end).should_error()
	end
				
	it["this is pending"] = pending
	
	describe["Calling pop on an empty stack"] = function(_ENV)
		before = function(_ENV)
			err = track_error(function() s:pop() end)		
		end
		
		it["errror should contain 'Nothing on Stack'"] = function(_ENV)
			expect(err).should_match(".*Nothing on the stack.*")
		end
	end
	
end

spec:report(true)