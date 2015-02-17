require 'luaspec'

describe["default matchers"] = function(_ENV)
	it["All matchers should be functions"] = function(_ENV)
		for _, m in pairs(matchers) do
			expect(type(m)).should_be("function")
		end
	end
end

spec:report(true)
