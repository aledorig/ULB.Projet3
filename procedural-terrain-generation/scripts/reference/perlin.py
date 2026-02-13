import math
from random import Random

# Can rename the "perlin class" to "noisemaker class" if we add other noises
class Perlin:
	"""2D Perlin NoiseGenerator"""

	# Gradients direction
	DIRECTIONS = [ # ??? : More directions? 
			(1, 1),
			(-1, 1),
			(1, -1),
			(-1,-1),
			(1, 0),
			(-1, 0),
			(0, 1),
			(0, -1)
		]
	
	def __init__(self, num_octaves=1, fractal_gain=0.5, fractal_lacunarity=2.0, seed: int | None = None) -> None:
		self.seed = seed
		self.table = []
		self.build_perm_table(seed)
		self.fractal_octaves = num_octaves
		self.fractal_gain = fractal_gain
		self.fractal_lacunarity = fractal_lacunarity


	def set_seed(self, seed):
		self.seed = seed
		self.build_perm_table(seed) # in case we reseed


	def shuffle(self, table : list , rng: Random) ->  None : # idk if we need it, could have used random.shuffle,
		for i in range(255, -1, -1):
			j = rng.randint(0, i)
			table[i], table[j] = table[j], table[i]


	def build_perm_table(self, seed: int | None) -> None:
		table = list(range(256))
		rng = Random(seed)

		self.shuffle(table, rng)
		
		# Duplicate table to 512 elements (Acces trick, look up to "Perlin noise" on eng wiki, idk if it's still a valid way in 2025)
		# Surely because the hash used (table[self.table[x] + y]) can be bigger than 256
		self.table = table*2

	
	def find_grid_coordinates(self, x : float, y : float) -> tuple :

		# Coordinates of the square
		x0 = math.floor(x) & 255
		y0 = math.floor(y) & 255
		x1 = (x0 + 1) & 255
		y1 = (y0 + 1) & 255

		# Local coordinates of (x,y) in the square
		local_x = x - math.floor(x)
		local_y = y - math.floor(y)

		return (x0 ,y0 ,x1 ,y1, local_x, local_y)
    

	def gradient_at(self, x: int, y: int) -> tuple:
		hash = self.table[self.table[x] + y] # hash function, give a random number in the table
		return self.DIRECTIONS[hash & 7] # take 3 LSB of hash as an int -> give random direction 

	def dir_vector(self ,x0 : float, y0 : float, x1 : float, y1 : float ) -> tuple :
		# Vector of (x0, y0) to (x1, y1) (not the other sens)
		return (x1 - x0, y1 - y0)
	
	def dot_product(self, grad, vec):
		return grad[0] * vec[0] + grad[1] * vec[1] # == how much the point go to the direction of the gradient
	
	def fade(self, n: float ) -> float :
		return (6*(n**5) - (15*(n**4)) + (10*(n**3)))
	
	def lerp(self, n0 : float , n1: float , fade_coeff : float) -> float : 
		return n0 + (n1 - n0) * fade_coeff

	def corner_contrib(self, grid_x: int, grid_y: int,
                    corner_x: float, corner_y: float,
                    local_x: float, local_y: float) -> float:
		
		# Vector from the corner to the local point
		vec = self.dir_vector(corner_x, corner_y, local_x, local_y)
		# Gradient direction obtained through hashing
		grad = self.gradient_at(grid_x,grid_y)
		# How much the vector is influenced/ follow the direction of the gradient
		return self.dot_product(grad, vec)
	

	def _perlin(self, x: float, y: float) -> float:

		# Which grid cell contains (x,y), get corners + get local remap of original (x,y)
		x0, y0, x1, y1, local_x, local_y = self.find_grid_coordinates(x, y)

		# 4 corner contribution
		down_left  = self.corner_contrib(x0, y0, 0.0, 0.0, local_x, local_y)
		down_right = self.corner_contrib(x1, y0, 1.0, 0.0, local_x, local_y)
		up_left    = self.corner_contrib(x0, y1, 0.0, 1.0, local_x, local_y)
		up_right   = self.corner_contrib(x1, y1, 1.0, 1.0, local_x, local_y)

		# Interpolation
		horizontal_interp = self.fade(local_x)
		vertical_interp = self.fade(local_y)

		# Fade it to smooth the transitions
		ix0 = self.lerp(down_left, down_right, horizontal_interp)
		ix1 = self.lerp(up_left, up_right,   horizontal_interp)

		return self.lerp(ix0, ix1, vertical_interp)
	
	def get_noise_2d(self, x: float, y: float):
		amplitude = 1.0
		frequency = 0.05
		noise_value = 0.0

		for _ in range(self.fractal_octaves+1):
			noise_value += self._perlin(x * frequency, y * frequency) * amplitude
			amplitude *= self.fractal_gain
			frequency *= self.fractal_lacunarity

		return min(max(noise_value, -1.0), 1.0)  # Clamp to [-1, 1]