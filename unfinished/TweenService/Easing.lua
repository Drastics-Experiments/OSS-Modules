--!native

local style = Enum.EasingStyle
local direction = Enum.EasingDirection

return {
	[style.Sine] = {
		[direction.In] = function(x)
			return 1 - math.cos((x * math.pi) / 2)
		end,
		
		[direction.Out] = function(x)
			return math.cos((x * math.pi) / 2)
		end,
		
		[direction.InOut] = function(x)
			return -(math.cos(math.pi * x) - 1) / 2
		end,
	},
	
	[style.Quad] = {
		[direction.In] = function(x)
			return x * x
		end,
		
		[direction.Out] = function(x)
			return 1 - (1 - x) * (1 - x)
		end,
		
		[direction.InOut] = function(x)
			return (x < 0.5 and 2 * x * x) or 1 - math.pow(-2 * x + 2, 2) / 2
		end,
	},
	
	[style.Cubic] = {
		[direction.In] = function(x)
			return x * x * x
		end,
		
		[direction.Out] = function(x)
			return 1 - math.pow(1 - x, 3)
		end,
		
		[direction.InOut] = function(x)
			return x < 0.5 and 2 * x * x * x or 1 - math.pow(-2 * x + 2, 3) / 2
		end,
	},
	
	[style.Quart] = {
		[direction.In] = function(x)
			return x * x * x * x
		end,

		[direction.Out] = function(x)
			return 1 - math.pow(1 - x, 4)
		end,

		[direction.InOut] = function(x)
			return (x < 0.5 and 8 * x * x * x * x) or 1 - math.pow(-2 * x + 2, 4) / 2
		end,
	},
	
	[style.Quint] = {
		[direction.In] = function(x)
			return x * x * x * x * x
		end,

		[direction.Out] = function(x)
			return 1 - math.pow(1 - x, 5)
		end,

		[direction.InOut] = function(x)
			return (x < 0.5 and 16 * x * x * x * x * x) or 1 - math.pow(-2 * x + 2, 5) / 2
		end,
	},
	[style.Exponential] = {
		[direction.In] = function(x)
			return x == 0 and 0 or math.pow(2, 10 * x - 10)
		end,

		[direction.Out] = function(x)
			return x == 1 and 1 or 1 - math.pow(2, -10 * x)
		end,

		[direction.InOut] = function(x)
			return x == 0 and 0
			or x == 1 and 1
			or x < 0.5 and math.pow(2, 20 * x - 10) / 2
			or (2 - math.pow(2, -20 * x + 10)) / 2
		end,
	},
	[style.Circle] = {
		[direction.In] = function(x)
			return 1 - math.sqrt(1 - math.pow(x, 2))
		end,

		[direction.Out] = function(x)
			return math.sqrt(1 - math.pow(x - 1, 2))
		end,

		[direction.InOut] = function(x)
			return x < 0.5 and (1 - math.sqrt(1 - math.pow(2 * x, 2))) / 2
			or (math.sqrt(1 - math.pow(-2 * x + 2, 2)) + 1) / 2
		end,
	},
	[style.Back] = {
		[direction.In] = function(x)
			local c1 = 1.70158
			local c3 = c1 + 1
			return c3 * x * x * x - c1 * x * x
		end,

		[direction.Out] = function(x)
			local c1 = 1.70158
			local c3 = c1 + 1
			return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2)
		end,

		[direction.InOut] = function(x)
			local c1 = 1.70158
			local c2 = c1 * 1.525
			return x < 0.5 and (math.pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2
			or (math.pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2
		end,
	},
	[style.Elastic] = {
		[direction.In] = function(x)
			local c4 = (2 * math.pi) / 3
			return x == 0 and 0
				or x == 1 and 1
				or -math.pow(2, 10 * x - 10) * math.sin((x * 10 - 10.75) * c4)
		end,

		[direction.Out] = function(x)
			local c4 = (2 * Math.PI) / 3
			return x == 0 and 0 
			or x == 1 and 1 or math.pow(2, -10 * x) * math.sin((x * 10 - 0.75) * c4) + 1
		end,

		[direction.InOut] = function(x)
			local c5 = (2 * math.PI) / 4.5
			return x == 0 and 0
			or x == 1 and 1
			or x < 0.5 and -(math.pow(2, 20 * x - 10) * Math.sin((20 * x - 11.125) * c5)) / 2
			or (math.pow(2, -20 * x + 10) * math.sin((20 * x - 11.125) * c5)) / 2 + 1
		end,
	},
	
	[style.Bounce] = {
		[direction.In] = function(x)

		end,

		[direction.Out] = function(x)
			local n1 = 7.5625
			local d1 = 2.75
			if (x < 1 / d1) then
				return n1 * x * x
			elseif (x < 2 / d1) then
				return n1 * (x -= 1.5 / d1) * x + 0.75
			elseif (x < 2.5 / d1) then
				return n1 * (x -= 2.25 / d1) * x + 0.9375
			else
				return n1 * (x -= 2.625 / d1) * x + 0.984375
			end
		end,

		[direction.InOut] = function(x)
			--return x < 0.5
			--? (1 - easeOutBounce(1 - 2 * x)) / 2
			--: (1 + easeOutBounce(2 * x - 1)) / 2;
		end,
	},
	

}