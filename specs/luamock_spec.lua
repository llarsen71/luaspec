require 'luaspec'
require 'luamock'

describe["a Mock"] = function(_ENV)
	before = function(_ENV)
		mock = Mock:new()
	end
	
	describe["when called as a function with no parameters"] = function(_ENV)
		before = function(_ENV)
			return_value = mock()
		end
		
		it["should return nil"] = function(_ENV)
			expect(return_value).should_be(nil)
		end

		it["should record the call in Mock.calls"] = function(_ENV)
			expect(#Mock.calls[mock]).should_be(1)
		end
		
		it["should record the parameters (or lack there of)"] = function(_ENV)
			expect(#Mock.calls[mock][1]).should_be(0)
		end
		
		describe["when called a second time with a few parameters"] = function(_ENV)
			before = function(_ENV)
				mock(1, "two", 3)
			end

			it["should record the call in Mock.calls"] = function(_ENV)
				expect(#Mock.calls[mock]).should_be(2)
			end

			it["should record the parameters"] = function(_ENV)
				-- TODO, replace with a single matcher that compares an array
				-- e.g. expect(Mock.calls[mock][2]).should_be({ 1, "two", 3 })
				expect(#Mock.calls[mock][2]).should_be(3)
				expect(Mock.calls[mock][2][1]).should_be(1)
				expect(Mock.calls[mock][2][2]).should_be("two")
				expect(Mock.calls[mock][2][3]).should_be(3)
			end
		end
	end
	
	describe["when accessing a new property"] = function(_ENV)
		before = function(_ENV)
			field = mock.foo
		end
		
		it["should create a new Mock instance"] = function(_ENV)
			expect(getmetatable(field)).should_be(Mock)
		end
	end
	
	describe["when setting a property"] = function(_ENV)
		before = function(_ENV)
			mock.foo = 25
		end
		
		it["should be accessible"] = function(_ENV)
			expect(mock.foo).should_be(25)
		end
	end
	
	describe["when specifying a return value"] = function(_ENV)
		before = function(_ENV)
			mock:returns(10)
		end
		
		it["should return that value when called as a function"] = function(_ENV)
			expect(mock()).should_be(10)
		end
	end
	
	describe["when specifying subsequent return values"] = function(_ENV)
		before = function(_ENV)
			mock:returns(10):then_returns(25)
		end
		
		it["should return that value when called as a function"] = function(_ENV)
			expect(mock()).should_be(10)
			expect(mock()).should_be(25)
		end
	end
	
	describe["when specifying a return value using . instead of :"] = function(_ENV)
		before = function(_ENV)
			err = track_error(function() mock.returns(10) end)
		end
		
		it["should produce an error"] = function(_ENV)
			expect(err).should_not_be(nil)
		end
	end	
end

spec:report(true)