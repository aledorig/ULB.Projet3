#!python.exe
# temporaire i guess, juste pour voir en visuel
import matplotlib.pyplot as plt
import numpy as np

from perlin import Perlin


noise = Perlin(num_octaves=8,fractal_gain=0.5,fractal_lacunarity=2, seed=666)

width  = 300
height = 300

img = np.zeros((height, width))

for y in range(height):
    for x in range(width):
        n = noise.get_noise_2d(x, y)
        if abs(n) > 0.9:
            print(f"At ({x},{y}) -> {n}")
        img[y][x] = n

plt.imshow(img, cmap="gray")
plt.title("Perlin Noise")
plt.axis("off")
plt.show()
