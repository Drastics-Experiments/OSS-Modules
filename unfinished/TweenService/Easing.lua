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

		end,

		[direction.Out] = function(x)

		end,

		[direction.InOut] = function(x)

		end,
	},
	
	[style.Quint] = {
		[direction.In] = function(x)

		end,

		[direction.Out] = function(x)

		end,

		[direction.InOut] = function(x)

		end,
	},
}